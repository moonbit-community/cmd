///|
fn byte_feed(data : Bytes, chunk : Int32) -> @io.MemoryReader {
  @io.MemoryReader(
    // Public in-memory pipe writes rendezvous with reads, so a read cannot
    // combine these independently completed chunks into a larger transfer.
    writer => {
      for offset = 0; offset < data.length(); offset = offset + chunk {
        writer.write(data[offset:(offset + chunk).min(data.length())])
      }
    },
  )
}

///|
async test "gzip Reader handles byte feeds through optional headers and members" {
  let header = b"\x1f\x8b\x08\x1f\x00\x00\x00\x00\x00\xff\x03\x00abcname\x00comment\x00"
  let crc = crc32(header[:])
  let gzip_member = header +
    Bytes::from_array([crc.to_byte(), (crc >> 8).to_byte()]) +
    abc[10:].to_owned()
  for chunk in [1, 2, 7] {
    let input = byte_feed(gzip_member + abc + b"\x00\x00", chunk)
    defer input.close()
    let output : Collected = { bytes: [], }
    assert_true(!decode_reader(input, output, false))
    assert_eq(Bytes::from_array(output.bytes), b"abcabc")
  }
  let input = byte_feed(abc, 1)
  defer input.close()
  let buffer = FixedArray::make(64, b'\x00')
  for _ in 0..<abc.length() {
    assert_eq(input.read(buffer), 1)
  }
  assert_eq(input.read(buffer), 0)
  let long_header = b"\x1f\x8b\x08\x0a\x00\x00\x00\x00\x00\xff" +
    Bytes::make(70000, b'n') +
    b"\x00"
  let crc = crc32(long_header[:])
  let long_input = cursor(
    long_header +
    Bytes::from_array([crc.to_byte(), (crc >> 8).to_byte()]) +
    abc[10:].to_owned(),
  )
  defer long_input.close()
  let output : Collected = { bytes: [], }
  assert_true(!decode_reader(long_input, output, false))
  assert_eq(Bytes::from_array(output.bytes), b"abc")
}

///|
async test "gzip Reader preserves prefixes for every fixed-member truncation" {
  for length in 0..<abc.length() {
    let input = byte_feed(abc[:length].to_owned(), 1)
    defer input.close()
    let output : Collected = { bytes: [], }
    try decode_reader(input, output, false) catch {
      _ => ()
    } noraise {
      _ => fail("must reject truncation at \{length}")
    }
    let expected = if length <= 11 {
      b""
    } else if length == 12 {
      b"a"
    } else if length == 13 {
      b"ab"
    } else {
      b"abc"
    }
    assert_eq(Bytes::from_array(output.bytes), expected)
  }
}

///|
async test "gzip Reader retains prefetched trailer bytes and stored block bytes" {
  let payload = Bytes::makei(131075, index => (index % 251).to_byte())
  let raw = DeflateBits::new()
  raw.stored(payload[:], finish=true)
  let input = cursor(raw.drain())
  defer input.close()
  let bits = Bits::new(input)
  let output : Collected = { bytes: [], }
  let (checksum, size) = inflate(bits, output, false)
  assert_eq(checksum, crc32(payload[:]))
  assert_eq(size, payload.length().reinterpret_as_uint())
  assert_eq(Bytes::from_array(output.bytes), payload)
  assert_true(bits.next_byte() is None)
  let members = cursor(abc + abc)
  defer members.close()
  let decoded : Collected = { bytes: [], }
  assert_true(!decode_reader(members, decoded, false))
  assert_eq(Bytes::from_array(decoded.bytes), b"abcabc")
}

///|
async test "gzip Reader rejects reserved blocks stored lengths and absent history" {
  // Independent raw vectors: BTYPE=3; stored LEN/NLEN mismatch; fixed length
  // three at distance one before any literal has established output history.
  for raw in [b"\x07", b"\x01\x01\x00\xff\xffx", b"\x03\x02"] {
    let input = byte_feed(raw, 1)
    defer input.close()
    let output : Collected = { bytes: [], }
    try inflate(Bits::new(input), output, false) catch {
      _ => ()
    } noraise {
      _ => fail("must reject corrupt raw DEFLATE")
    }
    assert_eq(output.bytes.length(), 0)
  }
}

///|
test "gzip Huffman tables match canonical codes including secondary entries" {
  let lengths = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 15]
  let tree = huffman(lengths, main_bits=9)
  let unused = cursor(b"")
  defer unused.close()
  for key, symbol in tree.codes {
    let length = key >> 16
    let code = key & 0xffff
    let bits = Bits::new(unused)
    bits.pending = code.reinterpret_as_uint()
    bits.available = length
    assert_eq(tree.buffered(bits), Some(symbol))
    assert_eq(bits.available, 0)
  }
  let single = huffman([1])
  let bits = Bits::new(unused)
  bits.pending = 1U
  bits.available = 1
  try single.buffered(bits) catch {
    _ => ()
  } noraise {
    _ => fail("must reject an unassigned code")
  }
  for lengths in [[1, 1, 1], [2, 2], [16]] {
    try huffman(lengths) catch {
      _ => ()
    } noraise {
      _ => fail("must reject invalid tree")
    }
  }
}

///|
priv struct LimitedWriter {
  bytes : Array[Byte]
  mut remaining : Int32
  mut calls : Int32
}

///|
impl @io.Writer for LimitedWriter with fn write_once(self, data, offset~, len~) {
  self.calls += 1
  guard self.remaining > 0 else { fail("fixture writer failure") }
  let count = len.min(self.remaining)
  for index in offset..<(offset + count) {
    self.bytes.push(data[index])
  }
  self.remaining -= count
  count
}

///|
async test "gzip Reader preserves read errors and never retries a failed writer" {
  let input = @io.MemoryReader(writer => {
    writer.write(abc[:15])
    @async.sleep(5)
    fail("fixture reader failure")
  })
  defer input.close()
  let output : Collected = { bytes: [], }
  try decode_reader(input, output, false) catch {
    error => assert_true(error.to_string().contains("fixture reader failure"))
  } noraise {
    _ => fail("must propagate reader failure")
  }
  assert_eq(Bytes::from_array(output.bytes), b"abc")
  let encoded : Collected = { bytes: [], }
  let source = cursor(Bytes::make(100000, b'a'))
  defer source.close()
  encode(source, encoded)
  let compressed = cursor(Bytes::from_array(encoded.bytes))
  defer compressed.close()
  let limited : LimitedWriter = { bytes: [], remaining: 17, calls: 0, }
  try decode_reader(compressed, limited, false) catch {
    error => assert_true(error.to_string().contains("fixture writer failure"))
  } noraise {
    _ => fail("must propagate writer failure")
  }
  assert_eq(limited.calls, 2)
  assert_eq(Bytes::from_array(limited.bytes), Bytes::make(17, b'a'))
}
