///|
/// A matcher searches haystacks for matches. Haystacks are given as a
/// window `hay[hs:he]` of a byte buffer; all offsets accepted and returned
/// are relative to `hs`, and the matcher must treat `hs` and `he` as the
/// boundaries of the haystack.
pub(open) trait Matcher {
  /// Returns the first match in the haystack starting at or after `at`.
  fn find_at(Self, FixedArray[Byte], Int32, Int32, Int32) -> Match?
  /// Creates an empty set of captures for this matcher.
  fn new_captures(Self) -> Captures
  /// The number of capture groups (including group 0), or 0 if captures are
  /// not supported.
  fn capture_count(Self) -> Int32 = _
  /// Maps a capture group name to its index.
  fn capture_index(Self, String) -> Int32? = _
  /// Finds the first match at or after `at` and fills in `caps`.
  fn captures_at(Self, FixedArray[Byte], Int32, Int32, Int32, Captures) -> Bool = _
  /// Returns the end offset of a match at or after `at`, if one exists.
  fn shortest_match_at(Self, FixedArray[Byte], Int32, Int32, Int32) -> Int32? = _
  /// Bytes that can never appear in a match.
  fn non_matching_bytes(Self) -> ByteSet? = _
  /// The line terminator that is guaranteed to never be in a match.
  fn line_terminator(Self) -> LineTerminator? = _
  /// Finds a line that might contain a match.
  fn find_candidate_line(Self, FixedArray[Byte], Int32, Int32) -> LineMatchKind? = _
}

///|
impl Matcher with fn capture_count(_self) {
  0
}

///|
impl Matcher with fn capture_index(_self, _name) {
  None
}

///|
impl Matcher with fn captures_at(_self, _hay, _hs, _he, _at, _caps) {
  false
}

///|
impl Matcher with fn shortest_match_at(self, hay, hs, he, at) {
  match self.find_at(hay, hs, he, at) {
    Some(m) => Some(m.end)
    None => None
  }
}

///|
impl Matcher with fn non_matching_bytes(_self) {
  None
}

///|
impl Matcher with fn line_terminator(_self) {
  None
}

///|
impl Matcher with fn find_candidate_line(self, hay, hs, he) {
  match self.shortest_match_at(hay, hs, he, 0) {
    Some(end) => Some(Confirmed(end))
    None => None
  }
}

///|
/// Calls `matched` for each successive non-overlapping match in
/// `hay[hs:he]` starting at `at`. Iteration stops if `matched` returns
/// false.
pub fn[M : Matcher] find_iter_at(
  m : M,
  hay : FixedArray[Byte],
  hs : Int32,
  he : Int32,
  at : Int32,
  matched : (Match) -> Bool,
) -> Unit {
  let len = he - hs
  let mut last_end = at
  let mut last_match : Int32? = None
  while last_end <= len {
    guard m.find_at(hay, hs, he, last_end) is Some(mat) else { return }
    if mat.start == mat.end {
      last_end = mat.end + 1
      if last_match == Some(mat.end) {
        continue
      }
    } else {
      last_end = mat.end
    }
    last_match = Some(mat.end)
    if !matched(mat) {
      return
    }
  }
}

///|
pub fn[M : Matcher] find_iter(
  m : M,
  hay : FixedArray[Byte],
  hs : Int32,
  he : Int32,
  matched : (Match) -> Bool,
) -> Unit {
  find_iter_at(m, hay, hs, he, 0, matched)
}

///|
/// Like `find_iter_at`, but reports capture groups.
pub fn[M : Matcher] captures_iter_at(
  m : M,
  hay : FixedArray[Byte],
  hs : Int32,
  he : Int32,
  at : Int32,
  caps : Captures,
  matched : (Captures) -> Bool,
) -> Unit {
  let len = he - hs
  let mut last_end = at
  let mut last_match : Int32? = None
  while last_end <= len {
    if !m.captures_at(hay, hs, he, last_end, caps) {
      return
    }
    let mat = caps.get(0).unwrap()
    if mat.start == mat.end {
      last_end = mat.end + 1
      if last_match == Some(mat.end) {
        continue
      }
    } else {
      last_end = mat.end
    }
    last_match = Some(mat.end)
    if !matched(caps) {
      return
    }
  }
}

///|
/// Replaces every match in `hay[hs:he]` by calling `append`, writing the
/// result to `dst`.
pub fn[M : Matcher] replace(
  m : M,
  hay : FixedArray[Byte],
  hs : Int32,
  he : Int32,
  dst : Buffer,
  append : (Match, Buffer) -> Bool,
) -> Unit {
  let mut last = 0
  find_iter(m, hay, hs, he, mat => {
    for i in last..<mat.start {
      dst.write_byte(hay[hs + i])
    }
    last = mat.end
    append(mat, dst)
  })
  for i in (hs + last)..<he {
    dst.write_byte(hay[i])
  }
}

///|
/// Replaces every match in `hay[hs:he]` starting at `at`, using capture
/// groups, writing the result to `dst`.
pub fn[M : Matcher] replace_with_captures_at(
  m : M,
  hay : FixedArray[Byte],
  hs : Int32,
  he : Int32,
  at : Int32,
  caps : Captures,
  dst : Buffer,
  append : (Captures, Buffer) -> Bool,
) -> Unit {
  let mut last = at
  captures_iter_at(m, hay, hs, he, at, caps, caps => {
    let mat = caps.get(0).unwrap()
    for i in last..<mat.start {
      dst.write_byte(hay[hs + i])
    }
    last = mat.end
    append(caps, dst)
  })
  for i in (hs + last)..<he {
    dst.write_byte(hay[i])
  }
}

///|
pub fn[M : Matcher] is_match_at(
  m : M,
  hay : FixedArray[Byte],
  hs : Int32,
  he : Int32,
  at : Int32,
) -> Bool {
  m.shortest_match_at(hay, hs, he, at) is Some(_)
}
