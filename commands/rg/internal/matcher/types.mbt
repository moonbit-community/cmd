///|
/// The byte offsets of a match, relative to the haystack searched.
pub(all) struct Match {
  start : Int32
  end : Int32
} derive(Debug, Eq, Hash)

///|
pub fn Match::new(start : Int32, end : Int32) -> Match {
  guard start <= end else { abort("match start \{start} > end \{end}") }
  { start, end, }
}

///|
pub fn Match::zero(offset : Int32) -> Match {
  { start: offset, end: offset, }
}

///|
pub fn Match::with_start(self : Match, start : Int32) -> Match {
  Match::new(start, self.end)
}

///|
pub fn Match::with_end(self : Match, end : Int32) -> Match {
  Match::new(self.start, end)
}

///|
pub fn Match::offset(self : Match, amount : Int32) -> Match {
  { start: self.start + amount, end: self.end + amount, }
}

///|
pub fn Match::len(self : Match) -> Int32 {
  self.end - self.start
}

///|
pub fn Match::is_empty(self : Match) -> Bool {
  self.start == self.end
}

///|
/// A line terminator: either a single byte or CRLF (which means `\n` is the
/// terminator but a preceding `\r` is also stripped).
pub(all) enum LineTerminator {
  Byte(Byte)
  CRLF
} derive(Debug, Eq, Hash)

///|
pub fn LineTerminator::byte(b : Byte) -> LineTerminator {
  Byte(b)
}

///|
pub fn LineTerminator::crlf() -> LineTerminator {
  CRLF
}

///|
pub fn LineTerminator::default() -> LineTerminator {
  Byte(b'\n')
}

///|
pub fn LineTerminator::is_crlf(self : LineTerminator) -> Bool {
  self is CRLF
}

///|
/// Returns the byte that terminates lines (`\n` for CRLF).
pub fn LineTerminator::as_byte(self : LineTerminator) -> Byte {
  match self {
    Byte(b) => b
    CRLF => b'\n'
  }
}

///|
pub fn LineTerminator::as_bytes(self : LineTerminator) -> Bytes {
  match self {
    Byte(b) => Bytes::make(1, b)
    CRLF => b"\r\n"
  }
}

///|
/// Returns true if `hay[start:end]` ends with this line terminator.
pub fn LineTerminator::is_suffix(
  self : LineTerminator,
  hay : FixedArray[Byte],
  start : Int32,
  end : Int32,
) -> Bool {
  end > start && hay[end - 1] == self.as_byte()
}

///|
/// A set of bytes.
pub struct ByteSet {
  priv bits : FixedArray[Bool]
}

///|
pub fn ByteSet::empty() -> ByteSet {
  { bits: FixedArray::make(256, false), }
}

///|
pub fn ByteSet::full() -> ByteSet {
  { bits: FixedArray::make(256, true), }
}

///|
pub fn ByteSet::add(self : ByteSet, b : Byte) -> Unit {
  self.bits[b.to_int()] = true
}

///|
pub fn ByteSet::add_all(self : ByteSet, start : Byte, end : Byte) -> Unit {
  for b in start.to_int()..<=end.to_int() {
    self.bits[b] = true
  }
}

///|
pub fn ByteSet::remove(self : ByteSet, b : Byte) -> Unit {
  self.bits[b.to_int()] = false
}

///|
pub fn ByteSet::remove_all(self : ByteSet, start : Byte, end : Byte) -> Unit {
  for b in start.to_int()..<=end.to_int() {
    self.bits[b] = false
  }
}

///|
pub fn ByteSet::contains(self : ByteSet, b : Byte) -> Bool {
  self.bits[b.to_int()]
}

///|
pub impl Debug for ByteSet with fn to_repr(self) {
  let items = []
  for b in 0..<256 {
    if self.bits[b] {
      items.push(Repr::integer(b.to_string()))
    }
  }
  Repr::array(items)
}

///|
/// The result of searching for a candidate line.
pub(all) enum LineMatchKind {
  /// A line was confirmed to match; the offset is within that line.
  Confirmed(Int32)
  /// A line may match; the offset is within that line.
  Candidate(Int32)
} derive(Debug, Eq)

///|
/// Capture group positions for a single match. Offsets are relative to the
/// haystack that was searched.
pub struct Captures {
  /// Two slots per group; -1 means the group did not participate.
  slots : FixedArray[Int32]
}

///|
pub fn Captures::new(group_len : Int32) -> Captures {
  { slots: FixedArray::make(group_len * 2, -1), }
}

///|
/// The number of groups, including the implicit group 0.
pub fn Captures::len(self : Captures) -> Int32 {
  self.slots.length() / 2
}

///|
pub fn Captures::is_empty(self : Captures) -> Bool {
  self.len() == 0
}

///|
pub fn Captures::get(self : Captures, i : Int32) -> Match? {
  if i < 0 || 2 * i + 1 >= self.slots.length() {
    return None
  }
  let s = self.slots[2 * i]
  let e = self.slots[2 * i + 1]
  if s < 0 || e < 0 {
    None
  } else {
    Some({ start: s, end: e, })
  }
}

///|
/// Returns the overall match (group 0). Panics if there is none.
pub fn Captures::as_match(self : Captures) -> Match {
  self.get(0).unwrap()
}

///|
/// Expands `replacement` into `dst`, substituting capture group references
/// like `$1`, `${1}`, `$name` and `${name}` using the matched text in
/// `hay[hs:]` (group offsets are relative to `hs`).
pub fn Captures::interpolate(
  self : Captures,
  name_to_index : (String) -> Int32?,
  hay : FixedArray[Byte],
  hs : Int32,
  replacement : Bytes,
  dst : Buffer,
) -> Unit {
  interpolate(
    replacement,
    (i, dst) => {
      if self.get(i) is Some(m) {
        for j in m.start..<m.end {
          dst.write_byte(hay[hs + j])
        }
      }
    },
    name_to_index,
    dst,
  )
}
