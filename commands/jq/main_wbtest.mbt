///|
test "jq sort and output modes are deterministic" {
  let value = @json.parse("{\"z\":1,\"a\":2}")
  assert_eq(
    render_result(value, false, true, true, None, false),
    "{\"a\":2,\"z\":1}",
  )
  assert_eq(status_for_results([@json.parse("false")]), 1)
  assert_eq(status_for_results([@json.parse("null")]), 1)
  assert_eq(status_for_results([@json.parse("true")]), 0)
}

///|
test "jq raw input framing omits terminal empty records" {
  assert_eq(raw_values("one\ntwo\n"), [
    @json.parse("\"one\""),
    @json.parse("\"two\""),
  ])
}
