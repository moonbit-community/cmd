///|
test "UTF-8 record search returns original byte positions across malformed input" {
  let input = @bytere.Utf8Record::new(b"\xff\xc5\xbf\xc3\x9fS")
  let pattern = @bytere.compile_utf8(
    ["s", "ßS"],
    fixed=true,
    extended=false,
    ignore_case=true,
  )
  assert_eq(pattern.find_span(input), Some((1, 3)))
  assert_eq(pattern.find_span(input, start=2), Some((3, 6)))
  assert_eq(pattern.find_span(input, start=6), None)
}

///|
test "C.UTF-8 capture choices retain independent pattern registers and GNU counted repetitions" {
  let input = @bytere.Utf8Record::new(b"\xc3\xa4\xc3\xa4\xc3\xa4")
  let pattern = @bytere.compile_utf8(
    ["(x)\\1", "(ä*){1,2}\\1"],
    fixed=false,
    extended=true,
    ignore_case=false,
  )
  assert_eq(pattern.find_span(input), Some((0, 4)))
  let empty = @bytere.compile_utf8(
    [],
    fixed=false,
    extended=true,
    ignore_case=true,
  )
  assert_eq(empty.find_span(input), None)
}
