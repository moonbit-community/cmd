///|
test "streaming SHA1 matches standard vectors across padding boundaries" {
  for length in [0, 1, 55, 56, 63, 64, 65, 127, 128, 129, 65535, 65536, 65537] {
    let bytes = Bytes::makei(length, i => (i * 37 % 256).to_byte())
    let expected = @crypto.bytes_to_hex_string(@crypto.sha1(bytes))
    for chunk_size in [1, 7, 64, 65536] {
      let hasher = Sha1State::new()
      let mut offset = 0
      while offset < length {
        let end = if offset + chunk_size < length {
          offset + chunk_size
        } else {
          length
        }
        hasher.update(bytes[offset:end])
        offset = end
      }
      assert_eq(hasher.finalize(), expected)
    }
  }
  let state = Sha1State::new()
  state.update(b"abc"[:])
  assert_eq(state.finalize(), "a9993e364706816aba3e25717850c26c9cd0d89d")
}

///|
test "checksum records preserve escaped filenames and markers" {
  let digest = "900150983cd24fb0d6963f7d28e17f72"
  assert_eq(
    format_record(digest, "payload", false, false),
    digest + "  payload\n",
  )
  assert_eq(
    format_record(digest, "payload", true, false),
    digest + " *payload\n",
  )
  let name = "a\\b\nc\r"
  let record = format_record(digest, name, false, false)
  assert_eq(record, "\\" + digest + "  a\\\\b\\nc\\r\n")
  assert_eq(
    parse_record(Md5, record[:record.length() - 1].to_owned()),
    Some((digest, name)),
  )
  assert_eq(
    format_record(digest, name, false, true),
    digest + "  " + name + "\u0000",
  )
}

///|
test "checksum parser checks algorithm length syntax and invalid escapes" {
  let digest = "900150983cd24fb0d6963f7d28e17f72"
  assert_eq(
    parse_record(Md5, digest.to_upper() + " *payload"),
    Some((digest, "payload")),
  )
  assert_eq(parse_record(Sha1, digest + "  payload"), None)
  assert_eq(parse_record(Md5, digest + " ?payload"), None)
  assert_eq(parse_record(Md5, digest + "  "), None)
  assert_eq(parse_record(Md5, "\\" + digest + "  bad\\q"), None)
  assert_eq(parse_record(Md5, digest + "  nul\u0000name"), None)
}
