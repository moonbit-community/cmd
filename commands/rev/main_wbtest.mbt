///|
fn reverse_line(data : Bytes) -> Bytes {
  FixedArray::makei(data.length(), index => data[data.length() - index - 1]).unsafe_reinterpret_as_bytes()
}

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

///|
async test "rev retains buffered record counts at exact and straddled write boundaries" {
  for
    (width, expected_count) in [
      (1, 65536L),
      (2, 32768L),
      (79, 829L),
      (65536, 1L),
      (65537, 0L),
    ] {
    let data = Bytes::makei(131074, index => {
      if index % width == width - 1 {
        b'\n'
      } else {
        b'x'
      }
    })
    let reader = @io.MemoryReader(writer => writer.write(data))
    defer reader.close()
    let output : RevTestWriter = { bytes: [], remaining: Some(17), calls: 0, }
    let count = Ref(0L)
    try reverse_reader(reader, count, writer=output) catch {
      RevTestFailure => ()
      error => raise error
    } noraise {
      _ => fail("expected write failure")
    }
    assert_eq(count.val, expected_count)
    assert_eq(output.bytes.length(), 17)
    assert_eq(output.calls, 2)
  }
}

///|
async test "rev rejects late invalid bytes without leaking any of the rejected record" {
  for length in [65535, 65536, 1048577] {
    let input = b"ok\n\n" + Bytes::make(length, b'a') + b"\x80\nignored\n"
    let reader = @io.MemoryReader(writer => writer.write(input))
    defer reader.close()
    let output : RevTestWriter = { bytes: [], remaining: None, calls: 0, }
    let count = Ref(0L)
    try reverse_reader(reader, count, writer=output) catch {
      InvalidCRecord => ()
      error => raise error
    } noraise {
      _ => fail("expected invalid record")
    }
    assert_eq(count.val, 2L)
    assert_eq(Bytes::from_array(output.bytes), b"ko\n\n")
  }
}

///|
async test "rev wide copies preserve unaligned records tails and ASCII control bytes" {
  let bytes = @buffer.Buffer()
  let expected = @buffer.Buffer()
  for length in 0..<130 {
    let line = Bytes::makei(length, index => {
      ((index * 13 + length) % 117 + 11).to_byte()
    })
    bytes.write_bytes(line)
    bytes.write_byte(b'\n')
    expected.write_bytes(reverse_line(line))
    expected.write_byte(b'\n')
  }
  bytes.write_bytes(b"tail\x00\r")
  expected.write_bytes(b"\r\x00liat")
  let input = @io.MemoryReader(writer => writer.write(bytes.to_bytes()))
  defer input.close()
  let output : RevTestWriter = { bytes: [], remaining: None, calls: 0, }
  let count = Ref(0L)
  reverse_reader(input, count, writer=output)
  assert_eq(count.val, 131L)
  assert_eq(Bytes::from_array(output.bytes), expected.to_bytes())
  for offset in 0..<16 {
    for length in 0..<32 {
      let storage = b"\xff" + Bytes::make(offset + length, b'a') + b"\xff"
      assert_true(!invalid_c_record(storage[1 + offset:1 + offset + length]))
      for bad in 0..<length {
        let source = Bytes::makei(length, index => {
          if index == bad {
            b'\x80'
          } else {
            b'a'
          }
        })
        assert_true(invalid_c_record(source))
      }
    }
  }
}
