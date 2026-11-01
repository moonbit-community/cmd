///|
async test "record batches preserve selected runs, offsets and the partial tail" {
  let reader = @io.MemoryReader(_ => ())
  defer reader.close()
  let input = GrepInput::new(reader, b'\n', Text)
  input.bytes = b"hit\nhit\nmiss\nhit\ntail"
  let output = @buffer.Buffer()
  assert_eq(
    input.collect_records(
      Fixed([b"hit"], false, false),
      streaming_options(),
      output,
    ),
    3UL,
  )
  assert_eq(output.to_bytes(), b"hit\nhit\nhit\n")
  assert_eq(input.position, 17)
  assert_eq(input.offset, 17L)
  assert_eq(input.number, 4L)
  assert_eq(input.bytes[input.position:], b"tail"[:])
}

///|
async test "whole record batches preserve inversion, NUL, CRLF and missing terminators" {
  for
    (data, invert, nul, expected) in [
      (b"hit\nhit\nmiss\nhit", false, false, b"hit\nhit\nhit\n"),
      (b"hit\nmiss\nmiss\nhit", true, false, b"miss\nmiss\n"),
      (b"hit\x00hit\x00miss\x00hit", false, true, b"hit\x00hit\x00hit\x00"),
      (b"hit\r\nhit\r\nmiss\r\nhit\r", false, false, b"hit\r\nhit\r\nhit\r\n"),
    ] {
    let input = @io.MemoryReader(writer => writer.write(data))
    defer input.close()
    let output : CapturedOutput = { bytes: [], }
    let errors : CapturedOutput = { bytes: [], }
    let options = {
      ..streaming_options(),
      invert,
      zero_terminated: nul,
      binary_mode: Text,
    }
    assert_true(
      process_reader(
        input,
        "-",
        Fixed([b"hit"], false, false),
        options,
        false,
        stdout=output,
        stderr=errors,
      ),
    )
    assert_eq(Bytes::from_array(output.bytes), expected)
    assert_eq(errors.bytes.length(), 0)
  }
}

///|
async test "whole record batches preserve cross-chunk records and final tails" {
  let data = Bytes::makei(140000, i => if i % 4 == 3 { b'\n' } else { b'a' }) +
    Bytes::make(70000, b'a')
  let input = @io.MemoryReader(writer => writer.write(data))
  defer input.close()
  let output : CapturedOutput = { bytes: [], }
  let errors : CapturedOutput = { bytes: [], }
  assert_true(
    process_reader(
      input,
      "-",
      Fixed([b"a"], false, false),
      { ..streaming_options(), binary_mode: Text, },
      false,
      stdout=output,
      stderr=errors,
    ),
  )
  assert_eq(Bytes::from_array(output.bytes), data + b"\n")
}

///|
async test "whole record batches do not retry a partial output failure" {
  let input = @io.MemoryReader(writer => {
    writer.write(
      Bytes::makei(160000, i => if i % 2 == 0 { b'a' } else { b'\n' }),
    )
  })
  defer input.close()
  let output : FailingSpanWriter = { bytes: [], calls: 0, }
  let errors : CapturedOutput = { bytes: [], }
  let failed = try {
    ignore(
      process_reader(
        input,
        "-",
        Fixed([b"a"], false, false),
        { ..streaming_options(), binary_mode: Text, },
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
