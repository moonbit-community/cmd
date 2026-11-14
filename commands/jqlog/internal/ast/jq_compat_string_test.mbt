///|
// Adapted from MoonJQ 0.2.0 for local ownership and current syntax.
// See ../../THIRD_PARTY_NOTICES.md for source and license information.

///|
/// jq-compat tests for string helpers

///|
test "jq compat: split keeps empty segments" {
  let results = coverage_eval("split(\"/\")", "\"a/b//c/\"")
  json_inspect(results, content=[["a", "b", "", "c", ""]])
}

///|
test "jq compat: ltrimstr removes prefix only" {
  json_inspect(coverage_eval("ltrimstr(\"foo\")", "\"foobar\""), content=["bar"])
  json_inspect(coverage_eval("ltrimstr(\"bar\")", "\"foobar\""), content=[
    "foobar",
  ])
}

///|
test "jq compat: rtrimstr removes suffix only" {
  json_inspect(coverage_eval("rtrimstr(\"bar\")", "\"foobar\""), content=["foo"])
  json_inspect(coverage_eval("rtrimstr(\"baz\")", "\"foobar\""), content=[
    "foobar",
  ])
}

///|
test "jq compat: ascii_upcase/downcase only affects ASCII" {
  json_inspect(coverage_eval("ascii_downcase", "\"AbÇ\""), content=["abÇ"])
  json_inspect(coverage_eval("ascii_upcase", "\"AbÇ\""), content=["ABÇ"])
}
