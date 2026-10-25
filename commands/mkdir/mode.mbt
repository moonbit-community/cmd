///|
priv suberror ModeError {
  InvalidMode
  NeedsUmask
}

///|
priv struct ModeChange {
  who : Int32
  op : Char
  value : Int32
  copy : Int32?
  mentioned : Int32
}

///|
fn compile_mode(text : String) -> Array[ModeChange] raise ModeError {
  let chars = text.iter().collect()
  let changes : Array[ModeChange] = []
  let mut index = 0
  while index < chars.length() {
    let mut who = 0
    while index < chars.length() && chars[index] is ('u' | 'g' | 'o' | 'a') {
      who = who |
        (match chars[index] {
          'u' => 0o4700
          'g' => 0o2070
          'o' => 0o1007
          _ => 0o7777
        })
      index += 1
    }
    let before = changes.length()
    while index < chars.length() && chars[index] is ('+' | '-' | '=') {
      let op = chars[index]
      index += 1
      let mut value = 0
      let mut mentioned = 0
      let mut copy : Int32? = None
      let start = index
      while index < chars.length() && !(chars[index] is ('+' | '-' | '=' | ',')) {
        match chars[index] {
          'r' => value = value | 0o444
          'w' => value = value | 0o222
          'x' | 'X' => value = value | 0o111
          's' => {
            value = value | 0o6000
            mentioned = mentioned | 0o6000
          }
          't' => {
            value = value | 0o1000
            mentioned = mentioned | 0o1000
          }
          'u' => copy = Some(6)
          'g' => copy = Some(3)
          'o' => copy = Some(0)
          _ => raise InvalidMode
        }
        index += 1
      }
      if copy is Some(_) && index - start != 1 {
        raise InvalidMode
      }
      changes.push({ who, op, value, copy, mentioned, })
    }
    if changes.length() == before {
      raise InvalidMode
    }
    if index < chars.length() {
      if chars[index] != ',' {
        raise InvalidMode
      }
      index += 1
      if index == chars.length() {
        raise InvalidMode
      }
    }
  }
  if changes.is_empty() {
    raise InvalidMode
  }
  changes
}

///|
fn adjust_mode(changes : ArrayView[ModeChange], mask : Int32) -> Int32 {
  let mut mode = 0o777
  let mut mode_bits = 0
  for change in changes {
    let omit = 0o6000 & change.mentioned.lnot()
    let value = if change.copy is Some(shift) {
      let bits = (mode >> shift) & 7
      bits | (bits << 3) | (bits << 6)
    } else {
      change.value
    }
    let affected = if change.who == 0 { mask.lnot() } else { change.who }
    let value = value & affected & omit.lnot()
    mode = match change.op {
      '=' => {
        let preserved = (if change.who == 0 { 0 } else { change.who.lnot() }) |
          omit
        mode_bits = mode_bits | (0o7777 & preserved.lnot())
        (mode & preserved) | value
      }
      '+' => {
        mode_bits = mode_bits | value
        mode | value
      }
      _ => {
        mode_bits = mode_bits | value
        mode & value.lnot()
      }
    }
  }
  let mode = mode & 0o7777
  // GNU creates special-mode directories without group/other write access,
  // then applies chmod only when a requested bit differs from the new inode.
  let created = if ((mode_bits & 0o6000) | (mode & 0o1000)) != 0 {
    mode & (0o6022).lnot()
  } else {
    mode
  }
  if ((created ^ mode) & mode_bits) != 0 {
    mode
  } else {
    created
  }
}

///|
fn symbolic_mode(text : String) -> Int32 raise ModeError {
  let changes = compile_mode(text)
  let result = adjust_mode(changes, 0)
  if changes.any(change => change.who == 0) {
    // Establish independence from the unknown umask, rather than guessing it.
    for mask in 1..<512 {
      if adjust_mode(changes, mask) != result {
        raise NeedsUmask
      }
    }
  }
  result
}
