///|
test "streaming SHA1 matches standard vectors across padding boundaries" {
  for length in [0, 1, 55, 56, 63, 64, 65, 127, 128, 129, 65535, 65536, 65537] {
    let bytes = Bytes::makei(length, i => (i * 37 % 256).to_byte())
    let expected = @crypto.bytes_to_hex_string(@crypto.sha1(bytes))
    for chunk_size in [1, 7, 64, 65536] {
      let hasher = Sha1State::new()
      let mut offset = 0
      while offset < length {
        let end = if offset + chunk_size < length {
          offset + chunk_size
        } else {
          length
        }
        hasher.update(bytes[offset:end])
        offset = end
      }
      assert_eq(@hex.encode(hasher.finalize_bytes()), expected)
    }
  }
  let state = Sha1State::new()
  state.update(b"abc"[:])
  assert_eq(
    @hex.encode(state.finalize_bytes()),
    "a9993e364706816aba3e25717850c26c9cd0d89d",
  )
}
