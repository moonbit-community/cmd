///|
fn number(value : Int64, radix : Int32, width : Int32) -> String {
  let digits = "0123456789abcdef"
  let chars : Array[Char] = []
  let mut value = value
  for ;; {
    chars.push(
      digits[(value % radix.to_int64()).to_int()].to_int().unsafe_to_char(),
    )
    value /= radix.to_int64()
    if value == 0L {
      break
    }
  }
  while chars.length() < width {
    chars.push('0')
  }
  let out = StringBuilder()
  for i = chars.length() - 1; i >= 0; i = i - 1 {
    out.write_char(chars[i])
  }
  out.to_string()
}

///|
fn spaces(n : Int32) -> String {
  let out = StringBuilder()
  for _ in 0..<n {
    out.write_char(' ')
  }
  out.to_string()
}

///|
fn character(byte : Byte) -> String {
  let n = byte.to_int()
  let result = if n >= 32 && n <= 126 {
    n.unsafe_to_char().to_string()
  } else {
    match n {
      0 => "\\0"
      7 => "\\a"
      8 => "\\b"
      9 => "\\t"
      10 => "\\n"
      11 => "\\v"
      12 => "\\f"
      13 => "\\r"
      _ => number(n.to_int64(), 8, 3)
    }
  }
  spaces(3 - result.length()) + result
}

///|
fn render_row(data : Bytes, offset : Int64, mode : String) -> String {
  let out = StringBuilder()
  out.write_string(number(offset, 16, if mode == "canonical" { 8 } else { 7 }))
  if mode == "canonical" {
    out.write_string("  ")
    for i in 0..<16 {
      if i > 0 {
        out.write_char(' ')
      }
      if i == 8 {
        out.write_char(' ')
      }
      out.write_string(
        if i < data.length() {
          number(data[i].to_int64(), 16, 2)
        } else {
          "  "
        },
      )
    }
    out.write_string("  |")
    for byte in data {
      out.write_char(
        if byte >= b' ' && byte <= b'~' {
          byte.to_int().unsafe_to_char()
        } else {
          '.'
        },
      )
    }
    out.write_char('|')
  } else {
    let single = mode == "one-byte-octal" ||
      mode == "one-byte-char" ||
      mode == "one-byte-hex"
    let size = if single { 1 } else { 2 }
    let width = match mode {
      "default" => 5
      "one-byte-hex" => 4
      _ => if single { 4 } else { 8 }
    }
    for index in 0..<(16 / size) {
      let at = index * size
      if at >= data.length() {
        out.write_string(spaces(width))
        continue
      }
      let n = data[at].to_int() +
        (if size == 2 && at + 1 < data.length() {
          data[at + 1].to_int() * 256
        } else {
          0
        })
      let text = match mode {
        "one-byte-char" => character(data[at])
        "one-byte-octal" => number(n.to_int64(), 8, 3)
        "two-bytes-octal" => number(n.to_int64(), 8, 6)
        "two-bytes-decimal" => number(n.to_int64(), 10, 5)
        "one-byte-hex" => number(n.to_int64(), 16, 2)
        _ => number(n.to_int64(), 16, 4)
      }
      out.write_string(spaces(width - text.length()))
      out.write_string(text)
    }
  }
  out.write_char('\n')
  out.to_string()
}
