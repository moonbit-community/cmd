///|
test "grouping rejects outer types before key evaluation and retains errors" {
  for input in ["null", "42", "{}", "\"text\""] {
    let rejected = try {
      ignore(@engine.compile("group_by(.)").apply(@json.parse(input)))
      false
    } catch {
      _ => true
    }
    assert_true(rejected, msg=input)
  }
  assert_eq(
    @engine.compile("try group_by(. / 0) catch \"caught\"").apply(
      @json.parse("[1,2]"),
    ),
    [Json::string("caught")],
  )
}
