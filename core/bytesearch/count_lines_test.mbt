///|
test "block literal counts preserve short records candidate collisions and window bounds" {
  for needle in [b"", b"a", b"ab", b"alpha", b"aaaaab", b"ababababac"] {
    let finder = @bytesearch.Finder::new(
      needle.to_fixedarray(),
      0,
      (needle.length() - 1).max(0),
    )
    for length in [0, 1, 15, 16, 31, 32, 33, 64, 65, 257, 4097] {
      let data = Bytes::makei(length, i => {
          if i % 11 == 0 {
            b'\n'
          } else {
            b'a'
          }
        }) +
        b"alpha\nab\naaaaab\nababababac"
      for offset in [0, 1, 7] {
        let hay = (Bytes::make(offset, b'z') + data + b"suffix").to_fixedarray()
        let mut expected = 0L
        let mut start = 0
        for i in 0..<data.length() {
          if data[i] == b'\n' {
            if data[start:i].find(needle) is Some(_) {
              expected += 1L
            }
            start = i + 1
          }
        }
        if start < data.length() && data[start:].find(needle) is Some(_) {
          expected += 1L
        }
        assert_eq(
          finder.count_lines(hay, offset, offset + data.length(), b'\n'),
          expected,
        )
      }
    }
  }
}
