///|
test "regex stream counters preserve state without treating chunks as EOF" {
  for term in [b'\n', b'\x00'] {
    for
      pattern in [
        "a[bc]+d", "[0-9]{2}.*Q|ZZ", "[ab]+", "a.*b", "a.*?b", "甲[乙丙]+", "(?:xy){2,4}",
        "(?-u:[\\x80-\\xff]+)",
      ] {
      let matcher = SearchMatcher::new(
        [pattern],
        line_terminator=Some(@matcher.LineTerminator::byte(term)),
      )
      for
        input in [
          b"",
          b"\n",
          b"abcd\nabbd\nabc",
          b"abcd\x00abbd\x00abc",
          b"a\x00b\n",
          b"abcd",
          b"00 Q\nZZ\n00\nQ\n",
          b"xyxy\nxy\nxy",
          b"\xff\x80\n\x81",
          @utf8.encode("甲乙丙\n甲\n乙\n甲乙"),
        ] {
        let hay = input.to_fixedarray()
        let mut expected = 0L
        let mut start = 0
        for i in 0..<hay.length() {
          if hay[i] == term {
            if @matcher.is_match_at(matcher, hay, start, i, 0) {
              expected += 1L
            }
            start = i + 1
          }
        }
        if start < hay.length() &&
          @matcher.is_match_at(matcher, hay, start, hay.length(), 0) {
          expected += 1L
        }
        for chunk in [1, 2, 3, 7, 31, 262144] {
          let counter = @matcher.Matcher::stream_counter(matcher, term).unwrap()
          let mut at = 0
          let mut count = 0L
          while at < hay.length() {
            let end = (at + chunk).min(hay.length())
            count += counter(hay, at, end, false)
            at = end
          }
          count += counter(hay, 0, 0, true)
          assert_eq(counter(hay, 0, 0, true), 0L)
          assert_eq(count, expected, msg=pattern)
        }
      }
    }
  }
  for pattern in ["", "a*", "^x", "x$", "\\bx\\b", "(a|b)*a[ab]{6}"] {
    let matcher = SearchMatcher::new(
      [pattern],
      line_terminator=Some(@matcher.LineTerminator::byte(b'\n')),
    )
    assert_true(
      @matcher.Matcher::stream_counter(matcher, b'\n') is None,
      msg=pattern,
    )
  }
  for pattern in ["[0-9]{4}.*gamma", "[0-9]{4}.*QXYZ123|ZZZEND"] {
    let matcher = SearchMatcher::new(
      [pattern],
      line_terminator=Some(@matcher.LineTerminator::byte(b'\n')),
    )
    assert_true(!@matcher.Matcher::stream_count_candidate(matcher, b'\n'))
    assert_true(@matcher.Matcher::stream_counter(matcher, b'\n') is None)
  }
}

///|
async test "regex count streaming handles bulk boundaries and decoded EOF" {
  for term in [b'\n', b'\x00'] {
    let inputs = [
      Bytes::make(262143, b'x') +
      b"abcbd" +
      Bytes::from_array([term]) +
      Bytes::make(1048576, b'x') +
      b"abcbd",
      b"\xff\xfea\x00b\x00c\x00b\x00d\x00" +
      Bytes::from_array([term, b'\x00']) +
      b"a\x00b\x00c\x00d\x00",
    ]
    let matcher = SearchMatcher::new(
      ["a[bc]+d"],
      line_terminator=Some(@matcher.LineTerminator::byte(term)),
    )
    for input in inputs {
      for chunk in [3, 65536, 262144] {
        let results : Array[(Int64, Int64)] = []
        for aggregate in [false, true] {
          let sink : CountSummary = {
            aggregate,
            matches: 0,
            batches: 0,
            individual: 0,
            finish: None,
          }
          let reader : FragmentedCountInput = {
            inner: @searcher.SliceReader::from_bytes(input),
            chunk,
          }
          @searcher.SearcherBuilder::new()
          .line_terminator(@matcher.LineTerminator::byte(term))
          .build()
          .search_reader(matcher, reader, sink)
          results.push((sink.matches, sink.finish.unwrap().byte_count))
        }
        assert_eq(results[0].0, 2L)
        assert_eq(results[0], results[1])
      }
    }
  }
}

///|
priv struct BrokenRegexCountReader {
  bytes : Bytes
  mut position : Int32
}

///|
impl @searcher.Reader for BrokenRegexCountReader with fn read(
  self,
  buf,
  start,
  len,
) {
  let bytes = self.bytes
  if self.position == bytes.length() {
    fail("regex stream read failed")
  }
  let length = len.min(bytes.length() - self.position)
  for i in 0..<length {
    buf[start + i] = bytes[self.position + i]
  }
  self.position += length
  length
}

///|
async test "regex count streaming does not finalize a partial record on read failure" {
  let matcher = SearchMatcher::new(
    ["a[bc]+d"],
    line_terminator=Some(@matcher.LineTerminator::byte(b'\n')),
  )
  for bytes in [b"abcd\nabcd", Bytes::make(65536, b'x') + b"abcd\nabcd"] {
    for aggregate in [false, true] {
      let sink : CountSummary = {
        aggregate,
        matches: 0,
        batches: 0,
        individual: 0,
        finish: None,
      }
      let failed = try {
        @searcher.SearcherBuilder::new()
        .bom_sniffing(false)
        .build()
        .search_reader(
          matcher,
          BrokenRegexCountReader::{ bytes, position: 0, },
          sink,
        )
        false
      } catch {
        error => error.to_string().contains("regex stream read failed")
      }
      assert_true(failed)
      assert_eq(sink.matches, 1L)
      assert_true(sink.finish is None)
    }
  }
}

///|
priv struct ObservedRegexInput {
  inner : @searcher.SliceReader
  mut reads : Int32
}

///|
impl @searcher.Reader for ObservedRegexInput with fn read(self, buf, start, len) {
  self.reads += 1
  @searcher.Reader::read(self.inner, buf, start, len)
}

///|
priv struct StartedRegexCount {
  allow : Bool
  mut begins : Int32
  mut finishes : Int32
  mut matches : Int64
}

///|
impl @searcher.Sink for StartedRegexCount with fn begin(self, _) {
  self.begins += 1
  self.allow
}

///|
impl @searcher.Sink for StartedRegexCount with fn finish(self, _, _) {
  self.finishes += 1
}

///|
impl @searcher.Sink for StartedRegexCount with fn synchronous_count(self) {
  Some(count => self.matches += count)
}

///|
impl @searcher.Sink for StartedRegexCount with fn matched(self, _, _) {
  self.matches += 1L
  true
}

///|
async test "adaptive count probes preserve begin denial and decoded replay" {
  let matcher = SearchMatcher::new(
    ["a[bc]+d"],
    line_terminator=Some(@matcher.LineTerminator::byte(b'\n')),
  )
  for
    data in [
      b"abcd\n",
      Bytes::make(65536, b'x') + b"abcd",
      b"",
      b"header\n" + Bytes::make(65536, b'x') + b"abcd",
      b"\xff\xfe" + b"x\x00".repeat(65536) + b"a\x00b\x00c\x00d\x00",
    ] {
    for allow in [false, true] {
      let sink : StartedRegexCount = {
        allow,
        begins: 0,
        finishes: 0,
        matches: 0L,
      }
      let reader : ObservedRegexInput = {
        inner: @searcher.SliceReader::from_bytes(data),
        reads: 0,
      }
      @searcher.SearcherBuilder::new()
      .build()
      .search_reader(matcher, reader, sink)
      assert_eq(sink.begins, 1)
      assert_eq(sink.finishes, 1)
      if !allow {
        assert_eq(reader.reads, 0)
      }
      assert_eq(sink.matches, if allow && !data.is_empty() { 1L } else { 0L })
    }
  }
}

///|
async test "probe matches only decline streaming and never count a truncated record" {
  for
    (pattern, input, expected) in [
      ("", b"", 0L),
      ("a*", b"", 0L),
      ("^$", b"", 0L),
      ("^$", b"\n", 1L),
      ("a*", Bytes::make(65536, b'x'), 1L),
      ("x$", Bytes::make(65535, b' ') + b"xb", 0L),
      ("\\bx\\b", Bytes::make(65535, b' ') + b"xb", 0L),
      ("a[bc]+d", b"abcd" + Bytes::make(65536, b'x'), 1L),
    ] {
    let matcher = SearchMatcher::new(
      [pattern],
      line_terminator=Some(@matcher.LineTerminator::byte(b'\n')),
    )
    for aggregate in [false, true] {
      let sink : CountSummary = {
        aggregate,
        matches: 0,
        batches: 0,
        individual: 0,
        finish: None,
      }
      @searcher.SearcherBuilder::new()
      .build()
      .search_reader(matcher, @searcher.SliceReader::from_bytes(input), sink)
      assert_eq(sink.matches, expected, msg=pattern)
      assert_eq(sink.finish.unwrap().byte_count, input.length().to_int64())
    }
  }
}
