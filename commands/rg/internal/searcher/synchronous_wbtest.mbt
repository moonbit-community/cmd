///|
priv struct SynchronousTrace {
  enabled : Bool
  stop : Int32
  mut calls : Int32
  mut synchronous_calls : Int32
  events : Array[String]
}

///|
fn SynchronousTrace::record(self : SynchronousTrace, mat : SinkMatch) -> Bool {
  self.calls += 1
  self.events.push(
    "match:\{mat.absolute_byte_offset}:\{mat.line_number.map(value => value.to_string()).unwrap_or("-")}:\{@utf8.decode_lossy(mat.bytes())}",
  )
  self.calls < self.stop
}

///|
impl Sink for SynchronousTrace with fn synchronous_matched(self) {
  if self.enabled {
    Some((_, mat) => {
      self.synchronous_calls += 1
      self.record(mat)
    })
  } else {
    None
  }
}

///|
impl Sink for SynchronousTrace with fn matched(self, _, mat) {
  self.record(mat)
}

///|
impl Sink for SynchronousTrace with fn context(self, _, ctx) {
  self.events.push(
    "context:\{ctx.absolute_byte_offset}:\{ctx.line_number.map(value => value.to_string()).unwrap_or("-")}:\{@utf8.decode_lossy(ctx.bytes())}",
  )
  true
}

///|
impl Sink for SynchronousTrace with fn context_break(self, _) {
  self.events.push("break")
  true
}

///|
impl Sink for SynchronousTrace with fn binary_data(self, _, offset) {
  self.events.push("binary:\{offset}")
  true
}

///|
impl Sink for SynchronousTrace with fn finish(self, _, finish) {
  self.events.push(
    "finish:\{finish.byte_count}:\{finish.binary_byte_offset.map(value => value.to_string()).unwrap_or("-")}",
  )
}

///|
async test "synchronous reader summaries preserve events limits binary detection and fallback" {
  let matcher = @grep_regex.RegexMatcherBuilder::new()
    .line_terminator(Some(b'\n'))
    .build("hit")
  let input = b"skip\nhit one\nskip\nhit two\nhit three\x00tail\nhit end"
  for context in [0, 1] {
    for invert in [false, true] {
      for binary in [BinaryNone, BinaryQuit(b'\x00'), BinaryConvert(b'\x00')] {
        for stop in [1, 100] {
          for limit in [None, Some(0L), Some(2L)] {
            let traces : Array[SynchronousTrace] = []
            for enabled in [false, true] {
              let sink : SynchronousTrace = {
                enabled,
                stop,
                calls: 0,
                synchronous_calls: 0,
                events: [],
              }
              let searcher = SearcherBuilder::new()
                .line_number(true)
                .before_context(context)
                .after_context(context)
                .invert_match(invert)
                .binary_detection(binary)
                .max_matches(limit)
                .build()
              searcher.search_reader(
                matcher,
                SliceReader::from_bytes(input),
                sink,
              )
              traces.push(sink)
            }
            assert_eq(traces[0].events, traces[1].events)
            if context == 0 &&
              !invert &&
              limit != Some(0L) &&
              binary != BinaryQuit(b'\x00') {
              assert_true(traces[1].synchronous_calls > 0)
            } else {
              assert_eq(traces[1].synchronous_calls, 0)
            }
          }
        }
      }
    }
  }
}
