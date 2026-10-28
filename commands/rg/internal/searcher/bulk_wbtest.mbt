///|
priv struct BulkSummary {
  enabled : Bool
  mut lines : Int32
  mut finish : SinkFinish?
}

///|
impl Sink for BulkSummary with fn bulk_scan(self) {
  self.enabled
}

///|
impl Sink for BulkSummary with fn matched(self, _, _) {
  self.lines += 1
  true
}

///|
impl Sink for BulkSummary with fn finish(self, _, finish) {
  self.finish = Some(finish)
}

///|
async test "bulk summaries preserve final counts offsets and binary conversion across original read boundaries" {
  let matcher = TestMatcher::new("hit")
  matcher.line_term = Some(@matcher.LineTerminator::byte(b'\n'))
  for binary in [BinaryNone, BinaryConvert(b'\x00'), BinaryQuit(b'\x00')] {
    for limit in [None, Some(1L), Some(5000L)] {
      let bytes = @utf8.encode(
        "hit a\n".repeat(13000) +
        "tail\u0000hit b\n" +
        "miss\n".repeat(35000) +
        "hit c",
      )
      let sinks : Array[BulkSummary] = []
      for enabled in [false, true] {
        let sink : BulkSummary = { enabled, lines: 0, finish: None, }
        let searcher = SearcherBuilder::new()
          .binary_detection(binary)
          .max_matches(limit)
          .build()
        searcher.search_reader(matcher, SliceReader::from_bytes(bytes), sink)
        if enabled && binary.quit_byte() is None && limit is None {
          assert_eq(searcher.line_buffer.capacity, 262144)
        } else {
          assert_eq(searcher.line_buffer.capacity, 65536)
        }
        sinks.push(sink)
      }
      assert_eq(sinks[0].lines, sinks[1].lines)
      assert_eq(
        sinks[0].finish.unwrap().byte_count,
        sinks[1].finish.unwrap().byte_count,
      )
      assert_eq(
        sinks[0].finish.unwrap().binary_byte_offset,
        sinks[1].finish.unwrap().binary_byte_offset,
      )
    }
  }
}

///|
test "bulk reader capacity preserves limits and opt-out modes" {
  let sink : BulkSummary = { enabled: true, lines: 0, finish: None, }
  for limit in [1, 4096, 65536, 131072, 262144, 1048576] {
    assert_eq(
      SearcherBuilder::new()
      .heap_limit(Some(limit))
      .build()
      .reader_capacity(sink),
      limit.min(262144),
    )
  }
  for
    searcher in [
      SearcherBuilder::new().before_context(1).build(),
      SearcherBuilder::new().after_context(1).build(),
      SearcherBuilder::new().multi_line(true).build(),
      SearcherBuilder::new().stop_on_nonmatch(true).build(),
      SearcherBuilder::new().invert_match(true).build(),
      SearcherBuilder::new().passthru(true).build(),
      SearcherBuilder::new().binary_detection(BinaryQuit(b'\x00')).build(),
    ] {
    assert_eq(searcher.reader_capacity(sink), 65536)
  }
}

///|
async test "reused searchers restore the original window for a non-bulk sink" {
  let matcher = TestMatcher::new("hit")
  matcher.line_term = Some(@matcher.LineTerminator::byte(b'\n'))
  let searcher = SearcherBuilder::new().build()
  for enabled in [true, false, true, false] {
    let sink : BulkSummary = { enabled, lines: 0, finish: None, }
    searcher.search_reader(matcher, SliceReader::from_bytes(b"hit\n"), sink)
    assert_eq(
      searcher.line_buffer.capacity,
      if enabled {
        262144
      } else {
        65536
      },
    )
    assert_eq(sink.lines, 1)
  }
}
