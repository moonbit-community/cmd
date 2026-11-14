///|
test "sorting type rejection and key errors remain observable" {
  for input in ["null", "{}", "42", "\"text\""] {
    let rejected = try {
      ignore(
        @ast.eval(parse_filter("sort_by(.)"), @json.parse(input)).collect(),
      )
      false
    } catch {
      _ => true
    }
    assert_true(rejected, msg=input)
  }
  assert_eq(
    @ast.eval(
      parse_filter("try sort_by(. / 0) catch \"caught\""),
      @json.parse("[1,2]"),
    ).collect(),
    [Json::string("caught")],
  )
}
