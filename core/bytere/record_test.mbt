///|
test "record matcher keeps boolean search and leftmost-longest extraction separate" {
  let matcher = @bytere.compile("a|aa", extended=true).record_matcher()
  assert_true(matcher.matches(b"zaa"))
  assert_eq(matcher.find_span("zaa"), Some((1, 3)))
  assert_true(!matcher.matches(b"zaa", whole=true))
  assert_true(matcher.matches(b"aa", whole=true))
  assert_true(!matcher.matches(b"zaa", word=true))
  assert_true(matcher.matches(b" aa!", word=true))
}
