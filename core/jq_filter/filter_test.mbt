///|
test "jq string conversions and nested scalar-index slicing" {
  for
    (query, input, expected) in [
      ("tostring", Json::number(1), [Json::string("1")]),
      (
        "map(tostring)",
        Json::array([Json::boolean(true), Json::null(), Json::string("x")]),
        [
          Json::array([
            Json::string("true"),
            Json::string("null"),
            Json::string("x"),
          ]),
        ],
      ),
      (
        "tojson",
        Json::object({ "a": Json::string("b\n\"c") }),
        [Json::string("{\"a\":\"b\\n\\\"c\"}")],
      ),
      (".[1:-1]", Json::string("abcd"), [Json::string("bc")]),
      (".[1:3]", Json::string("a😀文z"), [Json::string("😀文")]),
      (
        "map(.[-2:])",
        Json::array([Json::string("abc"), Json::string("😀文z")]),
        [Json::array([Json::string("bc"), Json::string("文z")])],
      ),
      (
        "{x: .[1:]}",
        Json::string("abc"),
        [Json::object({ "x": Json::string("bc") })],
      ),
      ("def tail: .[1:]; tail", Json::string("abc"), [Json::string("bc")]),
      ("tojson | .[1:-1]", Json::string("a\n\"b"), [Json::string("a\\n\\\"b")]),
      (".[1:3]", Json::array([1, 2, 3, 4]), [Json::array([2, 3])]),
      (".[1:3]", Json::null(), [Json::null()]),
    ] {
    assert_eq(@ast.eval(@jq_filter.parse(query), input).collect(), expected)
  }
}

///|
test "jq slices reject invalid types and preserve optional catch" {
  let query = @jq_filter.parse(".[1:3]")
  try @ast.eval(query, Json::number(42)).collect() catch {
    _ => ()
  } noraise {
    _ => fail("numeric slice must raise rather than return null")
  }
  assert_eq(
    @ast.eval(@jq_filter.parse(".[1:3]?"), Json::number(42)).collect(),
    [],
  )
}
