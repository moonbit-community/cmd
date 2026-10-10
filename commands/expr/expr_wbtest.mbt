///|
test "expr precedence arbitrary integers and comparison" {
  assert_eq(evaluate(["2", "+", "3", "*", "4"]), "14")
  assert_eq(evaluate(["(", "2", "+", "3", ")", "*", "4"]), "20")
  assert_eq(
    evaluate(["999999999999999999999999999999", "+", "1"]),
    "1000000000000000000000000000000",
  )
  assert_eq(evaluate(["007", "=", "7"]), "1")
  assert_eq(evaluate(["-7", "/", "3"]), "-2")
  assert_eq(evaluate(["-7", "%", "3"]), "-1")
  assert_eq(evaluate(["a", "<", "b"]), "1")
}

///|
test "expr short circuit parses but does not evaluate skipped operations" {
  assert_eq(evaluate(["yes", "|", "1", "/", "0"]), "yes")
  assert_eq(evaluate(["0", "&", "1", "/", "0"]), "0")
  assert_eq(evaluate(["yes", "|", "match", "a", "["]), "yes")
  assert_eq(evaluate(["", "|", "0"]), "0")
  assert_eq(evaluate(["00", "|", "fallback"]), "fallback")
  assert_eq(evaluate(["a", "&", "b"]), "a")
}

///|
test "expr functions and anchored BRE captures" {
  assert_eq(evaluate(["length", "+", "match"]), "5")
  assert_eq(evaluate(["substr", "abcdef", "2", "3"]), "bcd")
  assert_eq(evaluate(["substr", "abcdef", "-1", "3"]), "")
  assert_eq(evaluate(["index", "abcdef", "fc"]), "3")
  assert_eq(evaluate(["abc", ":", "a.*"]), "3")
  assert_eq(evaluate(["abc", ":", "b"]), "0")
  assert_eq(evaluate(["abc", ":", "a\\(b.*\\)"]), "bc")
  assert_eq(evaluate(["abc", ":", "z\\(.*\\)"]), "")
}
