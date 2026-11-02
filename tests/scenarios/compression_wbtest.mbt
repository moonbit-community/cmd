///|
async test "independent gzip observer rejects truncated members and corrupted checksums" {
  let fixed = b"\x1f\x8b\x08\x00\x00\x00\x00\x00\x00\x03\x4b\x4c\x4a\x06\x00\xc2\x41\x24\x35\x03\x00\x00\x00"
  assert_eq(independently_decode_gzip(fixed), b"abc")
  let truncated = independently_decode_gzip(
    fixed[:fixed.length() - 1].to_owned(),
  ) catch {
    _ => b"rejected"
  }
  assert_eq(truncated, b"rejected")
  let bad_crc = independently_decode_gzip(
    fixed[:15].to_owned() + b"\x00\x00\x00\x00\x03\x00\x00\x00",
  ) catch {
    _ => b"rejected"
  }
  assert_eq(bad_crc, b"rejected")
}
