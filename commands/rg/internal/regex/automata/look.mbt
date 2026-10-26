///|
/// Returns true if the byte is an ASCII word byte (`[0-9A-Za-z_]`).
pub fn is_word_byte(b : Int32) -> Bool {
  (b >= 'a' && b <= 'z') ||
  (b >= 'A' && b <= 'Z') ||
  (b >= '0' && b <= '9') ||
  b == '_'
}

///|
/// Decodes the UTF-8 encoded scalar value starting at `at`, bounded by
/// `he`, returning `None` if it's invalid.
fn decode_fwd(hay : FixedArray[Byte], he : Int32, at : Int32) -> Int32? {
  if at >= he {
    return None
  }
  let b0 = hay[at].to_int()
  if b0 < 0x80 {
    return Some(b0)
  }
  let (n, init, min) = if b0 >= 0xC2 && b0 <= 0xDF {
    (2, b0 & 0x1F, 0x80)
  } else if b0 >= 0xE0 && b0 <= 0xEF {
    (3, b0 & 0x0F, 0x800)
  } else if b0 >= 0xF0 && b0 <= 0xF4 {
    (4, b0 & 0x07, 0x10000)
  } else {
    return None
  }
  if at + n > he {
    return None
  }
  let mut cp = init
  for i in 1..<n {
    let b = hay[at + i].to_int()
    if (b & 0xC0) != 0x80 {
      return None
    }
    cp = (cp << 6) | (b & 0x3F)
  }
  if cp < min || cp > 0x10FFFF || (cp >= 0xD800 && cp <= 0xDFFF) {
    None
  } else {
    Some(cp)
  }
}

///|
/// Decodes the UTF-8 encoded scalar value ending at `at` (exclusive),
/// looking no further back than `hs`.
fn decode_rev(hay : FixedArray[Byte], hs : Int32, at : Int32) -> Int32? {
  if at <= hs {
    return None
  }
  let limit = if at - 4 >= hs { at - 4 } else { hs }
  let mut start = at - 1
  while start > limit && (hay[start].to_int() & 0xC0) == 0x80 {
    start -= 1
  }
  match decode_fwd(hay, at, start) {
    Some(cp) => if start + utf8_len_of(cp) == at { Some(cp) } else { None }
    None => None
  }
}

///|
fn utf8_len_of(c : Int32) -> Int32 {
  if c < 0x80 {
    1
  } else if c < 0x800 {
    2
  } else if c < 0x10000 {
    3
  } else {
    4
  }
}

///|
fn is_word_char_fwd(hay : FixedArray[Byte], he : Int32, at : Int32) -> Bool {
  match decode_fwd(hay, he, at) {
    Some(c) => @unicode.is_word_character(c)
    None => false
  }
}

///|
fn is_word_char_rev(hay : FixedArray[Byte], hs : Int32, at : Int32) -> Bool {
  match decode_rev(hay, hs, at) {
    Some(c) => @unicode.is_word_character(c)
    None => false
  }
}

///|
/// Returns true if the look-around assertion is satisfied at position `at`
/// in the haystack `hay[hs:he]`. Positions are absolute indices into `hay`.
pub fn look_matches(
  look : @syntax.Look,
  hay : FixedArray[Byte],
  hs : Int32,
  he : Int32,
  at : Int32,
  lineterm~ : Int32 = '\n',
) -> Bool {
  match look {
    Start => at == hs
    End => at == he
    StartLF => at == hs || hay[at - 1].to_int() == lineterm
    EndLF => at == he || hay[at].to_int() == lineterm
    StartCRLF =>
      at == hs ||
      hay[at - 1] == b'\n' ||
      (hay[at - 1] == b'\r' && (at >= he || hay[at] != b'\n'))
    EndCRLF =>
      at == he ||
      hay[at] == b'\r' ||
      (hay[at] == b'\n' && (at == hs || hay[at - 1] != b'\r'))
    WordAscii => {
      let before = at > hs && is_word_byte(hay[at - 1].to_int())
      let after = at < he && is_word_byte(hay[at].to_int())
      before != after
    }
    WordAsciiNegate => {
      let before = at > hs && is_word_byte(hay[at - 1].to_int())
      let after = at < he && is_word_byte(hay[at].to_int())
      before == after
    }
    WordStartAscii => {
      let before = at > hs && is_word_byte(hay[at - 1].to_int())
      let after = at < he && is_word_byte(hay[at].to_int())
      !before && after
    }
    WordEndAscii => {
      let before = at > hs && is_word_byte(hay[at - 1].to_int())
      let after = at < he && is_word_byte(hay[at].to_int())
      before && !after
    }
    WordStartHalfAscii => !(at > hs && is_word_byte(hay[at - 1].to_int()))
    WordEndHalfAscii => !(at < he && is_word_byte(hay[at].to_int()))
    WordUnicode =>
      is_word_char_rev(hay, hs, at) != is_word_char_fwd(hay, he, at)
    WordUnicodeNegate => {
      // Like regex-automata: \B never matches when either side of `at` is
      // not valid UTF-8, so that it never splits a codepoint.
      if at > hs && decode_rev(hay, hs, at) is None {
        return false
      }
      if at < he && decode_fwd(hay, he, at) is None {
        return false
      }
      is_word_char_rev(hay, hs, at) == is_word_char_fwd(hay, he, at)
    }
    WordStartUnicode =>
      !is_word_char_rev(hay, hs, at) && is_word_char_fwd(hay, he, at)
    WordEndUnicode =>
      is_word_char_rev(hay, hs, at) && !is_word_char_fwd(hay, he, at)
    // Like regex-automata, the half assertions never match next to invalid
    // UTF-8 (e.g. inside a codepoint).
    WordStartHalfUnicode =>
      if at > hs && decode_rev(hay, hs, at) is None {
        false
      } else {
        !is_word_char_rev(hay, hs, at)
      }
    WordEndHalfUnicode =>
      if at < he && decode_fwd(hay, he, at) is None {
        false
      } else {
        !is_word_char_fwd(hay, he, at)
      }
  }
}
