///|
fn normalization_literal(value : StringView) -> String raise {
  let result = StringBuilder()
  for scalar in value.trim().split(" ") {
    if scalar.is_empty() {
      continue
    }
    let code = @string.parse_int(scalar, base=16)
    guard code.to_char() is Some(character) else {
      fail("invalid normalization corpus scalar")
    }
    result.write_char(character)
  }
  result.to_string()
}

///|
async test "released NFC primitive preserves the complete Unicode 15 corpus" {
  let mut root = @fs.realpath(".")
  while !@fs.exists(root + "/moon.work") {
    let parent = @path.Path(root).dirname().to_string()
    guard parent != root else { fail("normalization corpus workspace missing") }
    root = parent
  }
  let bytes = @fs.read_file(root + "/tests/fixtures/idna/NormalizationTest.txt").binary()
  assert_eq(
    @crypto.bytes_to_hex_string(@crypto.sha256(bytes)),
    "fb9ac8cc154a80cad6caac9897af55a4e75176af6f4e2bb6edc2bf8b1d57f326",
  )
  let mut records = 0
  for line in @utf8.decode(bytes).split("\n") {
    let content = line.split("#").next().unwrap().trim()
    if content.is_empty() || content.has_prefix("@") {
      continue
    }
    let columns = content.split(";").to_array()
    assert_eq(columns.length(), 6)
    assert_true(columns[5].trim().is_empty())
    let values = columns[:5].map(normalization_literal)
    for index in 0..<3 {
      assert_eq(
        @normalization.nfc(values[index]),
        values[1],
        msg="NFC corpus record \{records}, column \{index}",
      )
    }
    for index in 3..<5 {
      assert_eq(
        @normalization.nfc(values[index]),
        values[3],
        msg="NFC corpus record \{records}, column \{index}",
      )
    }
    records += 1
  }
  assert_eq(records, 19074)
}
