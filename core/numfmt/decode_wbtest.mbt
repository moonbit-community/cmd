///|
test "binary decode preserves negative NaN for C formatting" {
  for
    (data, profile) in [
      (b"\x00\x00\xc0\xff", Binary32),
      (b"\x00\x00\x00\x00\x00\x00\xf8\xff", Binary64),
      (
        b"\x00\x00\x00\x00\x00\x00\x00\xc0\xff\xff\x00\x00\x00\x00\x00\x00",
        Extended80,
      ),
    ] {
    let value = decode(data[:], profile)
    assert_true(value is NaN(true))
    assert_eq(format_roundtrip(value, profile), "-nan")
  }
}
