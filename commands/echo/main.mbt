///|
fn hex_value(c : Char) -> Int {
  match c {
    '0'..='9' => c.to_int() - '0'.to_int()
    'a'..='f' => c.to_int() - 'a'.to_int() + 10
    'A'..='F' => c.to_int() - 'A'.to_int() + 10
    _ => -1
  }
}

///|
fn append_char(out : Array[Byte], c : Char) -> Unit {
  for byte in @utf8.encode(c.to_string()) {
    out.push(byte)
  }
}

///|
fn decode_escapes(text : String) -> (Bytes, Bool) {
  let chars : Array[Char] = text.iter().collect()
  let out : Array[Byte] = []
  let mut stopped = false
  let mut i = 0
  while i < chars.length() && !stopped {
    if chars[i] != '\\' || i + 1 >= chars.length() {
      append_char(out, chars[i])
      i += 1
      continue
    }
    let escaped = chars[i + 1]
    let simple = match escaped {
      'a' => 0x07
      'b' => 0x08
      'e' => 0x1B
      'f' => 0x0C
      'n' => 0x0A
      'r' => 0x0D
      't' => 0x09
      'v' => 0x0B
      '\\' => 0x5C
      _ => -1
    }
    if simple >= 0 {
      out.push(simple.to_byte())
      i += 2
    } else if escaped == 'c' {
      stopped = true
    } else if escaped == 'x' {
      let mut value = 0
      let mut count = 0
      let mut j = i + 2
      while j < chars.length() && count < 2 && hex_value(chars[j]) >= 0 {
        value = value * 16 + hex_value(chars[j])
        count += 1
        j += 1
      }
      if count == 0 {
        out.push(b'\\')
        out.push(b'x')
        i += 2
      } else {
        out.push(value.to_byte())
        i = j
      }
    } else if escaped is ('0'..='7') {
      let mut value = 0
      let mut count = 0
      let mut j = if escaped == '0' { i + 2 } else { i + 1 }
      while j < chars.length() && count < 3 && chars[j] is ('0'..='7') {
        value = value * 8 + chars[j].to_int() - '0'.to_int()
        count += 1
        j += 1
      }
      out.push(value.to_byte())
      i = j
    } else {
      out.push(b'\\')
      append_char(out, escaped)
      i += 2
    }
  }
  (Bytes::from_array(out), stopped)
}

///|
async fn main {
  let args = @env.args()[1:]
  if args.length() == 1 && args[0] == "--help" {
    @stdio.stdout.write("Usage: echo [-n] [-e|-E] [STRING...]\n")
    return
  }
  if args.length() == 1 && args[0] == "--version" {
    @stdio.stdout.write("echo (moonbit cmd) 0.1.3\n")
    return
  }
  let mut newline = true
  let mut escapes = false
  let mut index = 0
  while index < args.length() {
    let arg = args[index]
    if !arg.has_prefix("-") || arg == "-" || arg == "--" {
      break
    }
    let mut valid = true
    for c in arg[1:] {
      if c != 'n' && c != 'e' && c != 'E' {
        valid = false
      }
    }
    if !valid {
      break
    }
    for c in arg[1:] {
      match c {
        'n' => newline = false
        'e' => escapes = true
        'E' => escapes = false
        _ => ()
      }
    }
    index += 1
  }
  if escapes {
    let mut stopped = false
    for operand_index in index..<args.length() {
      if operand_index > index {
        @stdio.stdout.write(" ")
      }
      let (output, operand_stopped) = decode_escapes(args[operand_index])
      @stdio.stdout.write(output)
      if operand_stopped {
        stopped = true
        break
      }
    }
    if newline && !stopped {
      @stdio.stdout.write("\n")
    }
  } else {
    @stdio.stdout.write(args[index:].join(" "))
    if newline {
      @stdio.stdout.write("\n")
    }
  }
}
