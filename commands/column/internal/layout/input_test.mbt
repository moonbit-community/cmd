///|
fn input_line_scalar(data : Bytes) -> String? {
  let line = StringBuilder()
  for byte in data {
    if byte == 0 {
      break
    }
    if byte >= 128 {
      let hex = "0123456789abcdef"
      line.write_string("\\x")
      line.write_char(hex[byte.to_int() / 16].to_char().unwrap())
      line.write_char(hex[byte.to_int() % 16].to_char().unwrap())
    } else {
      line.write_char(byte.to_int().to_char().unwrap())
    }
  }
  let value = line.to_string()
  if value
    .iter()
    .all(c => c is (' ' | '\t' | '\r' | '\n' | '\u000b' | '\u000c')) {
    None
  } else {
    Some(value)
  }
}

///|
test "column ASCII conversion preserves C-byte escapes NUL truncation and whitespace" {
  for code in 0..<256 {
    let byte = Bytes::from_array([code.to_byte()])
    for
      data in [
        byte,
        b" \t" + byte + b"\r\n",
        b"before\x00" + byte,
        byte + b"\x00after",
      ] {
      assert_eq(@layout.input_line(data[:]), input_line_scalar(data))
    }
  }
  for length in [0, 1, 7, 8, 9, 63, 64, 65, 65535, 65536, 65537] {
    let ascii = Bytes::make(length, b'x')
    for
      data in [
        ascii,
        ascii + b"\xff",
        ascii + b"\x00\xff",
        b"\t\r\n" + Bytes::make(length, b' '),
      ] {
      assert_eq(@layout.input_line(data[:]), input_line_scalar(data))
    }
  }
}
