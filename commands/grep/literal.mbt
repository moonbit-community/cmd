///|
fn folded_bytes(bytes : BytesView) -> Bytes {
  Bytes::makei(bytes.length(), index => {
    let byte = bytes[index]
    if byte >= b'A' && byte <= b'Z' {
      (byte.to_int() + 32).to_byte()
    } else {
      byte
    }
  })
}

///|
fn byte_word(byte : Byte) -> Bool {
  byte == b'_' || byte is (b'a'..<=b'z' | b'A'..<=b'Z' | b'0'..<=b'9')
}

///|
fn fixed_span(
  patterns : Array[Bytes],
  line : BytesView,
  position : Int32,
  whole : Bool,
  word : Bool,
) -> (Int32, Int32)? {
  if position > line.length() {
    return None
  }
  let mut best = None
  for pattern in patterns {
    if whole {
      if position == 0 && line == pattern[:] {
        return Some((0, line.length()))
      }
      continue
    }
    let mut search = position
    while search <= line.length() {
      guard line[search:].find(pattern[:]) is Some(relative) else { break }
      let start = search + relative
      let end = start + pattern.length()
      if !word ||
        (
          (start == 0 || !byte_word(line[start - 1])) &&
          (end == line.length() || !byte_word(line[end]))
        ) {
        match best {
          Some((old_start, old_end)) =>
            if start < old_start || (start == old_start && end > old_end) {
              best = Some((start, end))
            }
          None => best = Some((start, end))
        }
        break
      }
      search = start + 1
    }
  }
  best
}
