///|
priv struct BufferedTrace {
  enabled : Bool
  mut attempts : Int32
  mut accepted : Int32
  trace : SynchronousTrace
}

///|
impl @searcher.Sink for BufferedTrace with fn buffered_matched(self) {
  if self.enabled {
    Some((_, mat) => {
      self.attempts += 1
      // Decline alternating matches and every potentially stopping event.
      if self.attempts % 2 == 0 || self.trace.calls + 1 >= self.trace.stop {
        false
      } else {
        ignore(self.trace.record(mat))
        self.accepted += 1
        true
      }
    })
  } else {
    None
  }
}

///|
impl @searcher.Sink for BufferedTrace with fn matched(self, _, mat) {
  self.trace.record(mat)
}

///|
impl @searcher.Sink for BufferedTrace with fn context(self, searcher, ctx) {
  @searcher.Sink::context(self.trace, searcher, ctx)
}

///|
impl @searcher.Sink for BufferedTrace with fn context_break(self, searcher) {
  @searcher.Sink::context_break(self.trace, searcher)
}

///|
impl @searcher.Sink for BufferedTrace with fn binary_data(
  self,
  searcher,
  offset,
) {
  @searcher.Sink::binary_data(self.trace, searcher, offset)
}

///|
impl @searcher.Sink for BufferedTrace with fn finish(self, searcher, finish) {
  @searcher.Sink::finish(self.trace, searcher, finish)
}

///|
async test "buffered sink handoff never duplicates events and respects stopping modes" {
  let matcher = SearchMatcher::new(
    ["hit"],
    line_terminator=Some(@matcher.LineTerminator::byte(b'\n')),
  )
  let input = b"skip\nhit a\nhit b\nmiss\nhit c\nhit d\nhit e"
  for context in [0, 1] {
    for invert in [false, true] {
      for stop in [1, 3, 100] {
        for limit in [Some(0L), Some(2L), None] {
          let sinks : Array[BufferedTrace] = []
          for enabled in [false, true] {
            let sink : BufferedTrace = {
              enabled,
              attempts: 0,
              accepted: 0,
              trace: {
                enabled: false,
                stop,
                calls: 0,
                synchronous_calls: 0,
                events: [],
              },
            }
            @searcher.SearcherBuilder::new()
            .line_number(true)
            .before_context(context)
            .after_context(context)
            .invert_match(invert)
            .max_matches(limit)
            .build()
            .search_reader(
              matcher,
              @searcher.SliceReader::from_bytes(input),
              sink,
            )
            sinks.push(sink)
          }
          assert_eq(sinks[0].trace.events, sinks[1].trace.events)
          if context == 0 && !invert && stop == 100 && limit is None {
            assert_true(sinks[1].accepted > 0)
            assert_true(sinks[1].attempts > sinks[1].accepted)
          }
          if context > 0 || invert {
            assert_eq(sinks[1].attempts, 0)
          }
        }
      }
    }
  }
}
