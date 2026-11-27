///|
test "truncate size arithmetic honors units bounds and rounding" {
  assert_eq(@resize.target(@resize.parse("1KiB"), 1L), 1024L)
  assert_eq(@resize.target(@resize.parse(">8"), 2L), 8L)
  assert_eq(@resize.target(@resize.parse("<8"), 12L), 8L)
  assert_eq(@resize.target(@resize.parse("-10"), 2L), 0L)
  assert_eq(@resize.target(@resize.parse("%4"), 5L), 8L)
  assert_eq(@resize.target(@resize.parse("/4"), 5L), 4L)
  try @resize.target(@resize.parse("+1"), 9223372036854775807L) catch {
    _ => ()
  } noraise {
    _ => fail("overflow accepted")
  }
}
