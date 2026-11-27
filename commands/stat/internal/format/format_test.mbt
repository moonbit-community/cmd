///|
test "stat reports invalid format directives before looking up operands" {
  for text in ["%", "%i", "%03s"] {
    try @format.parse(text) catch {
      _ => ()
    } noraise {
      _ => fail("invalid stat format accepted")
    }
  }
  assert_eq(@format.parse("%n:%% %s").length(), 5)
}
