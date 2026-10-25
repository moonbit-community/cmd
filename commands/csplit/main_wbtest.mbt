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
  let plus = parse_pattern("/a\\+b/")
  guard plus is Expression(pattern, 0, false) else {
    fail("expected expression")
  }
  assert_true(pattern.find_span("aaab") is Some(_))
  let literal = parse_pattern("/a+b/")
  guard literal is Expression(pattern, 0, false) else {
    fail("expected expression")
  }
  assert_true(pattern.find_span("a+b") is Some(_))
  let repeated = parse_pattern("/\\(a\\)\\1/")
  guard repeated is Expression(pattern, 0, false) else {
    fail("expected expression")
  }
  assert_eq(pattern.find_span("zaab"), Some((1, 3)))
}

///|
test "csplit suffix integers distinguish precision alternate prefix and width" {
  assert_eq(suffix_format("pre%%-%03d.out").render(0), "pre%-000.out")
  assert_eq(suffix_format("%#04x").render(1), "0x01")
  assert_eq(suffix_format("%.0d").render(0), "")
  assert_eq(suffix_format("%#.0o").render(0), "0")
  assert_eq(suffix_format("%-3d").render(1), "1  ")
}
