///|
test "od decodes explicit IEEE x87 and quad fields without narrowing" {
  for
    (data, size, kind) in [
      (b"\x00\x3c", 2, Half),
      (b"\x80\x3f", 2, BFloat),
      (b"\x00\x00\x80\x3f", 4, Single),
      (b"\x00\x00\x00\x00\x00\x00\xf0\x3f", 8, Double),
      (Bytes::make(7, 0) + b"\x80\xff\x3f" + Bytes::make(6, 0), 16, Extended80),
    ] {
    let value = float_at(data, 0, size, false, kind)
    assert_eq(@numfmt.format_roundtrip(value, kind.profile()), "1")
  }
  let quad = Bytes::make(14, 0) + b"\xff\x3f"
  assert_eq(
    @numfmt.format_roundtrip(
      @numfmt.decode(quad[:], @numfmt.Binary128),
      @numfmt.Binary128,
    ),
    "1",
  )
}

///|
test "od short float fields pad physical bytes before endian decoding" {
  assert_eq(
    @numfmt.format_roundtrip(
      float_at(b"\x80", 0, 4, false, Single),
      @numfmt.Binary32,
    ),
    "1.8e-43",
  )
  assert_eq(
    @numfmt.format_roundtrip(
      float_at(b"\x80", 0, 4, true, Single),
      @numfmt.Binary32,
    ),
    "-0",
  )
  assert_eq(
    @numfmt.format_roundtrip(
      float_at(b"\x80", 0, 8, false, Double),
      @numfmt.Binary64,
    ),
    "6.3e-322",
  )
  assert_eq(
    @numfmt.format_roundtrip(
      float_at(b"\x66\x2e", 0, 2, false, Half),
      @numfmt.Binary32,
    ),
    "0.099975586",
  )
}
