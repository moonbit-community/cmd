///|
priv struct Collected {
  bytes : Array[Byte]
}

///|
impl @io.Writer for Collected with fn write_once(self, data, offset~, len~) {
  for index in offset..<(offset + len) {
    self.bytes.push(data[index])
  }
  len
}

///|
fn cursor(data : Bytes) -> @io.MemoryReader {
  @io.MemoryReader(writer => writer.write(data))
}

///|
fn crc32(data : BytesView) -> UInt32 {
  let mut crc = 0xffffffffU
  for byte in data {
    crc = update_crc(crc, byte)
  }
  crc ^ 0xffffffffU
}

///|
let abc = b"\x1f\x8b\x08\x00\x00\x00\x00\x00\x00\x03\x4b\x4c\x4a\x06\x00\xc2\x41\x24\x35\x03\x00\x00\x00"

///|
async test "gzip decodes fixed Huffman members and concatenation" {
  let output : Collected = { bytes: [], }
  assert_true(!decode(abc + abc, output, false))
  assert_eq(Bytes::from_array(output.bytes), b"abcabc")
  let verify : Collected = { bytes: [], }
  assert_true(!decode(abc, verify, true))
  assert_eq(verify.bytes.length(), 0)
}

///|
async test "gzip normalizes optional name extra comment text and header checksum" {
  let header = b"\x1f\x8b\x08\x1f\x00\x00\x00\x00\x00\x03\x02\x00abfile.txt\x00comment\x00"
  let crc = crc32(header[:])
  let input = header +
    Bytes::from_array([(crc & 0xffU).to_byte(), ((crc >> 8) & 0xffU).to_byte()]) +
    abc[10:].to_owned()
  let output : Collected = { bytes: [], }
  assert_true(!decode(input, output, false))
  assert_eq(Bytes::from_array(output.bytes), b"abc")
  let bad = header + b"\x00\x00" + abc[10:].to_owned()
  try decode(bad, output, false) catch {
    _ => ()
  } noraise {
    _ => fail("must reject bad header CRC")
  }
}

///|
async test "gzip keeps output prefix on CRC failure and distinguishes junk and zero padding" {
  let output : Collected = { bytes: [], }
  let corrupt = abc[:15].to_owned() + b"\x00\x00\x00\x00\x03\x00\x00\x00"
  try decode(corrupt, output, false) catch {
    _ => ()
  } noraise {
    _ => fail("must reject bad CRC")
  }
  assert_eq(Bytes::from_array(output.bytes), b"abc")
  let truncated : Collected = { bytes: [], }
  try decode(abc[:16].to_owned(), truncated, false) catch {
    _ => ()
  } noraise {
    _ => fail("must reject truncation")
  }
  assert_eq(Bytes::from_array(truncated.bytes), b"abc")
  let discard : Collected = { bytes: [], }
  assert_true(decode(abc + b"junk", discard, false))
  assert_true(!decode(abc + b"\x00\x00", discard, false))
  let padded : Collected = { bytes: [], }
  assert_true(decode(abc + b"\x00" + abc, padded, false))
  assert_eq(Bytes::from_array(padded.bytes), b"abc")
  assert_true(decode(abc + b"\x1f\x00", discard, false))
}

///|
async test "gzip encoder streams large byte payloads through public codec" {
  let payload = Bytes::makei(70003, i => (i % 251).to_byte())
  let encoded : Collected = { bytes: [], }
  let input = cursor(payload)
  defer input.close()
  encode(input, encoded)
  let decoded : Collected = { bytes: [], }
  assert_true(!decode(Bytes::from_array(encoded.bytes), decoded, false))
  assert_eq(Bytes::from_array(decoded.bytes), payload)
}

///|
async test "gzip dynamic Huffman backreferences overlap and wrap the 32 KiB window" {
  // Frozen zlib gzip member for 100,000 ASCII 'a' bytes. Its DEFLATE block is
  // dynamic and repeatedly copies from distance 1 across window boundaries.
  let gzip_member = b"\x1f\x8b\x08\x00\x00\x00\x00\x00\x02\xff\xed\xc1\x31\x01\x00\x00\x00\xc2\xa0\xac\xeb\x5f\xc2\x1a\x1e\x40\x01" +
    Bytes::make(96, b'\x00') +
    b"\xaf\x06\x87\xfa\xe2\x1b\xa0\x86\x01\x00"
  let output : Collected = { bytes: [], }
  assert_true(!decode(gzip_member, output, false))
  assert_eq(Bytes::from_array(output.bytes), Bytes::make(100000, b'a'))
  let verify : Collected = { bytes: [], }
  assert_true(!decode(gzip_member, verify, true))
  assert_eq(verify.bytes.length(), 0)
}
