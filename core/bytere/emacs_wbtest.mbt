///|
test "Emacs byte syntax separates operators line anchors and buffer anchors" {
  assert_eq(compile("a+", emacs=true).find_span("aaa"), Some((0, 3)))
  assert_eq(compile("a\\+", emacs=true).find_span("aa+"), Some((1, 3)))
  assert_eq(compile("a\\{2\\}", emacs=true).find_span("a{2}"), Some((0, 4)))
  assert_eq(compile("^a$", emacs=true).find_span("x\na\nb"), Some((2, 3)))
  assert_eq(compile(".", emacs=true).find_span("\n\u0000"), Some((1, 2)))
  assert_eq(compile("\\`a", emacs=true).find_span("x\na"), None)
  assert_eq(compile("[[:digit:]]", emacs=true).find_span("1"), None)
  assert_eq(compile("[z-a]", emacs=true).find_span("z"), None)
}

///|
test "backward span search uses a logical prefix and guarantees empty progress" {
  let overlap = compile("aba", emacs=true)
  assert_eq(overlap.rfind_span("ababaX", 6), Some((2, 5)))
  assert_eq(overlap.rfind_span("ababaX", 2), None)
  assert_eq(compile("a*", emacs=true).rfind_span("aaBC", 4), Some((3, 3)))
  assert_eq(compile("a*", emacs=true).rfind_span("aaBC", 0), None)
  assert_eq(compile("a$", emacs=true).rfind_span("abaX", 3), Some((2, 3)))
  assert_eq(
    compile("\\(ab\\)\\1", emacs=true).rfind_span("ababX", 5),
    Some((0, 4)),
  )
}
