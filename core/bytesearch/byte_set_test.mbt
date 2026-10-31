///|
test "byte-set candidates match scalar membership across all bytes and boundaries" {
  for mode in 0..<6 {
    let members = FixedArray::makei(256, byte => {
      match mode {
        0 => false
        1 => true
        2 => byte % 17 == 0
        3 => (byte >= 48 && byte <= 57) || byte == 90
        4 => byte >= 128
        _ => byte == 255
      }
    })
    let finder = @bytesearch.ByteSetFinder::new(members)
    for byte in 0..<256 {
      assert_eq(finder.contains(byte.to_byte()), members[byte])
    }
    let hay = FixedArray::makei(1025, i => ((i * 73 + 19) % 256).to_byte())
    for start in 0..<256 {
      for length in [0, 1, 15, 16, 17, 31, 32, 33, 257, 513] {
        let end = start + length
        let mut expected = -1
        for i in start..<end {
          if members[hay[i].to_int()] {
            expected = i
            break
          }
        }
        assert_eq(finder.find(hay, start, end), expected)
      }
    }
    // Later caller mutations must not invalidate the compiled SIMD tables.
    let previous = finder.contains(b'\x00')
    members[0] = !previous
    assert_eq(finder.contains(b'\x00'), previous)
    assert_eq(finder.find([b'\x00'], 0, 1), if previous { 0 } else { -1 })
  }
}
