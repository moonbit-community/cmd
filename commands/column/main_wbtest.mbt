///|
test "column aligns whitespace fields" {
  assert_eq(
    table(["name age", "Ada 36", "Bob 7"], None, "  "),
    "name  age\nAda   36\nBob   7\n",
  )
}

///|
test "column accepts an explicit delimiter and output separator" {
  assert_eq(table(["a:b", "cc:ddd"], Some(":"), " | "), "a  | b\ncc | ddd\n")
}

///|
test "column handles empty fields, uneven rows and multiple delimiters" {
  assert_eq(
    table(["a::b,c", "xx:,d"], Some(":,"), "  "),
    "a     b  c\nxx    d  \n",
  )
  assert_eq(
    table(["a b", "c", "z d e"], None, "  "),
    "a  b  \nc     \nz  d  e\n",
  )
  assert_eq(table(["a b", "cc dd"], Some(""), "  "), "a b\ncc dd\n")
}

///|
test "column fills columns and rows at explicit widths" {
  assert_eq(columns(["a", "b", "c", "d", "e"], 16, false), "a\td\nb\te\nc\n")
  assert_eq(columns(["a", "b", "c", "d", "e"], 16, true), "a\tb\nc\td\ne\n")
  assert_eq(columns(["one", "two"], 80, false), "one\ttwo\n")
  assert_eq(columns(["one", "two"], 0, false), "one\ntwo\n")
  assert_eq(input_lines(b" \t\nhello\x00hidden\n\xff x\n"), ["hello", "\\xff x"])
}

///|
test "column table width ignores complete color escapes only" {
  assert_eq(
    table(["a\u001b[31mb:c", "long:d"], Some(":"), "  "),
    "a\u001b[31mb    c\nlong  d\n",
  )
  assert_eq(display_width("a\u001b[31mb"), 6)
  assert_eq(display_width("a\u001b[31mb", table=true), 2)
  assert_eq(display_width("a\u001b[31b", table=true), 5)
}
