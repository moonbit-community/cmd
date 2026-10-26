///|
let lines_sherlock : String = "For the Doctor Watsons of this world, as opposed to the Sherlock\nHolmeses, success in the province of detective work must always\nbe, to a very large extent, the result of luck. Sherlock Holmes\ncan extract a clew from a wisp of straw or a flake of cigar ash;\nbut Doctor Watson has to have it taken out for him and dusted,\nand exhibited clearly, with a label attached."

///|
fn lm(start : Int32, end : Int32) -> @matcher.Match {
  { start, end, }
}

///|
fn text_lines(text : String) -> Array[String] {
  let buf = @utf8.encode(text).to_fixedarray()
  let it = LineStep::new(b'\n', 0, buf.length())
  let out = []
  while it.next(buf, 0) is Some(m) {
    out.push(@utf8.decode_lossy(Bytes::from_array(buf[m.start:m.end])))
  }
  out
}

///|
fn line_ranges(text : String) -> Array[@matcher.Match] {
  let buf = @utf8.encode(text).to_fixedarray()
  let it = LineStep::new(b'\n', 0, buf.length())
  let out = []
  while it.next(buf, 0) is Some(m) {
    out.push(m)
  }
  out
}

///|
fn prev(text : String, pos : Int32, count : Int32) -> Int32 {
  let buf = @utf8.encode(text).to_fixedarray()
  preceding(buf, 0, pos, b'\n', count)
}

///|
fn preceding_by_pos(
  text : String,
  pos : Int32,
  lt : Byte,
  count : Int32,
) -> Int32 {
  preceding(@utf8.encode(text).to_fixedarray(), 0, pos, lt, count)
}

///|
fn loc(text : String, start : Int32, end : Int32) -> @matcher.Match {
  let buf = @utf8.encode(text).to_fixedarray()
  locate(buf, 0, buf.length(), b'\n', { start, end, })
}

///|
fn count(text : String, lt : Byte) -> Int64 {
  let bytes = @utf8.encode(text)
  count_lines(bytes.to_fixedarray(), 0, bytes.length(), lt)
}

///|
test "lines/line_count" {
  assert_eq(0L, count("", b'\n'))
  assert_eq(1L, count("\n", b'\n'))
  assert_eq(2L, count("\n\n", b'\n'))
  assert_eq(2L, count("a\nb\nc", b'\n'))
}

///|
test "lines/line_locate" {
  let t = lines_sherlock
  let lines = line_ranges(t)

  assert_eq(
    loc(t, lines[0].start, lines[0].end),
    lm(lines[0].start, lines[0].end),
  )
  assert_eq(
    loc(t, lines[0].start + 1, lines[0].end),
    lm(lines[0].start, lines[0].end),
  )
  assert_eq(
    loc(t, lines[0].end - 1, lines[0].end),
    lm(lines[0].start, lines[0].end),
  )
  assert_eq(
    loc(t, lines[0].end, lines[0].end),
    lm(lines[1].start, lines[1].end),
  )

  assert_eq(
    loc(t, lines[5].start, lines[5].end),
    lm(lines[5].start, lines[5].end),
  )
  assert_eq(
    loc(t, lines[5].start + 1, lines[5].end),
    lm(lines[5].start, lines[5].end),
  )
  assert_eq(
    loc(t, lines[5].end - 1, lines[5].end),
    lm(lines[5].start, lines[5].end),
  )
  assert_eq(
    loc(t, lines[5].end, lines[5].end),
    lm(lines[5].start, lines[5].end),
  )
}

///|
test "lines/line_locate_weird" {
  assert_eq(loc("", 0, 0), lm(0, 0))

  assert_eq(loc("\n", 0, 1), lm(0, 1))
  assert_eq(loc("\n", 1, 1), lm(1, 1))

  assert_eq(loc("\n\n", 0, 0), lm(0, 1))
  assert_eq(loc("\n\n", 0, 1), lm(0, 1))
  assert_eq(loc("\n\n", 1, 1), lm(1, 2))
  assert_eq(loc("\n\n", 1, 2), lm(1, 2))
  assert_eq(loc("\n\n", 2, 2), lm(2, 2))

  assert_eq(loc("a\nb\nc", 0, 1), lm(0, 2))
  assert_eq(loc("a\nb\nc", 1, 2), lm(0, 2))
  assert_eq(loc("a\nb\nc", 2, 3), lm(2, 4))
  assert_eq(loc("a\nb\nc", 3, 4), lm(2, 4))
  assert_eq(loc("a\nb\nc", 4, 5), lm(4, 5))
  assert_eq(loc("a\nb\nc", 5, 5), lm(4, 5))
}

///|
test "lines/line_iter" {
  assert_eq(text_lines("abc"), ["abc"])

  assert_eq(text_lines("abc\n"), ["abc\n"])
  assert_eq(text_lines("abc\nxyz"), ["abc\n", "xyz"])
  assert_eq(text_lines("abc\nxyz\n"), ["abc\n", "xyz\n"])

  assert_eq(text_lines("abc\n\n"), ["abc\n", "\n"])
  assert_eq(text_lines("abc\n\n\n"), ["abc\n", "\n", "\n"])
  assert_eq(text_lines("abc\n\nxyz"), ["abc\n", "\n", "xyz"])
  assert_eq(text_lines("abc\n\nxyz\n"), ["abc\n", "\n", "xyz\n"])
  assert_eq(text_lines("abc\nxyz\n\n"), ["abc\n", "xyz\n", "\n"])

  assert_eq(text_lines("\n"), ["\n"])
  assert_eq(text_lines(""), [])
}

///|
test "lines/line_iter_empty" {
  let it = LineStep::new(b'\n', 0, 0)
  assert_eq(it.next(b"abc".to_fixedarray(), 0), None)
}

///|
test "lines/preceding_lines_doc" {
  // These are the examples mentions in the documentation of `preceding`.
  let bytes = "abc\nxyz\n"
  assert_eq(4, preceding_by_pos(bytes, 7, b'\n', 0))
  assert_eq(4, preceding_by_pos(bytes, 8, b'\n', 0))
  assert_eq(0, preceding_by_pos(bytes, 7, b'\n', 1))
  assert_eq(0, preceding_by_pos(bytes, 8, b'\n', 1))
}

///|
test "lines/preceding_lines_sherlock" {
  let t = lines_sherlock
  let lines = line_ranges(t)

  // The following tests check the count == 0 case, i.e., finding the
  // beginning of the line containing the given position.
  assert_eq(0, prev(t, 0, 0))
  assert_eq(0, prev(t, 1, 0))
  // The line terminator is addressed by `end-1` and terminates the line
  // it is part of.
  assert_eq(0, prev(t, lines[0].end - 1, 0))
  assert_eq(lines[0].start, prev(t, lines[0].end, 0))
  // The end position of line addresses the byte immediately following a
  // line terminator, which puts it on the following line.
  assert_eq(lines[1].start, prev(t, lines[0].end + 1, 0))

  // Now tests for count > 0.
  assert_eq(0, prev(t, 0, 1))
  assert_eq(0, prev(t, 0, 2))
  assert_eq(0, prev(t, 1, 1))
  assert_eq(0, prev(t, 1, 2))
  assert_eq(0, prev(t, lines[0].end - 1, 1))
  assert_eq(0, prev(t, lines[0].end - 1, 2))
  assert_eq(0, prev(t, lines[0].end, 1))
  assert_eq(0, prev(t, lines[0].end, 2))
  assert_eq(lines[3].start, prev(t, lines[4].end - 1, 1))
  assert_eq(lines[3].start, prev(t, lines[4].end, 1))
  assert_eq(lines[4].start, prev(t, lines[4].end + 1, 1))

  // The last line has no line terminator.
  assert_eq(lines[5].start, prev(t, lines[5].end, 0))
  assert_eq(lines[5].start, prev(t, lines[5].end - 1, 0))
  assert_eq(lines[4].start, prev(t, lines[5].end, 1))
  assert_eq(lines[0].start, prev(t, lines[5].end, 5))
}

///|
test "lines/preceding_lines_short" {
  let t = "a\nb\nc\nd\ne\nf\n"
  let lines = line_ranges(t)
  assert_eq(12, @utf8.encode(t).length())

  assert_eq(lines[5].start, prev(t, lines[5].end, 0))
  assert_eq(lines[4].start, prev(t, lines[5].end, 1))
  assert_eq(lines[3].start, prev(t, lines[5].end, 2))
  assert_eq(lines[2].start, prev(t, lines[5].end, 3))
  assert_eq(lines[1].start, prev(t, lines[5].end, 4))
  assert_eq(lines[0].start, prev(t, lines[5].end, 5))
  assert_eq(lines[0].start, prev(t, lines[5].end, 6))

  assert_eq(lines[5].start, prev(t, lines[5].end - 1, 0))
  assert_eq(lines[4].start, prev(t, lines[5].end - 1, 1))
  assert_eq(lines[3].start, prev(t, lines[5].end - 1, 2))
  assert_eq(lines[2].start, prev(t, lines[5].end - 1, 3))
  assert_eq(lines[1].start, prev(t, lines[5].end - 1, 4))
  assert_eq(lines[0].start, prev(t, lines[5].end - 1, 5))
  assert_eq(lines[0].start, prev(t, lines[5].end - 1, 6))

  assert_eq(lines[4].start, prev(t, lines[5].start, 0))
  assert_eq(lines[3].start, prev(t, lines[5].start, 1))
  assert_eq(lines[2].start, prev(t, lines[5].start, 2))
  assert_eq(lines[1].start, prev(t, lines[5].start, 3))
  assert_eq(lines[0].start, prev(t, lines[5].start, 4))
  assert_eq(lines[0].start, prev(t, lines[5].start, 5))

  assert_eq(lines[3].start, prev(t, lines[4].end - 1, 1))
  assert_eq(lines[2].start, prev(t, lines[4].start, 1))

  assert_eq(lines[2].start, prev(t, lines[3].end - 1, 1))
  assert_eq(lines[1].start, prev(t, lines[3].start, 1))

  assert_eq(lines[1].start, prev(t, lines[2].end - 1, 1))
  assert_eq(lines[0].start, prev(t, lines[2].start, 1))

  assert_eq(lines[0].start, prev(t, lines[1].end - 1, 1))
  assert_eq(lines[0].start, prev(t, lines[1].start, 1))

  assert_eq(lines[0].start, prev(t, lines[0].end - 1, 1))
  assert_eq(lines[0].start, prev(t, lines[0].start, 1))
}

///|
test "lines/preceding_lines_empty1" {
  let t = "\n\n\nd\ne\nf\n"
  let lines = line_ranges(t)
  assert_eq(9, @utf8.encode(t).length())

  assert_eq(lines[0].start, prev(t, lines[0].end, 0))
  assert_eq(lines[0].start, prev(t, lines[0].end, 1))
  assert_eq(lines[1].start, prev(t, lines[1].end, 0))
  assert_eq(lines[0].start, prev(t, lines[1].end, 1))

  assert_eq(lines[5].start, prev(t, lines[5].end, 0))
  assert_eq(lines[4].start, prev(t, lines[5].end, 1))
  assert_eq(lines[3].start, prev(t, lines[5].end, 2))
  assert_eq(lines[2].start, prev(t, lines[5].end, 3))
  assert_eq(lines[1].start, prev(t, lines[5].end, 4))
  assert_eq(lines[0].start, prev(t, lines[5].end, 5))
  assert_eq(lines[0].start, prev(t, lines[5].end, 6))
}

///|
test "lines/preceding_lines_empty2" {
  let t = "a\n\n\nd\ne\nf\n"
  let lines = line_ranges(t)
  assert_eq(10, @utf8.encode(t).length())

  assert_eq(lines[0].start, prev(t, lines[0].end, 0))
  assert_eq(lines[0].start, prev(t, lines[0].end, 1))
  assert_eq(lines[1].start, prev(t, lines[1].end, 0))
  assert_eq(lines[0].start, prev(t, lines[1].end, 1))

  assert_eq(lines[5].start, prev(t, lines[5].end, 0))
  assert_eq(lines[4].start, prev(t, lines[5].end, 1))
  assert_eq(lines[3].start, prev(t, lines[5].end, 2))
  assert_eq(lines[2].start, prev(t, lines[5].end, 3))
  assert_eq(lines[1].start, prev(t, lines[5].end, 4))
  assert_eq(lines[0].start, prev(t, lines[5].end, 5))
  assert_eq(lines[0].start, prev(t, lines[5].end, 6))
}
