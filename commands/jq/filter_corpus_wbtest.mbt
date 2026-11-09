///|
async test "complete shared jq adapter corpus preserves independent expectations" {
  let mut root = @fs.realpath(".")
  while !@fs.exists(root + "/moon.work") {
    let parent = @fs.realpath(root + "/..")
    guard parent != root else { fail("jq corpus workspace is missing") }
    root = parent
  }
  let value = @json.parse(
    @fs.read_file(root + "/tests/fixtures/jq/adapter.json").text(),
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
    assert_eq(@ast.eval(parse_filter(query), input).collect(), expected, msg=id)
  }
}
