///|
test "benchmark candidate regimes are admitted by the command count adapter" {
  for
    (kind, expected) in [
      ("hit", 1024L),
      ("candidate-miss", 0L),
      ("mixed", 256L),
    ] {
    let matcher = SearchMatcher::new(
      ["[0-9]{4}.*Q|ZZ"],
      line_terminator=Some(@matcher.LineTerminator::byte(b'\n')),
    )
    let data = Bytes::makei(1048576, offset => {
      let record = offset / 1024
      let column = offset % 1024
      let hit = kind == "hit" || (kind == "mixed" && record % 4 == 0)
      let prefix = if hit { b"0001 alpha " } else { b"Q alpha 0001 " }
      if column == 1023 {
        b'\n'
      } else if column < prefix.length() {
        prefix[column]
      } else if hit && column == 1022 {
        b'Q'
      } else {
        (97 + (record * 17 + column * 13) % 26).to_byte()
      }
    }).to_fixedarray()
    assert_eq(
      @matcher.Matcher::count_matching_lines(
        matcher,
        data,
        0,
        data.length(),
        b'\n',
      ),
      Some(expected),
    )
    assert_true(@matcher.Matcher::stream_count_candidate(matcher, b'\n'))
    for chunk in [3, 1021, 65521] {
      let counter = @matcher.Matcher::stream_counter(matcher, b'\n').unwrap()
      let mut start = 0
      let mut count = 0L
      while start < data.length() {
        let end = (start + chunk).min(data.length())
        count += counter(data, start, end, false)
        start = end
      }
      count += counter(data, 0, 0, true)
      assert_eq(count, expected, msg=kind)
      assert_eq(counter(data, 0, 0, true), 0L)
    }
  }
}
