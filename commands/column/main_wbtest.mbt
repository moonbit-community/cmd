///|
test "column aligns whitespace fields" {
  assert_eq(
    table(["name age", "Ada 36", "Bob 7"], None, " "),
    "name age\nAda  36\nBob  7",
  )
}

///|
test "column accepts an explicit delimiter and output separator" {
  assert_eq(table(["a:b", "cc:ddd"], Some(":"), " | "), "a  | b\ncc | ddd")
}
