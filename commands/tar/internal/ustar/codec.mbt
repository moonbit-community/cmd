///|
const BLOCK : Int32 = 512

///|
fn text(header : BytesView, start : Int32, width : Int32) -> String raise {
  let field = header[start:start + width]
  let end = field.find(b"\x00").unwrap_or(width)
  @utf8.decode(field[:end], ignore_bom=false)
}

///|
fn number(field : BytesView) -> Int64 raise {
  let mut result = 0L
  let mut ended = false
  let mut digits = false
  for byte in field {
    match byte {
      b'0'..<=b'7' if !ended => {
        guard result <= 0x0fff_ffff_ffff_ffffL else {
          raise @archivefs.ArchiveError("ustar numeric overflow")
        }
        result = result * 8L + (byte.to_int() - 48).to_int64()
        digits = true
      }
      b' ' => if digits { ended = true }
      b'\x00' => ended = true
      _ => raise @archivefs.ArchiveError("invalid ustar octal field")
    }
  }
  guard digits else { raise @archivefs.ArchiveError("missing ustar number") }
  result
}

///|
fn checksum(header : BytesView) -> Int32 {
  let mut sum = 0
  for i in 0..<BLOCK {
    sum += if i >= 148 && i < 156 { 32 } else { header[i].to_int() }
  }
  sum
}

///|
pub fn read(bytes : BytesView) -> Array[@archivefs.Member] raise {
  let entries = []
  let mut offset = 0
  while bytes.length() - offset >= BLOCK {
    let header = bytes[offset:offset + BLOCK]
    offset += BLOCK
    if header.iter().all(b => b == 0) {
      guard bytes.length() - offset >= BLOCK &&
        bytes[offset:].iter().all(b => b == 0) else {
        raise @archivefs.ArchiveError("invalid end of ustar archive")
      }
      return entries
    }
    guard number(header[148:156]) == checksum(header).to_int64() else {
      raise @archivefs.ArchiveError("ustar header checksum mismatch")
    }
    guard header[257:262] == b"ustar" else {
      raise @archivefs.ArchiveError("unsupported tar format")
    }
    let suffix = text(header, 0, 100)
    let prefix = if header[262] == 0 { text(header, 345, 155) } else { "" }
    let name = if prefix == "" { suffix } else { prefix + "/" + suffix }
    let size = number(header[124:136])
    guard size <= (bytes.length() - offset).to_int64() else {
      raise @archivefs.ArchiveError("truncated ustar entry: " + name)
    }
    let length = size.to_int()
    let padding = (BLOCK - length % BLOCK) % BLOCK
    guard padding <= bytes.length() - offset - length else {
      raise @archivefs.ArchiveError("truncated ustar padding")
    }
    let content : @archivefs.Content = match header[156] {
      b'0' | b'\x00' => Regular(bytes[offset:offset + length])
      b'5' if length == 0 => Directory
      b'1' | b'2' | b'3' | b'4' | b'6' if length == 0 => Special
      _ => raise @archivefs.ArchiveError("unsupported ustar header: " + name)
    }
    guard entries.length() < @archivefs.MAX_ENTRIES else {
      raise @archivefs.ArchiveError("too many archive members")
    }
    entries.push({ name, content, })
    offset += length + padding
  }
  raise @archivefs.ArchiveError("missing end of ustar archive")
}

///|
fn put(header : FixedArray[Byte], start : Int32, value : BytesView) -> Unit {
  for i in 0..<value.length() {
    header[start + i] = value[i]
  }
}

///|
fn octal(
  header : FixedArray[Byte],
  start : Int32,
  width : Int32,
  value : Int32,
) -> Unit {
  for i = width - 1, n = value; i >= 0; i = i - 1, n = n / 8 {
    header[start + i] = (48 + n % 8).to_byte()
  }
}

///|
fn put_name(header : FixedArray[Byte], name : String) -> Unit raise {
  let encoded = @utf8.encode(name)
  if encoded.length() <= 100 {
    put(header, 0, encoded)
    return
  }
  for i in 1..<encoded.length() {
    if encoded[i] == b'/' &&
      i <= 155 &&
      i + 1 < encoded.length() &&
      encoded.length() - i - 1 <= 100 {
      put(header, 345, encoded[:i])
      put(header, 0, encoded[i + 1:])
      return
    }
  }
  raise @archivefs.ArchiveError("name exceeds ustar fields: " + name)
}

///|
pub fn write(entries : ArrayView[@archivefs.Member]) -> Bytes raise {
  let output = @buffer.Buffer()
  let zeros = Bytes::make(BLOCK, 0)
  for entry in entries {
    let header = FixedArray::make(BLOCK, b'\x00')
    put_name(header, entry.name)
    let payload : BytesView = match entry.content {
      Regular(bytes) => bytes
      Directory => b""
      Special =>
        raise @archivefs.ArchiveError(
          "unsupported archive member: " + entry.name,
        )
    }
    let padding = (BLOCK - payload.length() % BLOCK) % BLOCK
    guard @archivefs.MAX_BYTES - output.length() >=
      payload.length() + padding + 3 * BLOCK else {
      raise @archivefs.ArchiveError("archive size limit exceeded")
    }
    octal(
      header,
      100,
      7,
      if entry.content is Directory {
        0o755
      } else {
        0o644
      },
    )
    octal(header, 108, 7, 0)
    octal(header, 116, 7, 0)
    octal(header, 124, 11, payload.length())
    octal(header, 136, 11, 0)
    header[156] = if entry.content is Directory { b'5' } else { b'0' }
    put(header, 257, b"ustar\x0000")
    octal(header, 148, 6, checksum(Bytes::from_array(header)))
    header[155] = b' '
    output.write_bytesview(Bytes::from_array(header))
    output.write_bytesview(payload)
    output.write_bytesview(zeros[:padding])
  }
  output.write_bytesview(zeros)
  output.write_bytesview(zeros)
  output.to_bytes()
}
