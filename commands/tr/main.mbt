///|
priv suberror CliError {
  CliError(String)
}

///|
priv enum SetToken {
  One(Byte)
  Dash
  Many(Array[Byte])
}

///|
fn char_to_byte(c : Char, spec : String) -> Byte raise CliError {
  let code = c.to_int()
  if code > 0xFF {
    raise CliError(
      "tr: only Latin-1 characters are supported in sets: '\{spec}'",
    )
  }
  code.to_byte()
}

///|
fn class_bytes(name : String) -> Array[Byte] raise CliError {
  let out : Array[Byte] = []
  fn push_range(lo : Int, hi : Int) {
    for code in lo..<=hi {
      out.push(code.to_byte())
    }
  }

  match name {
    "lower" => push_range(0x61, 0x7A)
    "upper" => push_range(0x41, 0x5A)
    "digit" => push_range(0x30, 0x39)
    "alpha" => {
      push_range(0x41, 0x5A)
      push_range(0x61, 0x7A)
    }
    "alnum" => {
      push_range(0x30, 0x39)
      push_range(0x41, 0x5A)
      push_range(0x61, 0x7A)
    }
    "space" =>
      for b in [b'\t', b'\n', 0x0B, 0x0C, b'\r', b' '] {
        out.push(b)
      }
    "xdigit" => {
      push_range(0x30, 0x39)
      push_range(0x41, 0x46)
      push_range(0x61, 0x66)
    }
    _ => raise CliError("tr: unsupported character class: '[:\{name}:]'")
  }
  out
}

///|
fn expand_set(spec : String) -> Array[Byte] raise CliError {
  let chars : Array[Char] = spec.iter().collect()
  let tokens : Array[SetToken] = []
  let mut i = 0
  while i < chars.length() {
    let c = chars[i]
    if c == '\\' && i + 1 < chars.length() {
      let escaped = match chars[i + 1] {
        'n' => b'\n'
        't' => b'\t'
        'r' => b'\r'
        '0' => b'\x00'
        'a' => b'\x07'
        'b' => b'\x08'
        'f' => b'\x0C'
        'v' => b'\x0B'
        other => char_to_byte(other, spec)
      }
      tokens.push(One(escaped))
      i += 2
    } else if c == '[' && i + 1 < chars.length() && chars[i + 1] == ':' {
      let mut j = i + 2
      let name = StringBuilder()
      while j + 1 < chars.length() && !(chars[j] == ':' && chars[j + 1] == ']') {
        name.write_char(chars[j])
        j += 1
      }
      if j + 1 >= chars.length() {
        raise CliError("tr: unterminated character class in: '\{spec}'")
      }
      tokens.push(Many(class_bytes(name.to_string())))
      i = j + 2
    } else if c == '-' {
      tokens.push(Dash)
      i += 1
    } else {
      tokens.push(One(char_to_byte(c, spec)))
      i += 1
    }
  }
  let bytes : Array[Byte] = []
  let mut k = 0
  while k < tokens.length() {
    match tokens[k] {
      Dash =>
        if k > 0 &&
          k + 1 < tokens.length() &&
          tokens[k - 1] is One(lo) &&
          tokens[k + 1] is One(hi) {
          if lo.to_int() > hi.to_int() {
            raise CliError("tr: range endpoints out of order in: '\{spec}'")
          }
          // The lower endpoint was already pushed when One(lo) was visited.
          for code in (lo.to_int() + 1)..<=hi.to_int() {
            bytes.push(code.to_byte())
          }
          k += 2
        } else {
          bytes.push(b'-')
          k += 1
        }
      One(b) => {
        bytes.push(b)
        k += 1
      }
      Many(class) => {
        bytes.append(class)
        k += 1
      }
    }
  }
  bytes
}

///|
fn membership(set : Array[Byte]) -> FixedArray[Bool] {
  let table = FixedArray::make(256, false)
  for b in set {
    table[b.to_int()] = true
  }
  table
}

///|
fn complement_set(set : Array[Byte]) -> Array[Byte] {
  let table = membership(set)
  let out : Array[Byte] = []
  for code in 0..<=255 {
    if !table[code] {
      out.push(code.to_byte())
    }
  }
  out
}

///|
async fn transform_stream(
  delete : FixedArray[Bool]?,
  translate : FixedArray[Byte]?,
  squeeze : FixedArray[Bool]?,
) -> Unit {
  let mut previous = -1
  while @stream.read_chunk(@stdio.stdin) is Some(chunk) {
    let out : Array[Byte] = []
    for input in chunk {
      let input_code = input.to_int()
      if delete is Some(table) && table[input_code] {
        continue
      }
      let byte = match translate {
        Some(table) => table[input_code]
        None => input
      }
      let code = byte.to_int()
      if squeeze is Some(table) && code == previous && table[code] {
        continue
      }
      out.push(byte)
      previous = code
    }
    if !out.is_empty() {
      @stdio.stdout.write(Bytes::from_array(out))
    }
  }
}

///|
async fn main {
  let args = @env.args()[1:]
  let parsed = @cli.parse(args, [
    @cli.flag("delete", short='d'),
    @cli.flag("squeeze-repeats", short='s'),
    @cli.flag("complement", short='c'),
    @cli.flag("help"),
  ]) catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.write("tr: \{message}: '\{option}'\n")
      @sys.exit(2)
      return
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.write("Usage: tr [-dsc] SET1 [SET2]\n")
    return
  }
  let delete = parsed.contains("delete")
  let squeeze_repeats = parsed.contains("squeeze-repeats")
  let complement = parsed.contains("complement")
  let sets = parsed.operands
  if sets.is_empty() {
    @stdio.stderr.write("tr: missing operand\n")
    @sys.exit(2)
    return
  }
  if sets.length() > 2 {
    @stdio.stderr.write("tr: extra operand '\{sets[2]}'\n")
    @sys.exit(2)
    return
  }
  try {
    let set1_bytes = {
      let expanded = expand_set(sets[0])
      if complement {
        complement_set(expanded)
      } else {
        expanded
      }
    }
    let set2_bytes = if sets.length() > 1 { expand_set(sets[1]) } else { [] }
    if !delete && sets.length() == 1 && !squeeze_repeats {
      raise CliError("tr: two sets must be given when translating")
    }
    if delete && sets.length() > 1 && !squeeze_repeats {
      raise CliError(
        "tr: extra operand '\{sets[1]}' (a second set is only used with -s)",
      )
    }
    if delete && squeeze_repeats && sets.length() == 1 {
      raise CliError(
        "tr: two sets must be given when both deleting and squeezing repeats",
      )
    }
    if delete {
      transform_stream(
        Some(membership(set1_bytes)),
        None,
        if squeeze_repeats && sets.length() > 1 {
          Some(membership(set2_bytes))
        } else {
          None
        },
      )
    } else if sets.length() > 1 {
      if set2_bytes.is_empty() {
        raise CliError("tr: SET2 must be non-empty when translating")
      }
      let map = FixedArray::make(256, b'\x00')
      for code in 0..<=255 {
        map[code] = code.to_byte()
      }
      for index, from in set1_bytes {
        let to = if index < set2_bytes.length() {
          set2_bytes[index]
        } else {
          set2_bytes[set2_bytes.length() - 1]
        }
        map[from.to_int()] = to
      }
      transform_stream(
        None,
        Some(map),
        if squeeze_repeats {
          Some(membership(set2_bytes))
        } else {
          None
        },
      )
    } else {
      // -s with a single set.
      transform_stream(None, None, Some(membership(set1_bytes)))
    }
  } catch {
    CliError(msg) => {
      @stdio.stderr.write("\{msg}\n")
      @sys.exit(2)
      return
    }
    err => {
      @stdio.stderr.write("tr: \{err}\n")
      @sys.exit(1)
      return
    }
  }
}
