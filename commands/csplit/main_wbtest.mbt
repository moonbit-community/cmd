///|
test "csplit indexes byte lines without a phantom terminal line" {
  assert_eq(line_starts(b"a\nb\n"), [0, 2, 4])
  assert_eq(line_starts(b"a\nb"), [0, 2, 3])
  assert_eq(line_starts(b""), [0])
  assert_eq(line_text(b"a\x00\xff\n", 0, 4).length(), 3)
}

///|
test "csplit parses BRE and repeats before any output files are created" {
  let controls = parse_controls(["2", "{3}", "/^item/+1"])
  assert_eq(controls.length(), 2)
  assert_eq(controls[0].repeats, Some(3))
  assert_true(controls[1].pattern is Expression(_, 1, false))
  assert_true(Regex(basic_expression("a\\+b")).execute("aaab") is Some(_))
  assert_true(Regex(basic_expression("a+b")).execute("a+b") is Some(_))
  try basic_expression("\\(a\\)\\1") catch {
    _ => ()
  } noraise {
    _ => fail("must reject backreferences")
  }
}
