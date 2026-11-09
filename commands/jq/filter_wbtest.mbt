///|
test "jq slices reject invalid types and preserve optional catch" {
  let query = parse_filter(".[1:3]")
  try @ast.eval(query, Json::number(42)).collect() catch {
    _ => ()
  } noraise {
    _ => fail("numeric slice must raise rather than return null")
  }
  assert_eq(@ast.eval(parse_filter(".[1:3]?"), Json::number(42)).collect(), [])
}
