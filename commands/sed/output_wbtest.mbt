///|
fn sed_test_runtime(writer : &@io.Writer) -> Runtime {
  {
    previous: None,
    missing_newline: false,
    output: @stream.BlockWriter::new(writer),
  }
}

///|
fn sed_test_input(reader : &@io.Reader, runtime : Runtime) -> Input {
  { ..sed_address_input(0), reader: Some(reader), output: runtime.output, }
}

///|
priv struct SedOutput {
  bytes : Array[Byte]
  mut calls : Int32
  mut budget : Int32
}

///|
impl @io.Writer for SedOutput with fn write_once(self, bytes, offset~, len~) {
  self.calls += 1
  guard self.budget > 0 else { fail("injected sed output failure") }
  let count = len.min(self.budget)
  for i in offset..<(offset + count) {
    self.bytes.push(bytes[i])
  }
  self.budget -= count
  count
}

///|
async test "sed synchronous output admission preserves slow path newline ownership" {
  let output : SedOutput = { bytes: [], calls: 0, budget: 100, }
  let runtime = {
    ..sed_test_runtime(output),
    output: @stream.BlockWriter::new(output, size=8),
  }
  assert_true(runtime.buffer_space(Space::from_bytes(b"abc"[:], false)) is None)
  assert_true(runtime.missing_newline)
  let second = Space::from_bytes(b"123456789"[:], true)
  assert_true(runtime.buffer_space(second) is Some(_))
  assert_true(runtime.missing_newline)
  assert_eq(output.calls, 0)
  runtime.emit_space(second)
  runtime.output.flush()
  assert_false(runtime.missing_newline)
  assert_eq(Bytes::from_array(output.bytes), b"abc\n123456789\n")
}

///|
test "sed cached record admission never consumes a spanning record" {
  let input = { ..sed_address_input(7), buffer: b"a\n\x00\xff\ntail", }
  let first = input.next_cached().unwrap()
  assert_eq(first.data, b"a"[:])
  assert_true(first.terminated)
  assert_eq(input.number, 8)
  let second = input.next_cached().unwrap()
  assert_eq(second.data, b"\x00\xff"[:])
  assert_eq(input.number, 9)
  assert_eq(input.position, 5)
  assert_true(input.next_cached() is None)
  assert_eq(input.position, 5)
  assert_eq(input.number, 9)
  input.buffer = b"replacement"
  assert_eq(first.data, b"a"[:])
  assert_eq(second.data, b"\x00\xff"[:])
}

///|
async test "sed delivers completed output before waiting for another input chunk" {
  let output : SedOutput = { bytes: [], calls: 0, budget: 1000, }
  let runtime = sed_test_runtime(output)
  let reader = @io.MemoryReader(writer => {
    writer.write(b"one\n")
    while output.bytes.length() < 4 {
      @async.sleep(1)
    }
    writer.write(b"two\n")
  })
  defer reader.close()
  let input = sed_test_input(reader, runtime)
  @async.with_timeout(2000, () => {
    execute(compile("", false), input, false, runtime)
  })
  assert_eq(Bytes::from_array(output.bytes), b"one\ntwo\n")
}

///|
async test "sed buffered output failure precedes a later script error without replay" {
  for budget in [1, 1000] {
    let output : SedOutput = { bytes: [], calls: 0, budget, }
    let runtime = sed_test_runtime(output)
    let reader = @io.MemoryReader(writer => writer.write(b"one\n"))
    defer reader.close()
    try
      execute(
        compile("p;s//X/", false),
        sed_test_input(reader, runtime),
        true,
        runtime,
      )
    catch {
      SedError(message) =>
        assert_eq(
          message,
          if budget == 1 {
            "injected sed output failure"
          } else {
            "no previous regular expression"
          },
        )
      error => fail("unexpected error: \{error}")
    } noraise {
      _ => fail("must report the first observable failure")
    }
    runtime.output.flush()
    assert_eq(
      Bytes::from_array(output.bytes),
      if budget == 1 {
        b"o"
      } else {
        b"one\n"
      },
    )
    assert_eq(output.calls, if budget == 1 { 2 } else { 1 })
  }
}

///|
async test "sed buffered output failure precedes a failing input read" {
  let output : SedOutput = { bytes: [], calls: 0, budget: 2, }
  let runtime = sed_test_runtime(output)
  let reader = @io.MemoryReader(writer => {
    writer.write(b"one\n")
    @async.sleep(5)
    fail("late input failure")
  })
  defer reader.close()
  let input = sed_test_input(reader, runtime)
  try execute(compile("", false), input, false, runtime) catch {
    SedError(message) => assert_eq(message, "injected sed output failure")
    error => fail("unexpected error: \{error}")
  } noraise {
    _ => fail("must propagate output failure")
  }
  assert_eq(input.status, 0)
  assert_eq(Bytes::from_array(output.bytes), b"on")
  assert_eq(output.calls, 2)
}

///|
async test "sed buffered output retains n N append and unterminated boundaries" {
  for
    (script, quiet, bytes, expected) in [
      ("a\\\nA\nn", false, b"one\ntwo\n", b"one\nA\ntwo\n"),
      ("a\\\nA\nN;p", true, b"one\ntwo", b"A\none\ntwo"),
      ("p;p", true, b"one", b"one\none"),
      ("a\\\nA\nq", false, b"one", b"one\nA\n"),
    ] {
    let output : SedOutput = { bytes: [], calls: 0, budget: 1000, }
    let runtime = sed_test_runtime(output)
    let reader = @io.MemoryReader(writer => writer.write(bytes))
    defer reader.close()
    execute(
      compile(script, false),
      sed_test_input(reader, runtime),
      quiet,
      runtime,
    )
    assert_eq(Bytes::from_array(output.bytes), expected)
  }
}

///|
async test "sed record scanning preserves all bytes and fragmented final records" {
  let all = Bytes::makei(256, i => i.to_byte())
  let long = Bytes::make(65539, b'x')
  let input_bytes = b"\n" + all + long + b"\nlast"
  for chunk in [1, 257, 65536] {
    let reader = @io.MemoryReader(writer => {
      for start = 0; start < input_bytes.length(); start = start + chunk {
        writer.write(
          input_bytes[start:(start + chunk).min(input_bytes.length())],
        )
      }
    })
    defer reader.close()
    let output : SedOutput = {
      bytes: [],
      calls: 0,
      budget: input_bytes.length() + 1,
    }
    let runtime = sed_test_runtime(output)
    let input = sed_test_input(reader, runtime)
    execute(compile("", false), input, false, runtime)
    assert_eq(Bytes::from_array(output.bytes), input_bytes)
    assert_eq(input.number, 4)
  }
}

///|
async test "sed raw spaces preserve bytes without decoding and retain independent hold contents" {
  let data = Bytes::makei(256, i => i.to_byte())
  let space = Space::from_bytes(data[:], false)
  let output : SedOutput = { bytes: [], calls: 0, budget: 1000, }
  let runtime = sed_test_runtime(output)
  assert_true(
    compile("2p", false)[0].selected(sed_address_input(2), space, runtime),
  )
  runtime.emit_space(space)
  runtime.output.flush()
  assert_true(space.decoded is None)
  assert_eq(Bytes::from_array(output.bytes), data)
  assert_eq(@bytere.bytes(space.text()), data)
  assert_true(space.decoded is Some(_))
  let appended = space.append(Space::from_text("tail", true))
  assert_eq(@bytere.bytes(appended.text()), data + b"\ntail")
  assert_eq(@bytere.bytes(space.text()), data)
  assert_false(space.terminated)
}

///|
async test "sed raw spaces survive refills substitutions hold exchange and multiline restart" {
  let long = Bytes::make(65539, b'x')
  for
    (script, quiet, data, expected) in [
      ("1h;2{g;s/old/NEW/;p;g;p;}", true, b"old\nnew\n", b"NEW\nold\n"),
      ("1h;2{x;p;x;p;}", true, b"old\nnew\n", b"old\nnew\n"),
      ("N;P;D", true, b"one\ntwo\nthree", b"one\ntwo\n"),
      (
        "1h;$g",
        false,
        b"seed\n" + long + b"\nlast",
        b"seed\n" + long + b"\nseed\n",
      ),
      ("s/a/a/;t yes;d;:yes;p", true, b"a\nb\n", b"a\n"),
      ("s/a/Z/3g;t yes;p;d;:yes;d", true, b"aa\n", b"aa\n"),
    ] {
    for chunk in [257, 65536] {
      let reader = @io.MemoryReader(writer => {
        for start = 0; start < data.length(); start = start + chunk {
          writer.write(data[start:(start + chunk).min(data.length())])
        }
      })
      defer reader.close()
      let output : SedOutput = {
        bytes: [],
        calls: 0,
        budget: expected.length() + 1,
      }
      let runtime = sed_test_runtime(output)
      execute(
        compile(script, false),
        sed_test_input(reader, runtime),
        quiet,
        runtime,
      )
      assert_eq(Bytes::from_array(output.bytes), expected, msg=script)
    }
  }
}

///|
async test "sed record output preserves separators and termination across buffer boundaries" {
  for length in [0, 1, 65535, 65536, 65537] {
    let bytes = Bytes::makei(length, i => (i % 256).to_byte())
    for terminated in [false, true] {
      for missing in [false, true] {
        let expected = (if missing { b"\n" } else { b"" }) +
          bytes +
          (if terminated { b"\n" } else { b"" })
        let output : SedOutput = {
          bytes: [],
          calls: 0,
          budget: expected.length() + 1,
        }
        let runtime = sed_test_runtime(output)
        runtime.missing_newline = missing
        runtime.emit_space(Space::from_bytes(bytes[:], terminated))
        runtime.output.flush()
        assert_eq(Bytes::from_array(output.bytes), expected)
        assert_eq(runtime.missing_newline, !terminated)
      }
    }
  }
}
