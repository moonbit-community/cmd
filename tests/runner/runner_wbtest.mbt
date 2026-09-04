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
test "fixture content expands HTTP placeholders after decoding" {
  let base = "http://127.0.0.1:12345"
  assert_eq(
    expand_fixture_content(b"${HTTP_BASE}/fixed\n", http_base=base),
    b"http://127.0.0.1:12345/fixed\n",
  )
  assert_eq(
    expand_fixture_content(b"plain text", http_base=base),
    b"plain text",
  )
  assert_eq(
    expand_fixture_content(b"\xff${HTTP_BASE}", http_base=base),
    b"\xff${HTTP_BASE}",
  )
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
test "working-directory normalization maps local and container roots" {
  let rules : Array[Normalization] = [
    {
      field: "stdout",
      rule: "working-directory",
      comment: "oracle containers mount each case at /work",
    },
  ]
  assert_eq(
    normalize_text(b"/tmp/case/sub\n", "stdout", rules, "/tmp/case"),
    b"<WORK>/sub\n",
  )
  assert_eq(
    normalize_text(b"/work/sub\n", "stdout", rules, "/oracle/root"),
    b"<WORK>/sub\n",
  )
}

///|
test "byte differences identify offset and length" {
  assert_true(first_byte_difference(b"abc", b"axc").contains("at 1"))
  assert_true(first_byte_difference(b"abc", b"abcx").contains("length differs"))
}
