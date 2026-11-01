///|
priv struct AuditReadRequests {
  inner : @searcher.SliceReader
  requests : Array[Int32]
}

///|
impl @searcher.Reader for AuditReadRequests with fn read(self, buf, start, len) {
  self.requests.push(len)
  @searcher.Reader::read(self.inner, buf, start, len)
}

///|
priv struct AuditBulkCount {
  bulk : Bool
  mut matches : Int64
}

///|
impl @searcher.Sink for AuditBulkCount with fn bulk_scan(self) {
  self.bulk
}

///|
impl @searcher.Sink for AuditBulkCount with fn synchronous_count(self) {
  Some(count => self.matches += count)
}

///|
impl @searcher.Sink for AuditBulkCount with fn matched(self, _, _) {
  self.matches += 1L
  true
}

///|
fn audit_count_sink(bulk : Bool) -> AuditBulkCount {
  { bulk, matches: 0L, }
}

///|
async test "audit reused regex probe must retain its nominal read bound" {
  let matcher = SearchMatcher::new(
    ["a[bc]+d"],
    line_terminator=Some(@matcher.LineTerminator::byte(b'\n')),
  )
  for initial_bulk in [false, true] {
    for bulk in [false, true] {
      let searcher = @searcher.SearcherBuilder::new().build()
      let first = audit_count_sink(initial_bulk)
      // An early hit declines streaming and grows the ordinary line buffer.
      searcher.search_reader(
        matcher,
        @searcher.SliceReader::from_bytes(b"abcd" + Bytes::make(2097152, b'x')),
        first,
      )
      assert_eq(first.matches, 1L)
      let failed_count = audit_count_sink(bulk)
      try
        searcher.search_reader(
          matcher,
          BrokenRegexCountReader::{ bytes: b"abcd\npartial", position: 0, },
          failed_count,
        )
      catch {
        error =>
          assert_true(error.to_string().contains("regex stream read failed"))
      } noraise {
        _ => fail("expected injected read failure")
      }
      assert_eq(failed_count.matches, 1L)
      for
        (input, expected, streaming) in [
          (Bytes::make(300000, b'x') + b"abcd", 1L, true),
          (b"abcd\n", 1L, false),
          (b"", 0L, false),
          (
            b"\xff\xfe" + b"x\x00".repeat(300000) + b"a\x00b\x00c\x00d\x00",
            1L,
            true,
          ),
        ] {
        let second = audit_count_sink(bulk)
        let observed : AuditReadRequests = {
          inner: @searcher.SliceReader::from_bytes(input),
          requests: [],
        }
        searcher.search_reader(matcher, observed, second)
        assert_eq(second.matches, expected)
        let fresh = audit_count_sink(bulk)
        let fresh_reader : AuditReadRequests = {
          inner: @searcher.SliceReader::from_bytes(input),
          requests: [],
        }
        @searcher.SearcherBuilder::new()
        .build()
        .search_reader(matcher, fresh_reader, fresh)
        assert_eq(fresh.matches, second.matches)
        // Replay resumes ordinary buffered reads, whose independent cap is 1 MiB.
        let limit = if streaming {
          if bulk {
            262144
          } else {
            65536
          }
        } else {
          1048576
        }
        assert_true(
          observed.requests.all(n => n <= limit),
          msg="reused=\{Repr(observed.requests)}; fresh=\{Repr(fresh_reader.requests)}",
        )
        if streaming {
          assert_eq(observed.requests, fresh_reader.requests)
        }
      }
    }
  }
}
