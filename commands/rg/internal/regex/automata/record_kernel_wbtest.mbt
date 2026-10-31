///|
test "wide endpoint count and stream kernels agree at every chunk phase" {
  for term in [b'\n', b'\x00'] {
    let separator = Bytes::from_array([term])
    let body = Bytes::make(137, b'x') +
      b"123Q" +
      separator +
      Bytes::make(97, b'a') +
      separator +
      b"ZZ" +
      separator +
      b"55Q"
    for pattern in ["[0-9]+Q|Z+", "a+Q", "Z+", "[0-9]{2}Q"] {
      let nfa = compile_nfa(@syntax.parse(pattern))
      let plan = LazyDFA::new(nfa).record_boolean().unwrap()
      for offset in 0..<16 {
        let hay = (Bytes::make(offset, b'!') + body).to_fixedarray()
        let expected = plan.count_lines(hay, offset, hay.length(), term)
        assert_eq(
          plan.count_long_lines(hay, offset, hay.length(), term),
          expected,
        )
        let reference = LazyDFA::new(nfa).find_fwd(
          hay,
          offset,
          hay.length(),
          offset,
          hay.length(),
          false,
          true,
        )
        assert_eq(plan.search_long_half(hay, offset, hay.length()), reference)
        for chunk in [1, 3, 4, 15, 16, 31, 32, 63, 64, 65, 137] {
          let feed = plan.stream_counter(term)
          let mut count = 0L
          let mut start = offset
          while start < hay.length() {
            let end = (start + chunk).min(hay.length())
            count += feed(hay, start, end, false)
            start = end
          }
          count += feed(hay, hay.length(), hay.length(), true)
          assert_eq(count, expected)
          assert_eq(feed(hay, hay.length(), hay.length(), true), 0L)
        }
      }
    }
  }
}
