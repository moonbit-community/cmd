///|
fn parse_record(algorithm : Algorithm, line : String) -> (String, String)? {
  let format : ManifestFormat = {
    reversed: 0,
    label: algorithm.label(),
    sha2_tag: None,
  }
  manifest_record(line, Some(Fixed(algorithm)), false, format).map(record => {
    (@hex.encode(record.expected), record.name)
  })
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
