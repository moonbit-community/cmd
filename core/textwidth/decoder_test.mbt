///|
test "incremental decoding preserves scalars, malformed bytes and truncated tails at every split" {
  let bytes = b"a\xe4\xb8\xad\xf0\x9f\x98\x80\xed\xa0\x80\xe2\x82"
  let expected : Array[Char?] = [
    Some('a'),
    Some('中'),
    Some('😀'),
    None,
    None,
    None,
    None,
    None,
  ]
  for split in 0..<=bytes.length() {
    let decoder = @textwidth.Decoder(Utf8)
    let seen = []
    let raw : Array[Byte] = []
    fn collect(ch : Char?, part : BytesView) {
      seen.push(ch)
      for byte in part {
        raw.push(byte)
      }
    }
    decoder.feed(bytes[:split], collect)
    for i in split..<bytes.length() {
      decoder.feed(bytes[i:i + 1], collect)
    }
    decoder.feed(b"", collect, eof=true)
    assert_eq(seen, expected)
    assert_eq(Bytes::from_array(raw), bytes)
  }
}

///|
test "narrow ambiguous characters, combining marks and wide characters use the selected scalar widths" {
  for
    (ch, width) in [
      ('¡', 1),
      ('中', 2),
      ('\u0301', 0),
      ('\u0000', 0),
      ('\r', 7),
    ] {
    assert_eq(@textwidth.cells(Some(ch), fallback=7), width)
  }
}
