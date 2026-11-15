///|
fn decoded(
  text : Bytes,
  style : @codec.Style,
  cols : Int32,
  base~ : Int64 = 0L,
) -> Array[(Int64, Byte)] raise @codec.DecodeError {
  let decoder = @codec.Decoder::new(style, cols, base)
  let result = []
  for byte in text {
    if decoder.feed(byte) is Some((position, Some(byte))) {
      result.push((position, byte))
    }
  }
  result
}

///|
test "xxd malformed addressed lines follow loose upstream offsets" {
  assert_eq(decoded(b"00000000: zz\n", @codec.Normal, 16), [])
  assert_eq(decoded(b"not a dump\n", @codec.Normal, 16), [])
  let decoder = @codec.Decoder::new(@codec.Normal, 16, 0L)
  let mut first = None
  for byte in b"not a dump\n" {
    if decoder.feed(byte) is Some((offset, _)) && first is None {
      first = Some(offset)
    }
  }
  assert_eq(first, Some(10L))
  assert_eq(decoded(b"xyz\n", @codec.Normal, 16), [])
}

///|
test "xxd reverse bits plain garbage and address adjustment" {
  assert_eq(decoded(b"00000000: 01000001 01000010  AB\n", @codec.Bits, 6), [
    (0L, b'A'),
    (1L, b'B'),
  ])
  assert_eq(decoded(b"41 42\n43", @codec.Plain, 30), [
    (0L, b'A'),
    (1L, b'B'),
    (2L, b'C'),
  ])
  assert_eq(decoded(b"41z 4", @codec.Plain, 30), [(0L, b'A')])
  assert_eq(decoded(b"00000002: 41\n", @codec.Normal, 16, base=4L), [(6L, b'A')])
  assert_eq(decoded(b"00000002: 41\n", @codec.Normal, 16, base=-2L), [
    (0L, b'A'),
  ])
}
