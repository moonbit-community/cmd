///|
test "A split UTF-8 scalar continues in the next block" {
  let text = "x".repeat(16383) + "🌙z"
  let input = Reader::new(Memory(@utf8.encode(text)))
  assert_eq(input.next(), Some("x".repeat(16383)))
  assert_eq(input.next(), Some("🌙z"))
  assert_eq(input.next(), None)
}

///|
test "Truncated UTF-8 fails when the source ends" {
  let input = Reader::new(Memory(b"a\xf0\x9f"))
  assert_eq(input.next(), Some("a"))
  assert_eq(
    input.next() catch {
      Failure(message) => Some(message)
      err => raise err
    },
    Some("invalid UTF-8 input"),
  )
}
