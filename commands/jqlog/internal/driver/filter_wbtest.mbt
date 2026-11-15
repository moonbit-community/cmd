///|
test "jq slices reject invalid types and preserve optional catch" {
  let query = @engine.compile(".[1:3]")
  try query.apply(Json::number(42)) catch {
    _ => ()
  } noraise {
    _ => fail("numeric slice must raise rather than return null")
  }
  assert_eq(@engine.compile(".[1:3]?").apply(Json::number(42)), [])
}
