///|
// Adapted from MoonJQ 0.2.0 for local ownership and current syntax.
// See ../../THIRD_PARTY_NOTICES.md for source and license information.

///|
test "while yields intermediate values" {
  json_inspect(coverage_eval("while(. < 4; . + 1)", "1"), content=[1, 2, 3])
}

///|
test "until terminates and returns final value" {
  json_inspect(coverage_eval("until(. > 3; . + 1)", "1"), content=[4])
}

///|
test "limit takes first N results" {
  json_inspect(coverage_eval("limit(2; .[])", "[1, 2, 3]"), content=[1, 2])
}

///|
test "reduce aggregates with variable binding" {
  json_inspect(coverage_eval("reduce .[] as $x (0; . + $x)", "[1, 2, 3]"), content=[
    6,
  ])
}

///|
test "foreach emits running accumulator" {
  json_inspect(coverage_eval("foreach .[] as $x (0; . + $x)", "[1, 2, 3]"), content=[
    1, 3, 6,
  ])
}

///|
test "foreach supports extract expression" {
  json_inspect(
    coverage_eval("foreach .[] as $x (0; . + $x; . * 2)", "[1, 2, 3]"),
    content=[2, 6, 12],
  )
}

///|
test "scan emits non-overlapping matches" {
  json_inspect(coverage_eval("scan(\"aa\")", "\"aaaaa\""), content=["aa", "aa"])
}

///|
test "recurse(f; cond) applies f transitively" {
  let input : String =
    #|{
    #|  "a": {
    #|    "a": null
    #|  }
    #|}
  json_inspect(coverage_eval("recurse(.a; . != null)", input), content=[
    { "a": { "a": null } },
    { "a": null },
  ])
}

///|
test "walk transforms nested numbers" {
  let input : String =
    #|{
    #|  "a": [1, { "b": 2 }],
    #|  "c": "x"
    #|}
  json_inspect(
    coverage_eval("walk(if type == \"number\" then . + 1 else . end)", input),
    content=[{ "a": [2, { "b": 3 }], "c": "x" }],
  )
}
