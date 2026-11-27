///|
test "count parser accepts documented signed and scaled forms" {
  assert_true(parse_count("10") is First(10L))
  assert_true(parse_count("-2") is AllButLast(2L))
  assert_true(parse_count("+3") is First(3L))
  assert_true(parse_count("2K") is First(2048L))
  assert_true(parse_count("2KiB") is First(2048L))
  assert_true(parse_count("2KB") is First(2000L))
}

///|
test "legacy count normalization does not rewrite option values" {
  assert_eq(legacy_count_args(["-2", "file"]), ["-n", "2", "file"])
  assert_eq(legacy_count_args(["-2kq", "file"]), ["-c", "2K", "-q", "file"])
  assert_eq(legacy_count_args(["-n", "-2"]), ["-n", "-2"])
  assert_eq(legacy_count_args(["file", "-2"]), ["file", "-2"])
}

///|
priv suberror HeadTestFailure

///|
priv struct HeadTestWriter {
  controller : @io.BinaryWriterController
  bytes : Array[Byte]
  mut budget : Int32?
}

///|
impl @io.BinaryWriter for HeadTestWriter

///|
impl @io.BinaryWriterImpl for HeadTestWriter with fn name(_) {
  "HeadTestWriter"
}

///|
impl @io.BinaryWriterImpl for HeadTestWriter with fn get_controller(self) {
  self.controller
}

///|
impl @io.BinaryWriterImpl for HeadTestWriter with fn flush_partial_data(_) {
  ()
}

///|
impl @io.BinaryWriterImpl for HeadTestWriter with fn raw_write_impl(
  self,
  data,
  offset~,
  len~,
) {
  let count = match self.budget {
    Some(0) => raise HeadTestFailure
    Some(remaining) => {
      let count = remaining.min(len)
      self.budget = Some(remaining - count)
      count
    }
    None => len
  }
  for byte in data[offset:offset + count] {
    self.bytes.push(byte)
  }
  count
}

///|
async test "head buffered output preserves record delimiters and byte modes" {
  for
    (data, spec, bytes_mode, delimiter, expected) in [
      (b"a\x00b\x00tail", First(2L), false, b'\x00', b"a\x00b\x00"),
      (b"a\nb\nlast", AllButLast(1L), false, b'\n', b"a\nb\n"),
      (b"\x00\xffa\n", First(3L), true, b'\n', b"\x00\xffa"),
      (b"abcde", AllButLast(2L), true, b'\n', b"abc"),
    ] {
    let reader = @io.MemoryReader(writer => writer.write(data))
    defer reader.close()
    let capture : HeadTestWriter = {
      controller: @io.BinaryWriterController(),
      bytes: [],
      budget: None,
    }
    let output = @io.BufferedWriter(capture, size=CHUNK_SIZE)
    head_reader(reader, output, spec, bytes_mode, delimiter)
    output.flush()
    assert_eq(Bytes::from_array(capture.bytes), expected)
  }
}

///|
async test "head flushes completed output after input failure and marks failed writes" {
  for bytes_mode in [false, true] {
    let reader = @io.MemoryReader(writer => {
      writer.write(b"kept\npartial")
      raise HeadTestFailure
    })
    defer reader.close()
    let capture : HeadTestWriter = {
      controller: @io.BinaryWriterController(),
      bytes: [],
      budget: None,
    }
    let sink : HeadOutput = { writer: capture, failed: false, }
    let output = @io.BufferedWriter(sink, size=CHUNK_SIZE)
    try head_reader(reader, output, First(100L), bytes_mode, b'\n') catch {
      err => assert_true(@stream.transport_cause(err) is HeadTestFailure)
    } noraise {
      _ => fail("expected input failure")
    }
    output.flush()
    assert_false(sink.failed)
    assert_eq(
      Bytes::from_array(capture.bytes),
      if bytes_mode {
        b"kept\npartial"
      } else {
        b"kept\n"
      },
    )
  }
  let reader = @io.MemoryReader(writer => writer.write(b"abcdef\n"))
  defer reader.close()
  let capture : HeadTestWriter = {
    controller: @io.BinaryWriterController(),
    bytes: [],
    budget: Some(2),
  }
  let sink : HeadOutput = { writer: capture, failed: false, }
  let output = @io.BufferedWriter(sink, size=4)
  try head_reader(reader, output, First(1L), false, b'\n') catch {
    err => assert_true(@stream.transport_cause(err) is HeadTestFailure)
  } noraise {
    _ => fail("expected output failure")
  }
  assert_true(sink.failed)
  assert_eq(Bytes::from_array(capture.bytes), b"ab")
}
