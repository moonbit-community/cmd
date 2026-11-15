///|
test "expr precedence arbitrary integers and comparison" {
  assert_eq(@expression.evaluate(["2", "+", "3", "*", "4"]), "14")
  assert_eq(@expression.evaluate(["(", "2", "+", "3", ")", "*", "4"]), "20")
  assert_eq(
    @expression.evaluate(["999999999999999999999999999999", "+", "1"]),
    "1000000000000000000000000000000",
  )
  assert_eq(@expression.evaluate(["007", "=", "7"]), "1")
  assert_eq(@expression.evaluate(["-7", "/", "3"]), "-2")
  assert_eq(@expression.evaluate(["-7", "%", "3"]), "-1")
  assert_eq(@expression.evaluate(["a", "<", "b"]), "1")
}

///|
test "expr short circuit parses but does not evaluate skipped operations" {
  assert_eq(@expression.evaluate(["yes", "|", "1", "/", "0"]), "yes")
  assert_eq(@expression.evaluate(["0", "&", "1", "/", "0"]), "0")
  assert_eq(@expression.evaluate(["yes", "|", "match", "a", "["]), "yes")
  assert_eq(@expression.evaluate(["", "|", "0"]), "0")
  assert_eq(@expression.evaluate(["00", "|", "fallback"]), "fallback")
  assert_eq(@expression.evaluate(["a", "&", "b"]), "a")
}

///|
test "expr functions and anchored BRE captures" {
  assert_eq(@expression.evaluate(["length", "+", "match"]), "5")
  assert_eq(@expression.evaluate(["substr", "abcdef", "2", "3"]), "bcd")
  assert_eq(@expression.evaluate(["substr", "abcdef", "-1", "3"]), "")
  assert_eq(@expression.evaluate(["index", "abcdef", "fc"]), "3")
  assert_eq(@expression.evaluate(["abc", ":", "a.*"]), "3")
  assert_eq(@expression.evaluate(["abc", ":", "b"]), "0")
  assert_eq(@expression.evaluate(["abc", ":", "a\\(b.*\\)"]), "bc")
  assert_eq(@expression.evaluate(["abc", ":", "z\\(.*\\)"]), "")
}
