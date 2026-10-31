///|
priv struct NumberOutput {
  bytes : Array[Byte]
}

///|
impl @io.Writer for NumberOutput with fn write_once(self, bytes, offset~, len~) {
  for i in offset..<(offset + len) {
    self.bytes.push(bytes[i])
  }
  len
}

///|
async fn number_for_test(reader : &@io.Reader, writer : &@io.Writer) -> Unit {
  process_reader(
    reader,
    "a",
    "a",
    "a",
    1,
    ":",
    Ref(1),
    1,
    1,
    "rn",
    1,
    false,
    "\\:",
    Ref(1),
    Ref(0),
    writer~,
  )
}

///|
async test "numbering preserves sections binary bytes and an unterminated final record" {
  let reader = @io.MemoryReader(writer => {
    writer.write(b"a\n\n\\:\\:\n\xff\x00tail")
  })
  defer reader.close()
  let output : NumberOutput = { bytes: [], }
  number_for_test(reader, output)
  assert_eq(Bytes::from_array(output.bytes), b"1:a\n2:\n\n1:\xff\x00tail\n")
}

///|
async test "numbering retains completed output before an input failure" {
  let reader = @io.MemoryReader(writer => {
    writer.write(b"one\nfragment")
    fail("injected read failure")
  })
  defer reader.close()
  let output : NumberOutput = { bytes: [], }
  let failed = try {
    number_for_test(reader, output)
    false
  } catch {
    _ => true
  }
  assert_true(failed)
  assert_eq(Bytes::from_array(output.bytes), b"1:one\n")
}

///|
priv struct PartialNumberOutput {
  bytes : Array[Byte]
  mut calls : Int32
}

///|
impl @io.Writer for PartialNumberOutput with fn write_once(
  self,
  bytes,
  offset~,
  len~,
) {
  self.calls += 1
  if self.calls > 1 {
    fail("injected write failure")
  }
  let length = len.min(2)
  for i in offset..<(offset + length) {
    self.bytes.push(bytes[i])
  }
  length
}

///|
async test "numbering never replays bytes after a partial write failure" {
  let reader = @io.MemoryReader(writer => writer.write(b"one\ntwo\n"))
  defer reader.close()
  let output : PartialNumberOutput = { bytes: [], calls: 0, }
  assert_true(
    try {
      number_for_test(reader, output)
      false
    } catch {
      _ => true
    },
  )
  assert_eq(Bytes::from_array(output.bytes), b"1:")
  assert_eq(output.calls, 2)
}

///|
async test "numbering batches preserve blank grouping section resets and signed formatting" {
  let reader = @io.MemoryReader(writer => {
    writer.write(b"a\n\n")
    writer.write(b"\n\\:\\:\\:\nh\n\\:\nf\n\\:\\:\nb")
  })
  defer reader.close()
  let output : NumberOutput = { bytes: [], }
  let number = Ref(-2)
  process_reader(
    reader,
    "a",
    "a",
    "n",
    3,
    "|",
    number,
    -2,
    1,
    "rz",
    2,
    false,
    "\\:",
    Ref(1),
    Ref(0),
    writer=output,
  )
  assert_eq(
    Bytes::from_array(output.bytes),
    b"-02|a\n    \n-01|\n\n-02|h\n\n    f\n\n-02|b\n",
  )
  assert_eq(number.val, -1)
}

///|
async test "numbering does not advance a declined oversized record after write failure" {
  let reader = @io.MemoryReader(writer => writer.write(Bytes::make(65537, b'x')))
  defer reader.close()
  let output : PartialNumberOutput = { bytes: [], calls: 0, }
  let number = Ref(10)
  assert_true(
    try {
      process_reader(
        reader,
        "a",
        "a",
        "a",
        1,
        ":",
        number,
        10,
        1,
        "rn",
        1,
        false,
        "",
        Ref(1),
        Ref(0),
        writer=output,
      )
      false
    } catch {
      _ => true
    },
  )
  assert_eq(Bytes::from_array(output.bytes), b"10")
  assert_eq(output.calls, 2)
  assert_eq(number.val, 10)
}

///|
async test "numbering empty input does not allocate a requested number field" {
  let reader = @io.MemoryReader(_ => ())
  defer reader.close()
  let output : NumberOutput = { bytes: [], }
  process_reader(
    reader,
    "a",
    "a",
    "a",
    2147483647,
    "",
    Ref(1),
    1,
    1,
    "rn",
    1,
    false,
    "",
    Ref(1),
    Ref(0),
    writer=output,
  )
  assert_eq(Bytes::from_array(output.bytes), b"")
}
