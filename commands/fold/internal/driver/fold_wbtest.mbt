///|
fn folded(
  data : Bytes,
  width : Int32,
  bytes~ : Bool = false,
  spaces~ : Bool = false,
) -> Bytes {
  let state = FoldState::new(width, bytes, false, spaces)
  let out = state.feed(data).to_array()
  out.append(state.pending)
  Bytes::from_array(out)
}

///|
test "fold width and final newline" {
  assert_eq(folded(b"abcdef\nxy", 3), b"abc\ndef\nxy")
  assert_eq(folded(b"abc\n", 3), b"abc\n")
  assert_eq(folded(b"", 3), b"")
}

///|
test "fold blank boundaries preserve blanks and split oversized words" {
  assert_eq(folded(b"aa bb cccccc", 5, spaces=true), b"aa \nbb \nccccc\nc")
  assert_eq(folded(b" abc def", 4, spaces=true), b" \nabc \ndef")
}

///|
test "fold tab backspace carriage return and raw bytes" {
  assert_eq(folded(b"a\tb", 4), b"a\n\t\nb")
  assert_eq(folded(b"ab\bcd\rabc", 3), b"ab\bcd\rabc")
  assert_eq(folded(b"ab\bcd", 3, bytes=true), b"ab\b\ncd")
  assert_eq(folded(b"a\x00\xffb", 2), b"a\x00\xff\nb")
}

///|
test "fold is independent of incoming chunk boundaries" {
  let state = FoldState::new(5, false, false, true)
  let out = state.feed(b"aa b").to_array()
  out.append(state.feed(b"b ccc").to_array())
  out.append(state.feed(b"ccc").to_array())
  out.append(state.pending)
  assert_eq(Bytes::from_array(out), b"aa \nbb \nccccc\nc")
}
