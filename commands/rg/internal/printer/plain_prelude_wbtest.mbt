///|
test "plain preludes preserve field order null path terminators and unsigned offsets" {
  let out = @termcolor.ByteVec::new()
  format_plain_prelude(
    out,
    Some(b"a/b"),
    None,
    Some(12),
    Some(3),
    Some(99),
    b":",
  )
  assert_eq(out.to_bytes(), b"a/b:12:3:99:")
  format_plain_prelude(
    out,
    Some(b"a/b"),
    Some(b'\x00'),
    Some(12),
    None,
    Some(-1),
    b"--",
  )
  assert_eq(out.to_bytes(), b"a/b\x0012--18446744073709551615--")
  format_plain_prelude(out, Some(b""), None, None, None, None, b"\r\n")
  assert_eq(out.to_bytes(), b"\r\n")
  format_plain_prelude(out, None, Some(b'\x00'), None, Some(0), None, b"-")
  assert_eq(out.to_bytes(), b"0-")
  format_plain_prelude(
    out,
    None,
    None,
    None,
    None,
    Some(9223372036854775807),
    b"",
  )
  assert_eq(out.to_bytes(), b"9223372036854775807")
  format_plain_prelude(out, None, None, None, None, None, b":")
  assert_eq(out.to_bytes(), b"")
}
