///|
test "base32 fragmented quanta preserve padding and wrap columns" {
  for
    (input, raw) in [
      (b"", b""),
      (b"f", b"MY======"),
      (b"fo", b"MZXQ===="),
      (b"foo", b"MZXW6==="),
      (b"foob", b"MZXW6YQ="),
      (b"fooba", b"MZXW6YTB"),
      (b"foobar", b"MZXW6YTBOI======"),
    ] {
    for size in [1, 2, 3, 4, 5, 6, 7] {
      for wrap in [0, 1, 3, 7, 8, 9, 76, 2147483647] {
        let encoder = Base32Encoder::new(wrap)
        let output = @buffer.Buffer()
        for at = 0; at < input.length(); at = at + size {
          output.write_bytes(
            encoder.encode(input[at:(at + size).min(input.length())]),
          )
          assert_eq(encoder.encode(b""[:]), b"")
          assert_true(encoder.count < 5)
        }
        output.write_bytes(encoder.finish())
        assert_eq(encoder.finish(), b"")
        let expected = @buffer.Buffer()
        for i, byte in raw {
          expected.write_byte(byte)
          if wrap > 0 && ((i + 1) % wrap == 0 || i + 1 == raw.length()) {
            expected.write_byte(b'\n')
          }
        }
        assert_eq(output.to_bytes(), expected.to_bytes())
      }
    }
  }
}

///|
priv struct Base32Output {
  bytes : Array[Byte]
  mut calls : Int32
  fail_after : Int32
  acknowledged : @async.Queue[Unit]?
}

///|
impl @io.Writer for Base32Output with fn write_once(self, bytes, offset~, len~) {
  self.calls += 1
  guard self.calls <= self.fail_after else { fail("base32 output failed") }
  let count = len.min(3)
  for i in offset..<(offset + count) {
    self.bytes.push(bytes[i])
  }
  if self.bytes.length() == 8 && self.acknowledged is Some(queue) {
    queue.put(())
  }
  count
}

///|
async test "base32 emits a complete quantum while input remains open" {
  @async.with_timeout(5000, () => {
    let acknowledged : @async.Queue[Unit] = @async.Queue(kind=Blocking(1))
    let reader = @io.MemoryReader(writer => {
      writer.write(b"foobar")
      acknowledged.get()
    })
    defer reader.close()
    let output : Base32Output = {
      bytes: [],
      calls: 0,
      fail_after: 100,
      acknowledged: Some(acknowledged),
    }
    encode_stream(reader, 0, output)
    assert_eq(Bytes::from_array(output.bytes), b"MZXW6YTBOI======")
  })
}

///|
async test "base32 read and write failures preserve only completed output" {
  let reader = @io.MemoryReader(writer => {
    writer.write(b"foobar")
    fail("base32 late read failure")
  })
  defer reader.close()
  let output : Base32Output = {
    bytes: [],
    calls: 0,
    fail_after: 100,
    acknowledged: None,
  }
  assert_true(
    try {
      encode_stream(reader, 76, output)
      false
    } catch {
      error => error.to_string().contains("late read failure")
    },
  )
  assert_eq(Bytes::from_array(output.bytes), b"MZXW6YTB")
  let reader2 = @io.MemoryReader(writer => writer.write(b"foobar"))
  defer reader2.close()
  let failed : Base32Output = {
    bytes: [],
    calls: 0,
    fail_after: 1,
    acknowledged: None,
  }
  assert_true(
    try {
      encode_stream(reader2, 0, failed)
      false
    } catch {
      error => error.to_string().contains("output failed")
    },
  )
  assert_eq(Bytes::from_array(failed.bytes), b"MZX")
  assert_eq(failed.calls, 2)
}

///|
async test "base32 streams across read windows without intermediate padding" {
  let input = Bytes::makei(65540, i => b"fooba"[i % 5]) + b"r"
  let reader = @io.MemoryReader(writer => writer.write(input))
  defer reader.close()
  let encoded = @io.MemoryReader(writer => encode_stream(reader, 0, writer))
  defer encoded.close()
  assert_eq(
    encoded.read_all().binary(),
    b"MZXW6YTB".repeat(13108) + b"OI======",
  )
}
