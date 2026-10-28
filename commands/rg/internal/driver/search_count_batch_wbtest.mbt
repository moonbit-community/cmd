///|
priv struct CountSummary {
  aggregate : Bool
  mut matches : Int64
  mut batches : Int32
  mut individual : Int32
  mut finish : @searcher.SinkFinish?
}

///|
impl @searcher.Sink for CountSummary with fn synchronous_count(self) {
  if self.aggregate {
    Some(count => {
      self.matches += count
      self.batches += 1
    })
  } else {
    None
  }
}

///|
impl @searcher.Sink for CountSummary with fn matched(self, _, _) {
  self.matches += 1
  self.individual += 1
  true
}

///|
impl @searcher.Sink for CountSummary with fn finish(self, _, finish) {
  self.finish = Some(finish)
}

///|
async test "batched counts agree with individual events on empty anchored binary and crossing input" {
  let inputs = [
    b"",
    b"\n",
    b"hit\nmiss\nhit hit\nhit",
    b"hit\r\nmiss\r\nhit\r\n",
    b"\xffhit\x00miss\nhit\n",
    Bytes::make(65535, b'a') + b"hit\n",
    @utf8.encode("miss\nhit hit\n".repeat(10000)) + b"hit",
  ]
  for
    pattern in [
      "hit", "h.t", "", "^", "$", "^hit$", "h.*t", "hit|miss", "\\bhit\\b",
    ] {
    let matcher = SearchMatcher::new(
      [pattern],
      line_terminator=Some(b'\n').map(@matcher.LineTerminator::byte),
    )
    for
      binary in [
        @searcher.BinaryNone,
        @searcher.BinaryConvert(b'\x00'),
        @searcher.BinaryQuit(b'\x00'),
      ] {
      for input in inputs {
        let sinks : Array[CountSummary] = []
        for aggregate in [false, true] {
          let sink : CountSummary = {
            aggregate,
            matches: 0,
            batches: 0,
            individual: 0,
            finish: None,
          }
          @searcher.SearcherBuilder::new()
          .binary_detection(binary)
          .line_number(true)
          .build()
          .search_reader(
            matcher,
            @searcher.SliceReader::from_bytes(input),
            sink,
          )
          if aggregate && binary.quit_byte() is None && pattern == "hit" {
            assert_eq(sink.individual, 0)
          }
          sinks.push(sink)
        }
        assert_eq(sinks[0].matches, sinks[1].matches, msg=pattern)
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
}

///|
async test "count aggregation excludes early stops context inverted passthrough and multiline" {
  let matcher = SearchMatcher::new(
    ["hit"],
    line_terminator=Some(b'\n').map(@matcher.LineTerminator::byte),
  )
  for
    builder in [
      @searcher.SearcherBuilder::new().max_matches(Some(1)),
      @searcher.SearcherBuilder::new().before_context(1),
      @searcher.SearcherBuilder::new().after_context(1),
      @searcher.SearcherBuilder::new().invert_match(true),
      @searcher.SearcherBuilder::new().stop_on_nonmatch(true),
      @searcher.SearcherBuilder::new().passthru(true),
      @searcher.SearcherBuilder::new().multi_line(true),
    ] {
    let sink : CountSummary = {
      aggregate: true,
      matches: 0,
      batches: 0,
      individual: 0,
      finish: None,
    }
    builder
    .build()
    .search_reader(
      matcher,
      @searcher.SliceReader::from_bytes(b"hit\nmiss\nhit\n"),
      sink,
    )
    assert_eq(sink.batches, 0)
  }
}
