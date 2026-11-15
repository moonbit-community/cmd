///|
async test "complete shared jq adapter corpus preserves independent expectations" {
  let value = @json.parse(
    @fixture_fs.read_file("internal/driver/fixtures/adapter.json").text(),
  )
  guard value
    is {
      "schema": Number(1, ..),
      "count": Number(count, ..),
      "cases": Array(cases),
      ..
    } &&
    count == 28 &&
    cases.length() == 28 else {
    fail("invalid or incomplete jq adapter corpus")
  }
  let seen : Set[String] = Set([])
  for record in cases {
    guard record
      is {
        "id": String(id),
        "query": String(query),
        "input": input,
        "expected": Array(expected),
        ..
      } &&
      !id.is_empty() &&
      !seen.contains(id) else {
      fail("invalid or duplicate jq adapter record")
    }
    seen.add(id)
    assert_eq(@engine.compile(query).apply(input), expected, msg=id)
  }
}
