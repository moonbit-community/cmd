///|
test "sorting captures full key streams and retains equal-key source order" {
  let input = @json.parse(
    "[{\"id\":\"x\",\"a\":1,\"b\":2},{\"id\":\"y\",\"a\":1,\"b\":1},{\"id\":\"z\",\"a\":1,\"b\":2}]",
  )
  assert_eq(
    @ast.eval(@jq_filter.parse("sort_by(.a,.b) | map(.id)"), input).collect(),
    [@json.parse("[\"y\",\"x\",\"z\"]")],
  )
  let rows = Array::makei(3000, i => {
    Json::object({ "key": Json(i % 3), "id": Json(i) })
  })
  let ordered : Array[Json] = []
  for key in [0, 1, 2] {
    ordered.append(
      rows.filter(row => {
        row is { "key": Number(value, ..), .. } && value == key.to_double()
      }),
    )
  }
  let expected = Json::array(ordered)
  assert_eq(
    @ast.eval(@jq_filter.parse("sort_by(.key)"), Json::array(rows)).collect(),
    [expected],
  )
  assert_eq(
    @ast.eval(@jq_filter.parse("sort_by(empty)"), Json::array(rows)).collect(),
    [Json::array(rows)],
  )
  assert_eq(
    @ast.eval(
      @jq_filter.parse("2 as $__cli_sort_keys | sort_by(. + $__cli_sort_keys)"),
      @json.parse("[2,1,2]"),
    ).collect(),
    [@json.parse("[1,2,2]")],
  )
}

///|
test "sorting type rejection and key errors remain observable" {
  for input in ["null", "{}", "42", "\"text\""] {
    let rejected = try {
      ignore(
        @ast.eval(@jq_filter.parse("sort_by(.)"), @json.parse(input)).collect(),
      )
      false
    } catch {
      _ => true
    }
    assert_true(rejected, msg=input)
  }
  assert_eq(
    @ast.eval(
      @jq_filter.parse("try sort_by(. / 0) catch \"caught\""),
      @json.parse("[1,2]"),
    ).collect(),
    [Json::string("caught")],
  )
}
