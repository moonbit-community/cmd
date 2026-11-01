///|
priv struct JoinSink {
  bytes : Array[Byte]
  mut calls : Int32
  fail_after : Int32
}

///|
impl @io.Writer for JoinSink with fn write_once(self, data, offset~, len~) {
  self.calls += 1
  guard self.calls <= self.fail_after else { fail("join sink failure") }
  let count = if self.fail_after < 100 { len.min(3) } else { len }
  for i in offset..<(offset + count) {
    self.bytes.push(data[i])
  }
  count
}

///|
async test "join buffered output flushes before the next external read" {
  let sink : JoinSink = { bytes: [], calls: 0, fail_after: 100, }
  let left = @io.MemoryReader(writer => {
    writer.write("a L1\nb L2\n")
    writer.write("c L3\n")
    assert_eq(Bytes::from_array(sink.bytes), b"a L1 R1\n")
  })
  defer left.close()
  let right = @io.MemoryReader(writer => writer.write("a R1\nb R2\nc R3\n"))
  defer right.close()
  merge_readers(
    left,
    right,
    1,
    1,
    None,
    [],
    [],
    "",
    [],
    b'\n',
    0,
    false,
    false,
    false,
    "left",
    "right",
    writer=sink,
  )
  assert_eq(Bytes::from_array(sink.bytes), b"a L1 R1\nb L2 R2\nc L3 R3\n")
}

///|
async test "join output retains duplicate products and never replays a failed write" {
  let sink : JoinSink = { bytes: [], calls: 0, fail_after: 100, }
  let left = @io.MemoryReader(writer => writer.write("a L1\na L2\nz end"))
  defer left.close()
  let right = @io.MemoryReader(writer => writer.write("a R1\na R2\nz last"))
  defer right.close()
  merge_readers(
    left,
    right,
    1,
    1,
    None,
    [],
    [],
    "",
    [],
    b'\n',
    0,
    false,
    false,
    false,
    "left",
    "right",
    writer=sink,
  )
  assert_eq(
    Bytes::from_array(sink.bytes),
    b"a L1 R1\na L1 R2\na L2 R1\na L2 R2\nz end last\n",
  )
  let failed : JoinSink = { bytes: [], calls: 0, fail_after: 1, }
  let output = @stream.BlockWriter::new(failed)
  write_joined(
    output,
    Some({ fields: [b"a", b"left"], }),
    Some({ fields: [b"a", b"right"], }),
    1,
    1,
    b' ',
    "",
    [],
    None,
    b'\n',
  )
  assert_true(
    try {
      output.flush()
      false
    } catch {
      _ => true
    },
  )
  output.flush()
  assert_eq(Bytes::from_array(failed.bytes), b"a l")
  assert_eq(failed.calls, 2)
}
