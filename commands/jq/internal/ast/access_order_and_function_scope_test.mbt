///|
// Adapted from MoonJQ 0.2.0 for local ownership and current syntax.
// See ../../THIRD_PARTY_NOTICES.md for source and license information.

///|
test ".[] iterates object values" {
  // Object iteration preserves insertion order.
  json_inspect(coverage_eval(".[]", "{\"a\": 1, \"b\": 2}"), content=[1, 2])
}

///|
test "index on non-array yields nulls" {
  json_inspect(coverage_eval(".[0, 1]", "{\"a\": 1}"), content=[null, null])
}

///|
test "slice on non-array yields null" {
  json_inspect(coverage_eval(".[1:2]", "1"), content=[null])
}

///|
test "optional suppresses evaluation errors" {
  json_inspect(coverage_eval("(1 / 0)?", "null"), content=[])
}

///|
test "in(array) checks index bounds" {
  json_inspect(coverage_eval("0 | in([10, 20])", "null"), content=[true])
  json_inspect(coverage_eval("1 | in([10, 20])", "null"), content=[true])
  json_inspect(coverage_eval("2 | in([10, 20])", "null"), content=[false])
  json_inspect(coverage_eval("-1 | in([10, 20])", "null"), content=[true])
}

///|
test "object-object comparison uses object ordering" {
  json_inspect(coverage_eval("{\"a\":1} < {\"b\":2}", "null"), content=[true])
}

///|
test "comparisons across JSON types" {
  json_inspect(coverage_eval("false < 0", "null"), content=[true])
  json_inspect(coverage_eval("0 > false", "null"), content=[true])
  json_inspect(coverage_eval("0 < \"x\"", "null"), content=[true])
  json_inspect(coverage_eval("\"x\" > 0", "null"), content=[true])
  json_inspect(coverage_eval("\"x\" < [0]", "null"), content=[true])
  json_inspect(coverage_eval("[0] > \"x\"", "null"), content=[true])
  json_inspect(coverage_eval("[0] < {\"a\":1}", "null"), content=[true])
  json_inspect(coverage_eval("{\"a\":1} > [0]", "null"), content=[true])
}

///|
test "function definitions cannot capture later caller bindings" {
  assert_coverage_eval_error(
    "def f: $x; 10 as $x | foreach .[] as $y (0; . + $y + f)", "[1, 2]",
  )
}

///|
test "function call validates argument count" {
  assert_coverage_eval_error("def add(a; b): a + b; add(1)", "null")
}

///|
test "undefined function errors" {
  assert_coverage_eval_error("no_such_fn", "null")
}
