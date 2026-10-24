///|
async fn gzip_header(bits : Bits, first : Byte, second : Byte) -> Unit {
  let header = FixedArray::make(10, b'\x00')
  header[0] = first
  header[1] = second
  for index in 2..<10 {
    header[index] = bits.take(8).to_byte()
  }
  guard first == b'\x1f' && second == b'\x8b' else {
    fail("not in gzip format")
  }
  guard header[2] == b'\x08' else { fail("unsupported compression method") }
  let flags = header[3].to_int()
  guard (flags & 0xe0) == 0 else { fail("reserved gzip header flags") }
  let mut crc = 0xffffffffU
  for byte in header {
    crc = update_crc(crc, byte)
  }
  if (flags & 4) != 0 {
    let low = bits.take(8).to_byte()
    let high = bits.take(8).to_byte()
    crc = update_crc(update_crc(crc, low), high)
    let size = low.to_int() | (high.to_int() << 8)
    for _ in 0..<size {
      crc = update_crc(crc, bits.take(8).to_byte())
    }
  }
  for bit in [8, 16] {
    if (flags & bit) != 0 {
      for ;; {
        let byte = bits.take(8).to_byte()
        crc = update_crc(crc, byte)
        if byte == b'\x00' {
          break
        }
      }
    }
  }
  if (flags & 2) != 0 {
    let low = bits.take(8).reinterpret_as_uint()
    let high = bits.take(8).reinterpret_as_uint()
    let expected = low | (high << 8)
    guard ((crc ^ 0xffffffffU) & 0xffffU) == expected else {
      fail("header checksum mismatch")
    }
  }
}

///|
/// Decode gzip bytes through the streaming codec. The caller retains `data`.
pub async fn decode(
  data : Bytes,
  output : &@io.Writer,
  test_only : Bool,
) -> Bool {
  let input = @io.MemoryReader(writer => writer.write(data))
  defer input.close()
  decode_reader(input, output, test_only)
}

///|
/// Decode concatenated gzip members with bounded input, history and output
/// buffers. Returns true for trailing garbage. A late format/read error keeps
/// the decoded prefix already written; `test_only` validates without output.
pub async fn decode_reader(
  input : &@io.Reader,
  output : &@io.Writer,
  test_only : Bool,
) -> Bool {
  let bits = Bits::new(input)
  let mut members = 0
  while bits.next_byte() is Some(first) {
    if members > 0 && first == b'\x00' {
      while bits.next_byte() is Some(byte) {
        if byte != b'\x00' {
          return true
        }
      }
      return false
    }
    if members > 0 && first != b'\x1f' {
      return true
    }
    guard bits.next_byte() is Some(second) else {
      fail("unexpected end of file")
    }
    if members > 0 && second != b'\x8b' {
      return true
    }
    gzip_header(bits, first, second)
    let (checksum, size) = inflate(bits, output, test_only)
    let expected_crc = bits.uint32_le()
    let expected_size = bits.uint32_le()
    guard expected_crc == checksum else {
      fail("invalid compressed data--crc error")
    }
    guard expected_size == size else {
      fail("invalid compressed data--length error")
    }
    members += 1
  }
  guard members > 0 else { fail("unexpected end of file") }
  false
}

///|
pub async fn encode(
  input : &@io.Reader,
  output : &@io.Writer,
  level~ : Int32 = 6,
) -> Unit {
  guard level >= 1 && level <= 9 else {
    fail("compression level must be between 1 and 9")
  }
  let extra = if level == 1 {
    b'\x04'
  } else if level == 9 {
    b'\x02'
  } else {
    b'\x00'
  }
  output.write(
    b"\x1f\x8b\x08\x00\x00\x00\x00\x00" + Bytes::from_array([extra, b'\xff']),
  )
  let encoder = DeflateEncoder::new(level)
  let buffer = FixedArray::make(65536, b'\x00')
  let mut count = 0
  let mut crc = 0xffffffffU
  let mut size = 0U
  for ;; {
    let received = input.read(
      buffer,
      offset=count,
      max_len=buffer.length() - count,
    )
    count += received
    if count == buffer.length() || received == 0 {
      let bytes = buffer.unsafe_reinterpret_as_bytes()[:count].to_owned()
      for byte in bytes {
        crc = update_crc(crc, byte)
      }
      size += count.reinterpret_as_uint()
      output.write(encoder.push(bytes, finish=received == 0))
      count = 0
    }
    if received == 0 {
      break
    }
  }
  let crc = crc ^ 0xffffffffU
  output.write(
    Bytes::from_array([
      crc.to_byte(),
      (crc >> 8).to_byte(),
      (crc >> 16).to_byte(),
      (crc >> 24).to_byte(),
      size.to_byte(),
      (size >> 8).to_byte(),
      (size >> 16).to_byte(),
      (size >> 24).to_byte(),
    ]),
  )
}
