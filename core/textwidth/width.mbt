///|
#derive(Eq)
pub(all) enum Profile {
  CBytes
  Utf8
}

///|
/// Select the reproducible C.UTF-8 character profile once at command startup.
pub fn current() -> Profile {
  for name in ["LC_ALL", "LC_CTYPE", "LANG"] {
    if @env.get_env_var(name) is Some(value) && !value.is_empty() {
      return match value {
        "C.UTF-8" | "C.utf8" => Utf8
        _ => CBytes
      }
    }
  }
  CBytes
}

///|
/// A malformed byte consumes one byte. Only an incomplete prefix at a
/// nonfinal stream boundary can return length zero.
pub fn Profile::next(
  self : Profile,
  data : BytesView,
  at : Int32,
  eof~ : Bool = true,
) -> (Char?, Int32) {
  let first = data[at].to_int()
  if self == CBytes || first < 0x80 {
    return (first.to_char(), 1)
  }
  let (len, mask) = match first {
    0xc2..<=0xdf => (2, 0x1f)
    0xe0..<=0xef => (3, 0x0f)
    0xf0..<=0xf4 => (4, 0x07)
    _ => return (None, 1)
  }
  let mut scalar = first & mask
  for i in 1..<len {
    if i >= data.length() - at {
      return (None, if eof { 1 } else { 0 })
    }
    let byte = data[at + i].to_int()
    let invalid_second = match first {
      0xe0 => byte < 0xa0
      0xed => byte >= 0xa0
      0xf0 => byte < 0x90
      0xf4 => byte > 0x8f
      _ => false
    }
    if byte < 0x80 || byte > 0xbf || (i == 1 && invalid_second) {
      return (None, 1)
    }
    scalar = (scalar << 6) | (byte & 0x3f)
  }
  (scalar.to_char(), len)
}

///|
/// Unicode 16 narrow-ambiguous scalar width, with the command's selected
/// fallback for invalid bytes and nonprinting controls.
pub fn cells(ch : Char?, fallback~ : Int32) -> Int32 {
  match ch {
    Some('\u0000') => 0
    Some(' '..<='~') => 1
    Some(c) => @unicodewidth.char_width(c).unwrap_or(fallback)
    None => fallback
  }
}

///|
/// Horizontal separators used by GNU coreutils in glibc's C.UTF-8 locale.
/// Nonbreaking spaces remain part of a word for fold and tab expansion.
pub fn is_blank(ch : Char?) -> Bool {
  ch
  is Some(
    ' '
    | '\t'
    | '\u1680'
    | '\u2000'..<='\u2006'
    | '\u2008'..<='\u200a'
    | '\u205f'
    | '\u3000',
  )
}
