// Lossless conversion between OS strings (arbitrary bytes, such as Unix
// file names) and MoonBit `String`s.
//
// Valid UTF-8 is decoded normally. Each byte of an invalid UTF-8 sequence is
// mapped to the lone surrogate `U+DC00 + byte` (the "surrogateescape" scheme
// used by Python). Since valid UTF-8 never decodes to a surrogate, `encode`
// recovers the original bytes exactly.

///|
/// Decodes OS bytes into a string, escaping invalid UTF-8 bytes.
pub fn decode(b : BytesView) -> String {
  let sb = StringBuilder(size_hint=b.length())
  let n = b.length()
  let mut i = 0
  while i < n {
    let c = b[i].to_int()
    let (len, min) = if c < 0x80 {
      (1, 0)
    } else if c >= 0xC2 && c <= 0xDF {
      (2, 0x80)
    } else if c >= 0xE0 && c <= 0xEF {
      (3, 0x800)
    } else if c >= 0xF0 && c <= 0xF4 {
      (4, 0x10000)
    } else {
      (0, 0)
    }
    let cp = decode_at(b, i, len, min)
    if cp >= 0 {
      sb.write_char(cp.unsafe_to_char())
      i += len
    } else {
      sb.write_char((0xDC00 + c).unsafe_to_char())
      i += 1
    }
  }
  sb.to_string()
}

///|
/// Decodes the `len`-byte sequence at `i`, returning `-1` if it is invalid
/// (truncated, overlong, a surrogate or above U+10FFFF).
fn decode_at(b : BytesView, i : Int32, len : Int32, min : Int32) -> Int32 {
  if len == 0 || i + len > b.length() {
    return -1
  }
  if len == 1 {
    return b[i].to_int()
  }
  let mut cp = b[i].to_int() & (0x7F >> len)
  for j in 1..<len {
    let c = b[i + j].to_int()
    if (c & 0xC0) != 0x80 {
      return -1
    }
    cp = (cp << 6) | (c & 0x3F)
  }
  if cp < min || cp > 0x10FFFF || (cp >= 0xD800 && cp <= 0xDFFF) {
    -1
  } else {
    cp
  }
}

///|
/// Encodes a string back into OS bytes: escaped bytes are restored, and
/// everything else is encoded as UTF-8 (other lone surrogates become
/// U+FFFD).
pub fn encode(s : String) -> Bytes {
  let buf = Buffer(size_hint=s.length())
  let n = s.length()
  let mut i = 0
  while i < n {
    let u = s.code_unit_at(i).to_int()
    let mut cp = u
    if u >= 0xD800 && u <= 0xDBFF && i + 1 < n {
      let lo = s.code_unit_at(i + 1).to_int()
      if lo >= 0xDC00 && lo <= 0xDFFF {
        cp = 0x10000 + ((u - 0xD800) << 10) + (lo - 0xDC00)
        i += 1
      }
    }
    i += 1
    if cp >= 0xDC80 && cp <= 0xDCFF {
      buf.write_byte((cp - 0xDC00).to_byte())
    } else if cp >= 0xD800 && cp <= 0xDFFF {
      write_utf8(buf, 0xFFFD)
    } else {
      write_utf8(buf, cp)
    }
  }
  buf.to_bytes()
}

///|
fn write_utf8(buf : @buffer.Buffer, cp : Int32) -> Unit {
  if cp < 0x80 {
    buf.write_byte(cp.to_byte())
  } else if cp < 0x800 {
    buf.write_byte((0xC0 | (cp >> 6)).to_byte())
    buf.write_byte((0x80 | (cp & 0x3F)).to_byte())
  } else if cp < 0x10000 {
    buf.write_byte((0xE0 | (cp >> 12)).to_byte())
    buf.write_byte((0x80 | ((cp >> 6) & 0x3F)).to_byte())
    buf.write_byte((0x80 | (cp & 0x3F)).to_byte())
  } else {
    buf.write_byte((0xF0 | (cp >> 18)).to_byte())
    buf.write_byte((0x80 | ((cp >> 12) & 0x3F)).to_byte())
    buf.write_byte((0x80 | ((cp >> 6) & 0x3F)).to_byte())
    buf.write_byte((0x80 | (cp & 0x3F)).to_byte())
  }
}

///|
/// Returns true if `s` contains escaped bytes (i.e. its OS form is not valid
/// UTF-8).
pub fn has_escapes(s : String) -> Bool {
  for i in 0..<s.length() {
    let u = s.code_unit_at(i).to_int()
    if u >= 0xDC80 && u <= 0xDCFF {
      // A low surrogate preceded by a high one is part of a valid pair.
      if i == 0 || !(s.code_unit_at(i - 1).to_int() is (0xD800..<=0xDBFF)) {
        return true
      }
    }
  }
  false
}

///|
/// A string for display: escaped bytes are replaced like Rust's lossy
/// conversions (one U+FFFD per maximal invalid sequence), e.g. for paths
/// in error messages.
pub fn to_lossy(s : String) -> String {
  if has_escapes(s) {
    @utf8.decode_lossy(encode(s))
  } else {
    s
  }
}

///|
/// Returns true if `c` has the Unicode White_Space property (what Rust's
/// `str::trim` and bstr's `trim` remove).
pub fn is_white_space(c : Char) -> Bool {
  match c.to_int() {
    0x09..<=0x0D | 0x20 | 0x85 | 0xA0 | 0x1680 | 0x2000..<=0x200A => true
    0x2028 | 0x2029 | 0x202F | 0x205F | 0x3000 => true
    _ => false
  }
}

///|
/// Trims Unicode White_Space from both ends of `s`.
pub fn trim_white_space(s : String) -> String {
  let chars = s.to_array()
  let mut i = 0
  let mut j = chars.length()
  while i < j && is_white_space(chars[i]) {
    i += 1
  }
  while j > i && is_white_space(chars[j - 1]) {
    j -= 1
  }
  String::from_array(chars[i:j])
}
