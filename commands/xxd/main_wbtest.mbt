///|
test "xxd include output is stable and addressed dumps preserve holes" {
  assert_true(
    include_output("fixture.bin", b"abc", Some("fixture")).contains(
      "unsigned char fixture[]",
    ),
  )
  assert_true(include_output("-", b"abc", None) == "61, 62, 63\n")
  guard reverse_dump_line(b"00000002: 4142  ;AB") is Some((offset, bytes)) else {
    fail("addressed line did not parse")
  }
  assert_eq(offset, 2)
  assert_eq(bytes, b"AB")
}

///|
test "xxd malformed addressed lines are rejected" {
  assert_true(reverse_dump_line(b"00000000: zz") is None)
  assert_true(reverse_dump_line(b"not a dump") is None)
}
