///|
test "sorting type rejection and key errors remain observable" {
  for input in ["null", "{}", "42", "\"text\""] {
    let rejected = try {
      ignore(@engine.compile("sort_by(.)").apply(@json.parse(input)))
      false
    } catch {
      _ => true
    }
    assert_true(rejected, msg=input)
  }
  assert_eq(
    @engine.compile("try sort_by(. / 0) catch \"caught\"").apply(
      @json.parse("[1,2]"),
    ),
    [Json::string("caught")],
  )
}
