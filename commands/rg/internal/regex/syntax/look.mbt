///|
/// The kind of a look-around assertion.
pub(all) enum Look {
  Start
  End
  StartLF
  EndLF
  StartCRLF
  EndCRLF
  WordAscii
  WordAsciiNegate
  WordUnicode
  WordUnicodeNegate
  WordStartAscii
  WordEndAscii
  WordStartUnicode
  WordEndUnicode
  WordStartHalfAscii
  WordEndHalfAscii
  WordStartHalfUnicode
  WordEndHalfUnicode
} derive(Debug, Eq, Hash)

///|
pub fn Look::as_bit(self : Look) -> UInt32 {
  let i = match self {
    Start => 0
    End => 1
    StartLF => 2
    EndLF => 3
    StartCRLF => 4
    EndCRLF => 5
    WordAscii => 6
    WordAsciiNegate => 7
    WordUnicode => 8
    WordUnicodeNegate => 9
    WordStartAscii => 10
    WordEndAscii => 11
    WordStartUnicode => 12
    WordEndUnicode => 13
    WordStartHalfAscii => 14
    WordEndHalfAscii => 15
    WordStartHalfUnicode => 16
    WordEndHalfUnicode => 17
  }
  1U << i
}

///|
let all_looks : Array[Look] = [
  Start,
  End,
  StartLF,
  EndLF,
  StartCRLF,
  EndCRLF,
  WordAscii,
  WordAsciiNegate,
  WordUnicode,
  WordUnicodeNegate,
  WordStartAscii,
  WordEndAscii,
  WordStartUnicode,
  WordEndUnicode,
  WordStartHalfAscii,
  WordEndHalfAscii,
  WordStartHalfUnicode,
  WordEndHalfUnicode,
]

///|
/// Returns the assertion with the opposite direction.
pub fn Look::reversed(self : Look) -> Look {
  match self {
    Start => End
    End => Start
    StartLF => EndLF
    EndLF => StartLF
    StartCRLF => EndCRLF
    EndCRLF => StartCRLF
    WordAscii => WordAscii
    WordAsciiNegate => WordAsciiNegate
    WordUnicode => WordUnicode
    WordUnicodeNegate => WordUnicodeNegate
    WordStartAscii => WordEndAscii
    WordEndAscii => WordStartAscii
    WordStartUnicode => WordEndUnicode
    WordEndUnicode => WordStartUnicode
    WordStartHalfAscii => WordEndHalfAscii
    WordEndHalfAscii => WordStartHalfAscii
    WordStartHalfUnicode => WordEndHalfUnicode
    WordEndHalfUnicode => WordStartHalfUnicode
  }
}

///|
/// A set of look-around assertions represented as a bit set.
pub(all) struct LookSet {
  bits : UInt32
} derive(Debug, Eq, Hash)

///|
pub fn LookSet::empty() -> LookSet {
  { bits: 0, }
}

///|
pub fn LookSet::full() -> LookSet {
  { bits: (1U << 18) - 1, }
}

///|
pub fn LookSet::singleton(look : Look) -> LookSet {
  { bits: look.as_bit(), }
}

///|
pub fn LookSet::is_empty(self : LookSet) -> Bool {
  self.bits == 0
}

///|
pub fn LookSet::contains(self : LookSet, look : Look) -> Bool {
  (self.bits & look.as_bit()) != 0
}

///|
pub fn LookSet::insert(self : LookSet, look : Look) -> LookSet {
  { bits: self.bits | look.as_bit(), }
}

///|
pub fn LookSet::remove(self : LookSet, look : Look) -> LookSet {
  { bits: self.bits & look.as_bit().lnot(), }
}

///|
pub fn LookSet::union(self : LookSet, other : LookSet) -> LookSet {
  { bits: self.bits | other.bits, }
}

///|
pub fn LookSet::intersect(self : LookSet, other : LookSet) -> LookSet {
  { bits: self.bits & other.bits, }
}

///|
pub fn LookSet::subtract(self : LookSet, other : LookSet) -> LookSet {
  { bits: self.bits & other.bits.lnot(), }
}

///|
pub fn LookSet::iter(self : LookSet) -> Iter[Look] {
  all_looks.iter().filter(l => self.contains(l))
}

///|
pub fn LookSet::contains_anchor(self : LookSet) -> Bool {
  self.contains_anchor_haystack() || self.contains_anchor_line()
}

///|
pub fn LookSet::contains_anchor_haystack(self : LookSet) -> Bool {
  self.contains(Start) || self.contains(End)
}

///|
pub fn LookSet::contains_anchor_line(self : LookSet) -> Bool {
  self.contains(StartLF) ||
  self.contains(EndLF) ||
  self.contains(StartCRLF) ||
  self.contains(EndCRLF)
}

///|
pub fn LookSet::contains_anchor_lf(self : LookSet) -> Bool {
  self.contains(StartLF) || self.contains(EndLF)
}

///|
pub fn LookSet::contains_anchor_crlf(self : LookSet) -> Bool {
  self.contains(StartCRLF) || self.contains(EndCRLF)
}

///|
pub fn LookSet::contains_word(self : LookSet) -> Bool {
  self.contains_word_unicode() || self.contains_word_ascii()
}

///|
pub fn LookSet::contains_word_unicode(self : LookSet) -> Bool {
  self.contains(WordUnicode) ||
  self.contains(WordUnicodeNegate) ||
  self.contains(WordStartUnicode) ||
  self.contains(WordEndUnicode) ||
  self.contains(WordStartHalfUnicode) ||
  self.contains(WordEndHalfUnicode)
}

///|
pub fn LookSet::contains_word_ascii(self : LookSet) -> Bool {
  self.contains(WordAscii) ||
  self.contains(WordAsciiNegate) ||
  self.contains(WordStartAscii) ||
  self.contains(WordEndAscii) ||
  self.contains(WordStartHalfAscii) ||
  self.contains(WordEndHalfAscii)
}
