///|
async test "gzip synchronous decoding preserves exact full literal buffers and trailer ownership" {
  // Literal A has the independent RFC1951 fixed code 01110001 (MSB first).
  // The bit writer takes the reversed eight-bit value.
  for count in [65535, 65536, 65537, 131072] {
    let raw = DeflateBits::new()
    raw.put(3U, 3)
    for _ in 0..<count {
      raw.put(142U, 8)
    }
    raw.put(0U, 7)
    raw.align()
    let encoded = raw.drain() + b"trailer"
    let reader = cursor(encoded)
    defer reader.close()
    let bits = Bits::new(reader)
    let output : Collected = { bytes: [], }
    let (checksum, size) = inflate(bits, output, false)
    let expected = Bytes::make(count, b'A')
    assert_eq(Bytes::from_array(output.bytes), expected)
    assert_eq(checksum, crc32(expected[:]))
    assert_eq(size, count.reinterpret_as_uint())
    for byte in b"trailer" {
      assert_eq(bits.next_byte(), Some(byte))
    }
  }
}

///|
async test "gzip synchronous match tail preserves overlap across a full output buffer" {
  // 65,535 literals followed by length258/distance1; both symbols use the
  // fixed RFC1951 alphabet. Padding bytes keep the token on the ready path.
  let raw = DeflateBits::new()
  raw.put(3U, 3)
  for _ in 0..<65535 {
    raw.put(142U, 8)
  }
  raw.put(163U, 8) // reversed fixed symbol285
  raw.put(0U, 5) // distance1
  raw.put(0U, 7) // end of block
  raw.align()
  let reader = cursor(raw.drain() + b"trailer")
  defer reader.close()
  let bits = Bits::new(reader)
  let output : Collected = { bytes: [], }
  let (checksum, size) = inflate(bits, output, false)
  let expected = Bytes::make(65535 + 258, b'A')
  assert_eq(Bytes::from_array(output.bytes), expected)
  assert_eq(checksum, crc32(expected[:]))
  assert_eq(size, 65793U)
  assert_eq(bits.next_byte(), Some(b't'))
}
