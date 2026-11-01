///|
priv struct RetentionMatcher {
  inner : TestMatcher
  enable_plan : Bool
  mut preparations : Int32
}

///|
impl @matcher.Matcher for RetentionMatcher with fn find_at(
  self,
  hay,
  hs,
  he,
  at,
) {
  @matcher.Matcher::find_at(self.inner, hay, hs, he, at)
}

///|
impl @matcher.Matcher for RetentionMatcher with fn new_captures(_) {
  @matcher.Captures::new(0)
}

///|
impl @matcher.Matcher for RetentionMatcher with fn line_terminator(_) {
  Some(Byte(b'\n'))
}

///|
impl @matcher.Matcher for RetentionMatcher with fn stream_count_candidate(_, _) {
  true
}

///|
impl @matcher.Matcher for RetentionMatcher with fn stream_counter(self, term) {
  self.preparations += 1
  if self.enable_plan {
    self.inner.regex.boolean_stream_counter(term)
  } else {
    None
  }
}

///|
priv struct RetentionCount {
  mut matches : Int64
  mut finished : SinkFinish?
}

///|
impl Sink for RetentionCount with fn synchronous_count(self) {
  Some(count => self.matches += count)
}

///|
impl Sink for RetentionCount with fn matched(self, _, _) {
  self.matches += 1L
  true
}

///|
impl Sink for RetentionCount with fn finish(self, _, finish) {
  self.finished = Some(finish)
}

///|
priv struct RetentionReader {
  inner : SliceReader
  searcher : Searcher
  fail_at_end : Bool
  mut maximum_capacity : Int32
}

///|
impl Reader for RetentionReader with fn read(self, buf, start, len) {
  self.maximum_capacity = self.maximum_capacity.max(
    self.searcher.line_buffer.buf.length(),
  )
  let count = Reader::read(self.inner, buf, start, len.min(8191))
  if count == 0 && self.fail_at_end {
    fail("retention reader failed")
  }
  count
}

///|
async test "regex count admission is independent of match and record positions" {
  for prefix in [b"", b"abcd\nmiss\n"] {
    for
      record in [
        b"abcd" + Bytes::make(2097152, b'x'),
        Bytes::make(2097152, b'x') + b"abcd",
        Bytes::make(2097152, b'x'),
      ] {
      for plan in [false, true] {
        let searcher = SearcherBuilder::new().bom_sniffing(false).build()
        let matcher : RetentionMatcher = {
          inner: TestMatcher::new("a[bc]+d"),
          enable_plan: plan,
          preparations: 0,
        }
        let bytes = prefix + record + b"\nabcd"
        let reader : RetentionReader = {
          inner: SliceReader::from_bytes(bytes),
          searcher,
          fail_at_end: false,
          maximum_capacity: 0,
        }
        let sink : RetentionCount = { matches: 0L, finished: None, }
        searcher.search_reader(matcher, reader, sink)
        assert_eq(matcher.preparations, 1)
        assert_eq(
          sink.matches,
          (if prefix.is_empty() { 0L } else { 1L }) +
          (if record.length() == 2097152 { 0L } else { 1L }) +
          1L,
        )
        assert_eq(sink.finished.unwrap().byte_count, bytes.length().to_int64())
        if plan {
          assert_eq(reader.maximum_capacity, DEFAULT_BUFFER_CAPACITY)
        } else {
          assert_true(reader.maximum_capacity > maximum_retained_buffer_bytes)
        }
        assert_eq(searcher.line_buffer.buf.length(), DEFAULT_BUFFER_CAPACITY)
      }
    }
  }
}

///|
async test "oversized buffers are released after errors and successful multiline searches" {
  let long = Bytes::make(2097152, b'x')
  for multiline in [false, true] {
    for fail_at_end in [false, true] {
      let searcher = SearcherBuilder::new()
        .multi_line(multiline)
        .bom_sniffing(false)
        .build()
      let matcher = TestMatcher::new("never-present")
      let reader : RetentionReader = {
        inner: SliceReader::from_bytes(long),
        searcher,
        fail_at_end,
        maximum_capacity: 0,
      }
      let sink : RetentionCount = { matches: 0L, finished: None, }
      let failed = try {
        searcher.search_reader(matcher, reader, sink)
        false
      } catch {
        error => error.to_string().contains("retention reader failed")
      }
      assert_eq(failed, fail_at_end)
      assert_true(
        searcher.line_buffer.buf.length() <= maximum_retained_buffer_bytes,
      )
      assert_true(
        searcher.multi_line_buffer.length() <= maximum_retained_buffer_bytes,
      )
      assert_eq(sink.matches, 0L)
      let next : RetentionCount = { matches: 0L, finished: None, }
      searcher.search_reader(
        matcher,
        SliceReader::from_bytes(b"never-present\n"),
        next,
      )
      assert_eq(next.matches, 1L)
      assert_eq(next.finished.unwrap().byte_count, 14L)
    }
  }
}
