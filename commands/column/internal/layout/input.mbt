///|
pub struct Separator {
  priv members : FixedArray[Bool]
  priv wide : Set[Char]
  priv profile : @textwidth.Profile
  priv preserve_empty : Bool
}

///|
pub fn Separator::new(
  separator : String?,
  profile~ : @textwidth.Profile = CBytes,
) -> Separator {
  let members = FixedArray::make(128, false)
  let wide = Set([])
  for char in separator.unwrap_or(" \t") {
    if char.to_int() < 128 {
      members[char.to_int()] = true
    } else {
      wide.insert(char)
    }
  }
  { members, wide, profile, preserve_empty: separator is Some(_), }
}

///|
// Grid and table layouts treat escape sequences differently.
pub fn display_width(
  field : String,
  table~ : Bool = false,
  profile~ : @textwidth.Profile = CBytes,
) -> Int32 {
  if profile == Utf8 {
    if table {
      return table_width(@utf8.encode(field)[:], profile)
    }
    let mut width = 0
    for c in field {
      width += @textwidth.cells(Some(c), fallback=0)
    }
    return width
  }
  let mut width = 0
  let mut i = 0
  while i < field.length() {
    let c = field[i]
    i += 1
    if c >= ' ' && c <= '~' {
      width += 1
    } else if table && i < field.length() && field[i] == '[' {
      // util-linux 2.40's table width skips control + '[' ... 'm'.
      // Its default grid uses the unfiltered printable-character count.
      let mut end = i + 1
      while end < field.length() && field[end] != 'm' {
        end += 1
      }
      if end < field.length() {
        i = end + 1
      }
    }
  }
  width
}

///|
pub fn input_line(
  data : BytesView,
  profile~ : @textwidth.Profile = CBytes,
) -> String? {
  let end = data.find(b"\x00").unwrap_or(data.length())
  let prefix = data[:end]
  if input_is_ascii(prefix) {
    if prefix
      .iter()
      .all(byte => byte is (b' ' | b'\t' | b'\r' | b'\n' | b'\x0b' | b'\x0c')) {
      return None
    }
    // Every byte is ASCII, so decoding cannot replace or combine input bytes.
    return Some(@utf8.decode_lossy(prefix))
  }
  let line = StringBuilder()
  if profile == Utf8 {
    try @utf8.decode(prefix) catch {
      @utf8.Malformed(_) => ()
    } noraise {
      valid => return Some(valid)
    }
  }
  for i = 0; i < prefix.length(); {
    let byte = prefix[i]
    let (ch, len) = profile.next(prefix, i)
    if ch is None || (profile == CBytes && byte >= 128) {
      let hex = "0123456789abcdef"
      line.write_string("\\x")
      line.write_char(hex[byte.to_int() / 16].to_char().unwrap())
      line.write_char(hex[byte.to_int() % 16].to_char().unwrap())
    } else if profile == Utf8 &&
      byte == b'\\' &&
      i + 1 < prefix.length() &&
      prefix[i + 1] == b'x' {
      line.write_string("\\x5c")
    } else {
      line.write_char(ch.unwrap())
    }
    continue i + len
  }
  let value = line.to_string()
  if value
    .iter()
    .all(c => c is (' ' | '\t' | '\r' | '\n' | '\u000b' | '\u000c')) {
    None
  } else {
    Some(value)
  }
}

///|
fn input_is_ascii(data : BytesView) -> Bool {
  let mut offset = 0
  while data.length() - offset >= 8 {
    if (data.unsafe_read_uint64_le(offset) & 0x8080808080808080UL) != 0UL {
      return false
    }
    offset += 8
  }
  for byte in data[offset:] {
    if byte >= 128 {
      return false
    }
  }
  true
}
