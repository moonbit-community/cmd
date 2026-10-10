///|
fn crc32(data : BytesView) -> UInt {
  let mut crc = 0xffffffffU
  for byte in data {
    crc = update_crc(crc, byte)
  }
  crc ^ 0xffffffffU
}

///|
fn header_end(data : Bytes, start : Int) -> Int raise {
  guard data.length() - start >= 10 else { fail("unexpected end of file") }
  guard data[start] == b'\x1f' && data[start + 1] == b'\x8b' else {
    fail("not in gzip format")
  }
  guard data[start + 2] == b'\x08' else {
    fail("unsupported compression method")
  }
  let flags = data[start + 3].to_int()
  guard (flags & 0xe0) == 0 else { fail("reserved gzip header flags") }
  let mut position = start + 10
  if (flags & 4) != 0 {
    guard data.length() - position >= 2 else { fail("unexpected end of file") }
    let size = data[position].to_int() + (data[position + 1].to_int() << 8)
    position += 2
    guard size <= data.length() - position else {
      fail("unexpected end of file")
    }
    position += size
  }
  for bit in [8, 16] {
    if (flags & bit) != 0 {
      while position < data.length() && data[position] != b'\x00' {
        position += 1
      }
      guard position < data.length() else { fail("unexpected end of file") }
      position += 1
    }
  }
  if (flags & 2) != 0 {
    guard data.length() - position >= 2 else { fail("unexpected end of file") }
    let expected = data[position].to_uint() |
      (data[position + 1].to_uint() << 8)
    guard (crc32(data[start:position]) & 0xffffU) == expected else {
      fail("header checksum mismatch")
    }
    position += 2
  }
  position
}

///|
/// Decode every gzip member, including optional RFC 1952 header fields.
/// Compressed input is buffered; decoded chunks reach the writer before a
/// later trailer/CRC error is reported. Returns true for trailing garbage.
pub async fn decode(
  data : Bytes,
  output : &@io.Writer,
  test_only : Bool,
) -> Bool {
  let mut offset = 0
  let mut members = 0
  while offset < data.length() {
    if members > 0 && data[offset] == b'\x00' {
      while offset < data.length() && data[offset] == b'\x00' {
        offset += 1
      }
      if offset == data.length() {
        return false
      }
      return true
    }
    if members > 0 && data[offset] != b'\x1f' {
      return true
    }
    if members > 0 && offset + 1 < data.length() && data[offset + 1] != b'\x8b' {
      return true
    }
    let body = header_end(data, offset)
    let (trailer, checksum, size) = inflate(data, body, output, test_only)
    guard data.length() - trailer >= 8 else { fail("unexpected end of file") }
    guard uint32_le(data, trailer) == checksum else {
      fail("invalid compressed data--crc error")
    }
    guard uint32_le(data, trailer + 4) == size else {
      fail("invalid compressed data--length error")
    }
    offset = trailer + 8
    members += 1
  }
  guard members > 0 else { fail("unexpected end of file") }
  false
}

///|
fn uint32_le(data : Bytes, position : Int) -> UInt {
  data[position].to_uint() |
  (data[position + 1].to_uint() << 8) |
  (data[position + 2].to_uint() << 16) |
  (data[position + 3].to_uint() << 24)
}

///|
async fn flush_pending(pending : Array[Byte], output : &@io.Writer) -> Unit {
  if !pending.is_empty() {
    let bytes = Bytes::from_array(pending)
    pending.clear()
    output.write(bytes)
  }
}

///|
pub async fn encode(input : &@io.Reader, output : &@io.Writer) -> Unit {
  let encoder = @gzip.Encoder(output)
  encoder.write_reader(input)
  encoder.end()
}
