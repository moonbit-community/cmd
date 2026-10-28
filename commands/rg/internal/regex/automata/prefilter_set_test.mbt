///|
test "large candidate sets preserve earliest full-literal preference and high bytes" {
  for
    literals in [
      Array::makei(11, i => Bytes::make(1, (48 + i).to_byte())),
      Array::makei(20, i => Bytes::from_array([(128 + i).to_byte(), b'x'])),
      Array::makei(20, i => {
        Bytes::from_array([(48 + i).to_byte(), (65 + i).to_byte()])
      }) +
      [b"0AB"],
    ] {
    let pre = @automata.Prefilter::new(literals).unwrap()
    for
      data in [
        Bytes::make(513, b'a'),
        Bytes::makei(1025, i => (i % 256).to_byte()),
        b"0AB 1B 2C 9J\x80x\x90x",
        b"",
      ] {
      let hay = (b"head" + data + b"tail").to_fixedarray()
      for offset in 0..<(data.length().min(18) + 1) {
        let start = 4 + offset
        let end = 4 + data.length()
        let mut expected = @automata.NO_SPAN
        for i in start..<end {
          for literal in literals {
            if literal.length() <= end - i {
              let mut equal = true
              for j in 0..<literal.length() {
                if hay[i + j] != literal[j] {
                  equal = false
                  break
                }
              }
              if equal {
                expected = (i.to_int64() << 32) |
                  (i + literal.length()).to_int64()
                break
              }
            }
          }
          if expected != @automata.NO_SPAN {
            break
          }
        }
        assert_eq(pre.find_span(hay, start, end), expected)
      }
    }
  }
}
