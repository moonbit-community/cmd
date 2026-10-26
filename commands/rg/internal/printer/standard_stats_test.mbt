///|
/// A fake monotonic clock that advances by one microsecond per call. Rust
/// uses `Instant::now()`; the MoonBit printers take an explicit clock.
fn fake_clock() -> () -> Int64 {
  let now = Ref(0L)
  fn() {
    now.val += 1000L
    now.val
  }
}

///|
async test "reports_stats" {
  let matcher = @grep_regex.RegexMatcher::new("Sherlock|opposed")
  let out = @termcolor.ByteVec::new()
  let printer = @printer.StandardBuilder::new()
    .stats(true)
    .clock(fake_clock())
    .build(@termcolor.NoColor::new(out))
  let stats = {
    let sink = printer.sink(matcher)
    @searcher.SearcherBuilder::new()
    .line_number(false)
    .build()
    .search_reader(matcher, reader(str_bytes(sherlock)), sink)
    sink.stats().unwrap().clone()
  }
  let buf = out.to_bytes()
  assert_true(stats.elapsed() > 0L)
  assert_eq(stats.searches(), 1)
  assert_eq(stats.searches_with_match(), 1)
  assert_eq(stats.bytes_searched(), str_bytes(sherlock).length().to_int64())
  assert_eq(stats.bytes_printed(), buf.length().to_int64())
  assert_eq(stats.matched_lines(), 2)
  assert_eq(stats.matches(), 3)
}

///|
async test "reports_stats_multiple" {
  let matcher = @grep_regex.RegexMatcher::new("Sherlock|opposed")
  let out = @termcolor.ByteVec::new()
  let printer = @printer.StandardBuilder::new()
    .stats(true)
    .clock(fake_clock())
    .build(@termcolor.NoColor::new(out))
  let stats = {
    let sink = printer.sink(matcher)
    @searcher.SearcherBuilder::new()
    .line_number(false)
    .build()
    .search_reader(matcher, reader(str_bytes(sherlock)), sink)
    @searcher.SearcherBuilder::new()
    .line_number(false)
    .build()
    .search_reader(matcher, reader(b"zzzzzzzzzz"), sink)
    @searcher.SearcherBuilder::new()
    .line_number(false)
    .build()
    .search_reader(matcher, reader(str_bytes(sherlock)), sink)
    sink.stats().unwrap().clone()
  }
  let buf = out.to_bytes()
  assert_true(stats.elapsed() > 0L)
  assert_eq(stats.searches(), 3)
  assert_eq(stats.searches_with_match(), 2)
  assert_eq(
    stats.bytes_searched(),
    10L + 2L * str_bytes(sherlock).length().to_int64(),
  )
  assert_eq(stats.bytes_printed(), buf.length().to_int64())
  assert_eq(stats.matched_lines(), 4)
  assert_eq(stats.matches(), 6)
}
