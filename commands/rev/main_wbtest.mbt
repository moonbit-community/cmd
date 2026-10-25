///|
async test "rev reverses records across scanner blocks and preserves termination" {
  let long = FixedArray::makei(65539, index => {
    if index % 2 == 0 {
      b'a'
    } else {
      b'b'
    }
  }).unsafe_reinterpret_as_bytes()
  let output = @io.MemoryReader(writer => {
    let input = @io.MemoryReader(source => {
      source.write("abc\n")
      source.write(long)
      source.write("\n123")
    })
    defer input.close()
    let count = Ref(0L)
    reverse_reader(input, count, writer~)
    assert_eq(count.val, 3L)
  })
  defer output.close()
  assert_eq(output.read_exactly(4), b"cba\n")
  assert_eq(output.read_exactly(long.length()), reverse_line(long))
  assert_eq(output.read_all().binary(), b"\n321")
}

///|
test "rev is byte oriented for invalid UTF-8" {
  assert_eq(reverse_line(b"a\xc3\xa9"), b"\xa9\xc3a")
}

///|
async test "rev rejects invalid C records before output and continues later readers" {
  let observations : Array[(Int64, Bool)] = []
  let output = @io.MemoryReader(writer => {
    for data in [b"ok\nab\xffcd\nignored\n", b"bad\x80", b"tail\x00"] {
      let reader = @io.MemoryReader(input => input.write(data))
      defer reader.close()
      let count = Ref(0L)
      let rejected = try {
        reverse_reader(reader, count, writer~)
        false
      } catch {
        InvalidCRecord as error => {
          assert_eq(
            error_message(error),
            "Invalid or incomplete multibyte or wide character",
          )
          true
        }
        error => raise error
      }
      observations.push((count.val, rejected))
    }
  })
  defer output.close()
  assert_eq(output.read_all().binary(), b"ko\n\x00liat")
  assert_eq(observations, [(1L, true), (0L, true), (1L, false)])
}

///|
priv suberror RevTestFailure

///|
priv struct RevTestWriter {
  bytes : Array[Byte]
  mut remaining : Int32?
  mut calls : Int32
}

///|
impl @io.Writer for RevTestWriter with fn write_once(self, data, offset~, len~) {
  self.calls += 1
  let count = match self.remaining {
    None => len
    Some(0) => raise RevTestFailure
    Some(remaining) => {
      let count = remaining.min(len)
      self.remaining = Some(remaining - count)
      count
    }
  }
  for byte in data[offset:offset + count] {
    self.bytes.push(byte)
  }
  count
}

///|
async test "rev flushes complete records after a producer read failure" {
  let reader = @io.MemoryReader(writer => {
    writer.write("kept\npartial")
    @async.sleep(1)
    raise RevTestFailure
  })
  defer reader.close()
  let output : RevTestWriter = { bytes: [], remaining: None, calls: 0, }
  let count = Ref(0L)
  try reverse_reader(reader, count, writer=output) catch {
    RevTestFailure => ()
    error => raise error
  } noraise {
    _ => fail("expected read failure")
  }
  assert_eq(count.val, 1L)
  assert_eq(Bytes::from_array(output.bytes), b"tpek\n")
  assert_eq(output.calls, 1)
}

///|
async test "rev never replays a partially failed buffered output" {
  for
    (input, expected) in [
      (b"abcdef\n", b"fe"),
      (FixedArray::make(65537, b'x').unsafe_reinterpret_as_bytes(), b"xx"),
    ] {
    let reader = @io.MemoryReader(writer => writer.write(input))
    defer reader.close()
    let output : RevTestWriter = { bytes: [], remaining: Some(2), calls: 0, }
    try reverse_reader(reader, Ref(0L), writer=output) catch {
      RevTestFailure => ()
      error => raise error
    } noraise {
      _ => fail("expected output failure")
    }
    assert_eq(Bytes::from_array(output.bytes), expected)
    assert_eq(output.calls, 2)
  }
}
