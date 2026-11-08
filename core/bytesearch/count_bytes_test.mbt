///|
test "word-at-a-time byte counts match scalar counts in offset views" {
  let source = Bytes::makei(1050, index => (index % 256).to_byte())
  for needle in 0..<256 {
    for offset in 0..<16 {
      for length in [0, 1, 7, 8, 9, 15, 16, 17, 1024] {
        let view = source[offset:offset + length]
        let mut expected = 0
        for byte in view {
          if byte == needle.to_byte() {
            expected += 1
          }
        }
        assert_eq(@bytesearch.count_byte(view, needle.to_byte()), expected)
      }
    }
  }
  for needle in 0..<256 {
    let data = Bytes::makei(64, index => (needle ^ (index % 2)).to_byte())
    assert_eq(@bytesearch.count_byte(data, needle.to_byte()), 32)
    assert_eq(
      @bytesearch.count_byte(
        Bytes::make(32, needle.to_byte()),
        needle.to_byte(),
      ),
      32,
    )
  }
}
