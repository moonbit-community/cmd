///|
async test "literal streaming keeps nominal reads while declined routes grow records" {
  for bulk in [false, true] {
    for
      (pattern, input, heap, streaming) in [
        ("abc", b"abc" + Bytes::make(2097152, b'x'), None, true),
        ("abc", b"abc" + Bytes::make(2097152, b'x'), Some(4194304), false),
        ("ab.c", b"abxc" + Bytes::make(2097152, b'x'), None, false),
      ] {
      let matcher = SearchMatcher::new(
        [pattern],
        line_terminator=Some(@matcher.LineTerminator::byte(b'\n')),
      )
      let requests : Array[Int32] = []
      let reader = AuditReadRequests::{
        inner: @searcher.SliceReader::from_bytes(input),
        requests,
      }
      let sink = audit_count_sink(bulk)
      @searcher.SearcherBuilder::new()
      .heap_limit(heap)
      .build()
      .search_reader(matcher, reader, sink)
      assert_eq(sink.matches, 1L)
      let nominal = if bulk { 262144 } else { 65536 }
      assert_eq(requests.iter().all(size => size <= nominal), streaming)
    }
  }
}

///|
priv struct FragmentedCountInput {
  inner : @searcher.SliceReader
  chunk : Int32
}

///|
impl @searcher.Reader for FragmentedCountInput with fn read(
  self,
  buf,
  start,
  len,
) {
  @searcher.Reader::read(self.inner, buf, start, len.min(self.chunk))
}

///|
async test "counting agrees across fragmented literals alternatives decoding and final records" {
  let inputs = [
    b"",
    b"\n",
    b"ab\nc\nabc",
    b"abc\nabc",
    b"abc\r\nabc\x00ab\n",
    b"\xffabc\n",
    @utf8.encode("甲乙\n甲\n乙\n"),
    b"\xff\xfea\x00b\x00c\x00\n\x00a\x00b\x00c\x00",
  ]
  for
    pattern in [
      "abc", "a|abc", "abc|b", "[ab]c", "甲乙", "^abc$", "(abc)", "", "a.*c",
    ] {
    let matcher = SearchMatcher::new(
      [pattern],
      line_terminator=Some(b'\n').map(@matcher.LineTerminator::byte),
    )
    for input in inputs {
      for chunk in [1, 2, 3, 7, 262144] {
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
          .build()
          .search_reader(matcher, reader, sink)
          results.push((sink.matches, sink.finish.unwrap().byte_count))
        }
        assert_eq(results[0], results[1], msg=pattern)
      }
    }
  }
}

///|
async test "counting preserves matches crossing bulk windows and long unmatched records" {
  let matcher = SearchMatcher::new(
    ["abc"],
    line_terminator=Some(b'\n').map(@matcher.LineTerminator::byte),
  )
  for offset in [262142, 262143, 262144] {
    let input = Bytes::make(offset, b'x') +
      b"abc\n" +
      Bytes::make(1048576, b'x') +
      b"\nabc"
    let results : Array[(Int64, Int64)] = []
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
      results.push((sink.matches, sink.finish.unwrap().byte_count))
    }
    assert_eq(results[0], (2L, input.length().to_int64()))
    assert_eq(results[0], results[1])
  }
}

///|
async test "counting does not bypass an explicit heap limit" {
  let matcher = SearchMatcher::new(
    ["hit"],
    line_terminator=Some(b'\n').map(@matcher.LineTerminator::byte),
  )
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
      .heap_limit(Some(32))
      .build()
      .search_reader(
        matcher,
        @searcher.SliceReader::from_bytes(Bytes::make(128, b'x') + b"hit"),
        sink,
      )
      false
    } catch {
      _ => true
    }
    assert_true(failed)
    assert_eq(sink.matches, 0L)
    assert_true(sink.finish is None)
  }
}
