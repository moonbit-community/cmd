///|
priv struct SpanInput {
  bytes : Bytes
  chunk : Int32
  fail_at_end : Bool
  mut pos : Int32
}

///|
impl @searcher.Reader for SpanInput with fn read(self, buf, start, len) {
  if self.pos == self.bytes.length() && self.fail_at_end {
    fail("injected input failure")
  }
  let count = len.min(self.chunk).min(self.bytes.length() - self.pos)
  for index in 0..<count {
    buf[start + index] = self.bytes[self.pos + index]
  }
  self.pos += count
  count
}

///|
priv struct SpanOutput {
  bytes : Array[Byte]
  limit : Int32
  budget : Int32
}

///|
impl @io.Writer for SpanOutput with fn write_once(self, bytes, offset~, len~) {
  let remaining = self.budget - self.bytes.length()
  if remaining == 0 {
    raise @os_error.OSError(32, context="injected output failure")
  }
  let count = len.min(remaining).min(self.limit)
  for index in offset..<(offset + count) {
    self.bytes.push(bytes[index])
  }
  count
}

///|
async fn span_output(
  input : Bytes,
  pattern : String,
  coalesce : Bool,
  chunk~ : Int32 = 65536,
  binary~ : @searcher.BinaryDetection = BinaryNone,
  term~ : @matcher.LineTerminator = @matcher.LineTerminator::byte(b'\n'),
  read_failure~ : Bool = false,
  budget~ : Int32 = 2147483647,
  partial~ : Int32 = 4096,
  line_numbers~ : Bool = false,
  byte_offsets~ : Bool = false,
  path~ : String? = None,
  line_buffered~ : Bool = false,
  max_matches~ : Int64? = None,
  initial_buffer~ : Bool = false,
  initial_capacity~ : Int32 = 65536,
  encoding~ : String? = None,
  only_matching~ : Bool = false,
  per_match~ : Bool = false,
  column~ : Bool = false,
  replacement~ : Bytes? = None,
  trim_ascii~ : Bool = false,
  max_columns~ : Int64? = None,
  heading~ : Bool = false,
  path_terminator~ : Byte? = None,
) -> (Bytes, Bool, Bool, Int64?) {
  let destination : SpanOutput = { bytes: [], limit: partial, budget, }
  let output : StdoutWriter = {
    output: @stream.BlockWriter::new(
      StdoutSink::{ writer: destination, },
      size=8192,
      line_buffered~,
    ),
  }
  let printer = @printer.Standard::new(
    @termcolor.NoColor::new(output),
    coalesce_matches=coalesce,
    byte_offset=byte_offsets,
    only_matching~,
    per_match~,
    column~,
    replacement~,
    trim_ascii~,
    max_columns~,
    heading~,
    path_terminator~,
  )
  let matcher = SearchMatcher::new([pattern], line_terminator=Some(term))
  let sink = match path {
    Some(path) => printer.sink_with_path(matcher, path)
    None => printer.sink(matcher)
  }
  let reader : SpanInput = {
    bytes: input,
    chunk,
    fail_at_end: read_failure,
    pos: 0,
  }
  let source : &@searcher.Reader = if initial_buffer {
    (
      FileReadBuffer::new(reader, FixedArray::make(initial_capacity, b'\x00')) :
      &@searcher.Reader)
  } else {
    (reader : &@searcher.Reader)
  }
  let failed = try {
    @searcher.SearcherBuilder::new()
    .line_number(line_numbers)
    .max_matches(max_matches)
    .encoding(encoding.map(@searcher.Encoding::new))
    .line_terminator(term)
    .binary_detection(binary)
    .build()
    .search_reader(matcher, source, sink)
    false
  } catch {
    _ => true
  }
  let flush_failed = try {
    @termcolor.Write::flush(output)
    false
  } catch {
    _ => true
  }
  let bytes = Bytes::from_array(destination.bytes)
  // Cleanup must not replay any prefix consumed by a failed write.
  @termcolor.Write::flush(output)
  assert_eq(Bytes::from_array(destination.bytes), bytes)
  (bytes, failed || flush_failed, sink.has_match(), sink.binary_byte_offset())
}

///|
async test "plain match spans preserve gaps final records decoding and binary events" {
  for
    (input, expected) in [
      (b"", b""),
      (b"hit\nhit\nmiss\nhit", b"hit\nhit\nhit\n"),
      (b"hit\r\nhit\r\nmiss\n", b"hit\r\nhit\r\n"),
      (b"\xffhit\nhit\x00x\n", b"\xffhit\nhit\x00x\n"),
    ] {
    for chunk in [1, 2, 7, 8192, 65536] {
      for enabled in [false, true] {
        let result = span_output(input, "hit", enabled, chunk~)
        assert_eq(result.0, expected)
        assert_false(result.1)
      }
    }
  }
  for pattern in ["hit", "h.t", "^hit$", "hit|miss", ""] {
    for
      term in [
        @matcher.LineTerminator::byte(b'\n'),
        @matcher.LineTerminator::crlf(),
        @matcher.LineTerminator::byte(b'\x00'),
      ] {
      for
        binary in [
          @searcher.BinaryDetection::BinaryNone,
          BinaryQuit(b'\x00'),
          BinaryConvert(b'\x00'),
        ] {
        for chunk in [2, 7, 65536] {
          let input = b"hit\nhit\r\nmiss\nhit\x00hit\nlast hit"
          assert_eq(
            span_output(input, pattern, true, chunk~, term~, binary~),
            span_output(input, pattern, false, chunk~, term~, binary~),
          )
        }
      }
    }
  }
}

///|
async test "plain match spans preserve buffer seams long records and binary stop prefixes" {
  for size in [8191, 8192, 8193, 65535, 65536, 65537, 1048576] {
    let prefix = Bytes::make(size, b'x') + b"hit\nhit\n"
    for suffix in [b"miss\nhit", b"\x00hit\nhit\n"] {
      for
        binary in [
          @searcher.BinaryDetection::BinaryNone,
          BinaryQuit(b'\x00'),
          BinaryConvert(b'\x00'),
        ] {
        let input = prefix + suffix
        assert_eq(
          span_output(input, "hit", true, binary~),
          span_output(input, "hit", false, binary~),
        )
      }
    }
  }
}

///|
async test "plain match spans preserve partial write failure prefixes" {
  let record = b"hit" + Bytes::make(76, b'x') + b"\n"
  let input = Bytes::makei(65520, index => record[index % record.length()])
  for budget in [0, 1, 2, 8191, 8192, 8193, 16384, 65520, 65521] {
    for partial in [3, 4096, 65536] {
      let reference = span_output(input, "hit", false, budget~, partial~)
      let candidate = span_output(input, "hit", true, budget~, partial~)
      assert_eq(candidate, reference)
      assert_eq(candidate.0, input[:budget.min(input.length())].to_owned())
      assert_eq(candidate.1, budget < input.length())
    }
  }
}

///|
async test "plain match spans preserve output when a later read fails" {
  let record = b"hit" + Bytes::make(76, b'x') + b"\n"
  let input = Bytes::makei(65520, index => record[index % record.length()])
  for chunk in [8192, 65536] {
    let reference = span_output(input, "hit", false, chunk~, read_failure=true)
    let candidate = span_output(input, "hit", true, chunk~, read_failure=true)
    assert_eq(candidate, reference)
    assert_true(candidate.1)
    assert_eq(candidate.0, input)
  }
}

///|
async test "plain output preserves first hits after unmatched buffers and failures" {
  let miss = b"not selected\n"
  let gap = Bytes::makei(262144, index => miss[index % miss.length()]) + b"\n"
  let input = gap + b"hit\nhit\n" + gap + b"hit\n" + gap
  for chunk in [8192, 65536, 262144] {
    for pattern in ["hit", "h.t", "^hit$"] {
      for read_failure in [false, true] {
        let expected = span_output(input, pattern, false, chunk~, read_failure~)
        let actual = span_output(input, pattern, true, chunk~, read_failure~)
        assert_eq(actual, expected)
        assert_eq(actual.0, b"hit\nhit\nhit\n")
        assert_eq(actual.1, read_failure)
      }
    }
  }
}

///|
async test "text output batches preserve write failure prefixes across read windows" {
  let record = b"hit" + Bytes::make(76, b'x') + b"\n"
  let input = Bytes::makei(327600, index => record[index % record.length()])
  for
    budget in [
      0, 8191, 8192, 65535, 65536, 65537, 131071, 131072, 262143, 327600,
    ] {
    for partial in [3, 4096] {
      let baseline = span_output(
        input,
        "hit",
        false,
        chunk=262144,
        budget~,
        partial~,
      )
      let candidate = span_output(
        input,
        "hit",
        true,
        chunk=262144,
        budget~,
        partial~,
      )
      assert_eq(candidate, baseline)
      assert_eq(candidate.0, input[:budget].to_owned())
      assert_eq(candidate.1, budget < input.length())
    }
  }
}

///|
async test "text output batches preserve complete records before a read error" {
  let record = b"hit" + Bytes::make(76, b'x') + b"\n"
  for size in [65520, 131040, 262080, 327600] {
    let complete = Bytes::makei(size, index => record[index % record.length()])
    let input = complete + b"hit unfinished"
    let baseline = span_output(
      input,
      "hit",
      false,
      chunk=262144,
      read_failure=true,
    )
    let candidate = span_output(
      input,
      "hit",
      true,
      chunk=262144,
      read_failure=true,
    )
    assert_eq(candidate, baseline)
    assert_eq(candidate.0, complete)
    assert_true(candidate.1)
  }
}

///|
async test "plain binary output keeps matches from the original read window" {
  let input = b"hit\n" +
    Bytes::makei(70000, index => if index % 80 == 79 { b'\n' } else { b'x' }) +
    b"\x00hit\n"
  for
    binary in [
      @searcher.BinaryDetection::BinaryConvert(b'\x00'),
      BinaryQuit(b'\x00'),
    ] {
    let baseline = span_output(input, "hit", false, chunk=262144, binary~)
    let candidate = span_output(input, "hit", true, chunk=262144, binary~)
    assert_eq(candidate, baseline)
    assert_eq(candidate.0[:4].to_owned(), b"hit\n")
  }
}

///|
async test "NUL record output batches preserve gaps and final records" {
  let record = b"miss\x00"
  let gap = Bytes::makei(150000, index => record[index % record.length()])
  let input = gap + b"hit\x00hit\x00" + gap + b"hit"
  for chunk in [65536, 262144] {
    let term = @matcher.LineTerminator::byte(b'\x00')
    let baseline = span_output(input, "hit", false, chunk~, term~)
    let candidate = span_output(input, "hit", true, chunk~, term~)
    assert_eq(candidate, baseline)
    assert_eq(candidate.0, b"hit\x00hit\x00hit\x00")
  }
}
