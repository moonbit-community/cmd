///|
async test "record batches preserve bytes and view ownership across arbitrary fragments" {
  let input = b"\x00ab\x00\x00" + Bytes::make(131079, b'x') + b"\x00tail"
  for size in [1, 7, 16, 65535, 65536, 65537] {
    let reader = @io.MemoryReader(writer => {
      let mut offset = 0
      while offset < input.length() {
        let end = (offset + size).min(input.length())
        writer.write(input[offset:end])
        offset = end
      }
    })
    defer reader.close()
    let scanner = @stream.RecordReader::new(reader, delimiter=b'\x00')
    let records : Array[@stream.RecordView] = []
    while scanner.next_batch() is Some(batch) {
      while batch.next() is Some(record) {
        records.push(record)
      }
      assert_true(batch.next() is None)
    }
    assert_true(scanner.next_batch() is None)
    assert_eq(records.length(), 5)
    for index, expected in [b"", b"ab", b"", Bytes::make(131079, b'x'), b"tail"] {
      assert_eq(records[index].data.to_owned(), expected)
      assert_eq(records[index].terminated, index != 4)
    }
  }
}

///|
async test "a complete record is returned while the producer remains open" {
  let reader = @io.MemoryReader(writer => {
    writer.write(b"ready\npartial")
    @async.sleep(10000)
  })
  defer reader.close()
  let scanner = @stream.RecordReader::new(reader)
  let batch = @async.with_timeout(1000, () => scanner.next_batch()).unwrap()
  assert_eq(batch.next().unwrap().data.to_owned(), b"ready")
  assert_true(batch.next() is None)
}

///|
priv struct PartialWriter {
  bytes : Array[Byte]
  mut calls : Int32
}

///|
impl @io.Writer for PartialWriter with fn write_once(self, bytes, offset~, len~) {
  self.calls += 1
  if self.calls > 1 {
    fail("injected output failure")
  }
  let count = len.min(2)
  for index in offset..<(offset + count) {
    self.bytes.push(bytes[index])
  }
  count
}

///|
async test "flush consumes partial writes once even when cleanup runs" {
  let writer = PartialWriter::{ bytes: [], calls: 0, }
  let output = @buffer.Buffer()
  output.write_bytes(b"abcdef")
  let failed = try {
    defer @stream.flush_buffer(writer, output)
    @stream.flush_buffer(writer, output)
    false
  } catch {
    _ => true
  }
  assert_true(failed)
  assert_eq(writer.calls, 2)
  assert_eq(Bytes::from_array(writer.bytes), b"ab")
  assert_true(output.is_empty())
}

///|
async test "read failures do not turn an incomplete record into EOF" {
  let reader = @io.MemoryReader(writer => {
    writer.write(b"complete\nfragment")
    fail("injected input failure")
  })
  defer reader.close()
  let scanner = @stream.RecordReader::new(reader)
  assert_eq(
    scanner.next_batch().unwrap().next().unwrap().data.to_owned(),
    b"complete",
  )
  let failed = try {
    ignore(scanner.next_batch())
    false
  } catch {
    _ => true
  }
  assert_true(failed)
}
