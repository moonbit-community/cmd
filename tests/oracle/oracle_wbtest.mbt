///|
test "hex fixtures preserve arbitrary bytes" {
  assert_eq(decode_hex("00ff4162", "fixture"), b"\x00\xffAb")
  try decode_hex("0", "fixture") catch {
    _ => ()
  } noraise {
    _ => fail("odd hexadecimal input must fail")
  }
  try decode_hex("xz", "fixture") catch {
    _ => ()
  } noraise {
    _ => fail("non-hexadecimal input must fail")
  }
}

///|
test "fixture paths cannot escape an isolated work directory" {
  assert_true(safe_relative_path("input/data.bin"))
  assert_false(safe_relative_path(""))
  assert_false(safe_relative_path("/absolute"))
  assert_false(safe_relative_path("../escape"))
  assert_false(safe_relative_path("nested/../escape"))
  assert_false(safe_relative_path("nested\\..\\escape"))
}

///|
test "undeclared normalization preserves binary bytes" {
  let binary = b"\x00\xff\r\n"
  assert_true(
    @testkit.bytes_equal(
      normalize_text(binary, "stdout", [], "/tmp/case"),
      binary,
    ),
  )
}

///|
test "byte differences identify offset and length" {
  assert_true(first_byte_difference(b"abc", b"axc").contains("at 1"))
  assert_true(first_byte_difference(b"abc", b"abcx").contains("length differs"))
}
