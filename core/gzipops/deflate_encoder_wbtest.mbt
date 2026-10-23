///|
fn deflate_noise(count : Int32) -> Bytes {
  let mut state = 0x6d2b79f5U
  Bytes::makei(count, _ => {
    state = state ^ (state << 13)
    state = state ^ (state >> 17)
    state = state ^ (state << 5)
    (state >> 24).to_byte()
  })
}

///|
async fn assert_raw_deflate(encoded : Bytes, payload : Bytes) -> Unit {
  let output : Collected = { bytes: [], }
  let input = cursor(encoded)
  defer input.close()
  let bits = Bits::new(input)
  let (checksum, size) = inflate(bits, output, false)
  assert_true(bits.next_byte() is None)
  assert_eq(Bytes::from_array(output.bytes), payload)
  assert_eq(checksum, crc32(payload[:]))
  assert_eq(size, payload.length().reinterpret_as_uint())
}

///|
async test "deflate chooses fixed dynamic and stored blocks by complete cost" {
  let short = DeflateEncoder::new(6).push(b"abc", finish=true)
  assert_eq(short, b"\x4b\x4c\x4a\x06\x00")
  assert_raw_deflate(short, b"abc")
  let repeated = Bytes::make(8192, b'a')
  let dynamic = DeflateEncoder::new(6).push(repeated, finish=true)
  assert_eq((dynamic[0].to_int() >> 1) & 3, 2)
  assert_raw_deflate(dynamic, repeated)
  let noise = deflate_noise(65536)
  let stored = DeflateEncoder::new(6).push(noise, finish=true)
  assert_eq((stored[0].to_int() >> 1) & 3, 0)
  assert_eq(stored.length(), noise.length() + 10)
  assert_raw_deflate(stored, noise)
}

///|
async test "deflate streams reused trees changed alphabets and all search levels" {
  let record = b"0123456789abcdef0123456789abcde\n"
  let chunk = Bytes::makei(65536, index => record[index % 32])
  for level in 1..<=9 {
    let encoder = DeflateEncoder::new(level)
    let compressed = encoder.push(chunk, finish=false) +
      encoder.push(chunk, finish=false) +
      encoder.push(chunk, finish=true)
    assert_true(compressed.length() < 1000)
    assert_raw_deflate(compressed, chunk + chunk + chunk)
  }
  let encoder = DeflateEncoder::new(6)
  let a = Bytes::make(65536, b'a')
  let b = Bytes::make(65536, b'b')
  let compressed = encoder.push(a, finish=false) +
    encoder.push(b, finish=false) +
    encoder.push(b"", finish=true)
  assert_raw_deflate(compressed, a + b)
  assert_eq(DeflateEncoder::new(6).push(b"", finish=true), b"\x03\x00")
}

///|
async test "gzip encoding levels preserve envelope checksum and empty payloads" {
  for level in 1..<=9 {
    let encoded : Collected = { bytes: [], }
    let input = cursor(b"")
    defer input.close()
    encode(input, encoded, level~)
    let data = Bytes::from_array(encoded.bytes)
    assert_eq(data[:8].to_owned(), b"\x1f\x8b\x08\x00\x00\x00\x00\x00")
    assert_eq(
      data[8],
      if level == 1 {
        b'\x04'
      } else if level == 9 {
        b'\x02'
      } else {
        b'\x00'
      },
    )
    assert_eq(data[9], b'\xff')
    assert_eq(data[10:].to_owned(), b"\x03\x00\x00\x00\x00\x00\x00\x00\x00\x00")
    let output : Collected = { bytes: [], }
    assert_true(!decode(data, output, false))
    assert_true(output.bytes.is_empty())
  }
}
