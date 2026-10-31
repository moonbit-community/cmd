///|
test "grouping orders key streams and preserves member encounter order" {
  for
    (query, input, expected) in [
      (
        "group_by(.active) | map(map(.id))", "[{\"id\":\"t1\",\"active\":true},{\"id\":\"t2\",\"active\":true},{\"id\":\"f\",\"active\":false},{\"id\":\"n\"}]",
        "[[\"n\"],[\"f\"],[\"t1\",\"t2\"]]",
      ),
      (
        "group_by(.a,.b) | map(map(.id))", "[{\"id\":\"x\",\"a\":1,\"b\":2},{\"id\":\"y\",\"a\":1,\"b\":1},{\"id\":\"z\",\"a\":1,\"b\":2}]",
        "[[\"y\"],[\"x\",\"z\"]]",
      ),
      (
        "group_by(if .none then empty else null end) | map(map(.id))", "[{\"id\":\"none\",\"none\":true},{\"id\":\"null\",\"none\":false},{\"id\":\"none2\",\"none\":true}]",
        "[[\"none\",\"none2\"],[\"null\"]]",
      ),
      (
        "group_by(.key) | map(map(.id))", "[{\"id\":\"p\",\"key\":{\"a\":1,\"b\":2}},{\"id\":\"q\",\"key\":{\"b\":2,\"a\":1}},{\"id\":\"r\",\"key\":{\"a\":2}}]",
        "[[\"r\"],[\"p\",\"q\"]]",
      ),
      (
        "group_by(.)", "[2,1,2,null,false,true,\"2\"]", "[[null],[false],[true],[1],[2,2],[\"2\"]]",
      ),
      ("group_by(.) | map(length)", "[0,-0,0.0,1,1.0,1e0]", "[3,3]"),
      ("group_by(.+1)", "[2,1,2]", "[[1],[2,2]]"),
      ("group_by(empty)", "[2,1,2]", "[[2,1,2]]"),
      ("group_by(.)", "[]", "[]"),
      (
        "2 as $__cli_group_keys | group_by(. + $__cli_group_keys)", "[2,1,2]", "[[1],[2,2]]",
      ),
      (
        "map(group_by(.))", "[[2,1,2],[false,null,true]]", "[[[1],[2,2]],[[null],[false],[true]]]",
      ),
    ] {
    let result = @ast.eval(@jq_filter.parse(query), @json.parse(input)).collect()
    assert_eq(result, [@json.parse(expected)], msg=query)
  }
}

///|
test "grouping rejects outer types before key evaluation and retains errors" {
  for input in ["null", "42", "{}", "\"text\""] {
    let rejected = try {
      ignore(
        @ast.eval(@jq_filter.parse("group_by(.)"), @json.parse(input)).collect(),
      )
      false
    } catch {
      _ => true
    }
    assert_true(rejected, msg=input)
  }
  assert_eq(
    @ast.eval(
      @jq_filter.parse("try group_by(. / 0) catch \"caught\""),
      @json.parse("[1,2]"),
    ).collect(),
    [Json::string("caught")],
  )
}

///|
test "grouping full keys survive debug depth and preserve large literal identity" {
  let mut a : Json = Json::number(1)
  let mut b : Json = Json::number(2)
  for _ in 0..<40 {
    a = Json::object({ "n": a })
    b = Json::object({ "n": b })
  }
  assert_eq(
    @ast.eval(
      @jq_filter.parse("group_by(.) | map(length)"),
      Json::array([a, b, a]),
    ).collect(),
    [@json.parse("[2,1]")],
  )
  let input = @json.parse("[9007199254740992,9007199254740993]")
  assert_eq(
    @ast.eval(@jq_filter.parse("group_by(.) | map(length)"), input).collect(),
    [@json.parse("[1,1]")],
  )
}
