///|
priv struct PolicySink {
  count : Bool
  spans : Bool
  synchronous : Bool
}

///|
impl Sink for PolicySink with fn synchronous_count(self) {
  if self.count {
    Some(_ => ())
  } else {
    None
  }
}

///|
impl Sink for PolicySink with fn coalesce_matches(self) {
  self.spans
}

///|
impl Sink for PolicySink with fn synchronous_matched(self) {
  if self.synchronous {
    Some((_, _) => true)
  } else {
    None
  }
}

///|
impl Sink for PolicySink with fn matched(_, _, _) {
  true
}

///|
test "record policies preserve count coalescing and synchronous stop boundaries" {
  let config = { ..SearcherConfig::default(), line_number: false, }
  let all = PolicySink::{ count: true, spans: true, synchronous: true, }
  let spans = PolicySink::{ ..all, count: false, }
  assert_true(config.line_execution(all, false) is Count(_))
  assert_true(config.line_execution(spans, false) is Coalesced(_))
  assert_true(
    config.line_execution(spans, false).after_binary() is Synchronous(_),
  )
  assert_true(config.line_execution(all, true) is Ordinary)
  assert_true(
    { ..config, line_number: true, }.line_execution(spans, false)
    is Synchronous(_),
  )
  assert_true(
    { ..config, max_matches: Some(1L), }.line_execution(all, false)
    is Synchronous(_),
  )
  for
    limited in [
      { ..config, invert_match: true, },
      { ..config, before_context: 1, },
      { ..config, after_context: 1, },
      { ..config, stop_on_nonmatch: true, },
    ] {
    assert_true(limited.line_execution(all, false) is Ordinary)
  }
  // Raw multiline and passthru disable bulk routes; dynamic Core gating still
  // decides whether a synchronous route can be used for the current buffer.
  for
    limited in [{ ..config, multi_line: true, }, { ..config, passthru: true, }] {
    assert_true(limited.line_execution(all, false) is Synchronous(_))
    assert_true(limited.stream_count_term() is None)
  }
  for
    buffered in [
      { ..config, binary: BinaryConvert(b'\x00'), },
      { ..config, heap_limit: Some(1024), },
      { ..config, line_term: @matcher.LineTerminator::crlf(), },
    ] {
    assert_true(buffered.line_execution(all, false) is Count(_))
    assert_true(buffered.stream_count_term() is None)
  }
  assert_true(config.stream_count_term() is Some(b'\n'))
  assert_true(
    { ..config, line_term: @matcher.LineTerminator::byte(b'\x00'), }.stream_count_term()
    is Some(b'\x00'),
  )
}

///|
test "prefetched prefixes preserve complete records and EOF without allocation growth" {
  let buffer = SearcherConfig::default().line_buffer(capacity=16)
  b"one\ntail".to_fixedarray().blit_to(buffer.buf, len=8)
  buffer.commit_prefix(8, false)
  assert_eq(buffer.buffer_len(), 4)
  buffer.clear()
  buffer.commit_prefix(8, true)
  assert_eq(buffer.buffer_len(), 8)
  buffer.clear()
  buffer.commit_prefix(0, true)
  assert_eq(buffer.buffer_len(), 0)
  assert_eq(buffer.capacity, 16)
}
