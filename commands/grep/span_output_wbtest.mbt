///|
async test "span output keeps NUL delimiters and per-match byte prefixes" {
  let input = @io.MemoryReader(writer => writer.write(b"\xffaa aa\x00aa"))
  defer input.close()
  let output : CapturedOutput = { bytes: [], }
  let errors : CapturedOutput = { bytes: [], }
  let options = {
    ..streaming_options(),
    only_matching: true,
    zero_terminated: true,
    line_number: true,
    byte_offset: true,
  }
  let matcher = Regular(
    [@bytere.compile("a+", extended=true).record_matcher()],
    false,
    false,
  )
  assert_true(
    process_reader(
      input,
      "file",
      matcher,
      options,
      true,
      stdout=output,
      stderr=errors,
    ),
  )
  assert_eq(
    Bytes::from_array(output.bytes),
    b"file:1:1:aa\x00file:1:4:aa\x00file:2:7:aa\x00",
  )
  assert_eq(errors.bytes.length(), 0)
}

///|
async test "span output flushes a complete and partial record before a read error" {
  let input = @io.MemoryReader(writer => {
    writer.write(b"needle\npartneedle")
    @async.sleep(1)
    fail("span read failure")
  })
  defer input.close()
  let output : CapturedOutput = { bytes: [], }
  let errors : CapturedOutput = { bytes: [], }
  let options = {
    ..streaming_options(),
    only_matching: true,
    binary_mode: Text,
  }
  let failed = try {
    ignore(
      process_reader(
        input,
        "-",
        Fixed([b"needle"], false, false),
        options,
        false,
        stdout=output,
        stderr=errors,
      ),
    )
    false
  } catch {
    error => error.to_string().contains("span read failure")
  }
  assert_true(failed)
  assert_eq(Bytes::from_array(output.bytes), b"needle\nneedle\n")
}

///|
priv struct FailingSpanWriter {
  bytes : Array[Byte]
  mut calls : Int32
}

///|
impl @io.Writer for FailingSpanWriter with fn write_once(
  self,
  bytes,
  offset~,
  len~,
) {
  self.calls += 1
  if self.calls > 1 {
    fail("span write failure")
  }
  let count = len.min(2)
  for index in offset..<(offset + count) {
    self.bytes.push(bytes[index])
  }
  count
}

///|
async test "span output never retries a partially failed threshold flush" {
  let input = @io.MemoryReader(writer => {
    writer.write(
      Bytes::makei(80000, index => if index % 2 == 0 { b'a' } else { b'\n' }),
    )
  })
  defer input.close()
  let output : FailingSpanWriter = { bytes: [], calls: 0, }
  let errors : CapturedOutput = { bytes: [], }
  let options = {
    ..streaming_options(),
    only_matching: true,
    binary_mode: Text,
  }
  let failed = try {
    ignore(
      process_reader(
        input,
        "-",
        Fixed([b"a"], false, false),
        options,
        false,
        stdout=output,
        stderr=errors,
      ),
    )
    false
  } catch {
    error => error.to_string().contains("span write failure")
  }
  assert_true(failed)
  assert_eq(output.calls, 2)
  assert_eq(Bytes::from_array(output.bytes), b"a\n")
}

///|
async test "span output merges patterns by earliest start then longest end" {
  for
    (sources, data, word, expected) in [
      (["a.*z|b", "a+"], b"abz aa\n", false, b"abz\naa\n"),
      (["foo.", "foo"], b"foo.a\n", true, b"foo\n"),
      (["^a", "a+$"], b"aaa\n", false, b"aaa\n"),
    ] {
    let input = @io.MemoryReader(writer => writer.write(data))
    defer input.close()
    let output : CapturedOutput = { bytes: [], }
    let errors : CapturedOutput = { bytes: [], }
    let patterns = sources.map(source => {
      @bytere.compile(source, extended=true).record_matcher()
    })
    let options = {
      ..streaming_options(),
      only_matching: true,
      binary_mode: Text,
    }
    assert_true(
      process_reader(
        input,
        "-",
        Regular(patterns, false, word),
        options,
        false,
        stdout=output,
        stderr=errors,
      ),
    )
    assert_eq(Bytes::from_array(output.bytes), expected)
  }
}
