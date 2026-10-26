///|
/// A prefilter quickly finds candidate match positions using literals that
/// every match must start with.
pub(all) enum Prefilter {
  /// A single byte.
  Byte(Byte)
  /// One of two bytes (each literal is a single byte).
  Bytes2(Byte, Byte)
  /// One of three bytes.
  Bytes3(Byte, Byte, Byte)
  /// A larger set of bytes.
  ByteSet(FixedArray[Bool])
  /// A single literal of length >= 2.
  Substr(@memchr.Finder)
  /// Several literals (at most `@memchr.teddy_max_literals`), found with
  /// the Teddy SIMD algorithm.
  Teddy(@memchr.Teddy)
  /// Several literals, bucketed by their first byte in priority order.
  /// Candidates are found with a SIMD pair-set filter when possible, else
  /// with the distinct first bytes (when there are at most three of them, so
  /// they can be found with `memchr2`/`memchr3`) or the first-byte set.
  Multi(
    @memchr.PairSet?,
    FixedArray[Byte],
    FixedArray[Bool],
    Array[Array[FixedArray[Byte]]],
    Int32
  )
}

///|
/// Builds a prefilter from a set of literals, in priority order. Returns
/// `None` if no useful prefilter could be built.
pub fn Prefilter::new(lits : Array[Bytes]) -> Prefilter? {
  if lits.is_empty() || lits.iter().any(l => l.length() == 0) {
    return None
  }
  if lits.length() == 1 {
    let lit = lits[0]
    if lit.length() == 1 {
      return Some(Byte(lit[0]))
    }
    // Filter candidates with the two rarest bytes of the literal.
    let rank = (i : Int32) => @syntax.rank(lit[i].to_int())
    let mut r1 = 0
    for i in 1..<lit.length() {
      if rank(i) < rank(r1) {
        r1 = i
      }
    }
    let mut r2 = if r1 == 0 { 1 } else { 0 }
    for i in 0..<lit.length() {
      if i != r1 && rank(i) < rank(r2) {
        r2 = i
      }
    }
    return Some(Substr(@memchr.Finder::new(lit.to_fixedarray(), r1, r2)))
  }
  let set = FixedArray::make(256, false)
  let firsts : Array[Byte] = []
  for l in lits {
    if !set[l[0].to_int()] {
      set[l[0].to_int()] = true
      firsts.push(l[0])
    }
  }
  if lits.iter().all(l => l.length() == 1) {
    return Some(
      match firsts {
        [a] => Byte(a)
        [a, b] => Bytes2(a, b)
        [a, b, c] => Bytes3(a, b, c)
        _ => ByteSet(set)
      },
    )
  }
  if @memchr.Teddy::new(lits.map(l => l.to_fixedarray())) is Some(t) {
    return Some(Teddy(t))
  }
  let buckets : Array[Array[FixedArray[Byte]]] = Array::makei(256, _ => [])
  let mut min_len = lits[0].length()
  for l in lits {
    buckets[l[0].to_int()].push(l.to_fixedarray())
    if l.length() < min_len {
      min_len = l.length()
    }
  }
  let small = if firsts.length() <= 3 {
    FixedArray::from_array(firsts)
  } else {
    []
  }
  Some(Multi(pair_set(lits, min_len), small, set, buckets, min_len))
}

///|
/// Picks the two offsets (below `min_len`) whose sets of bytes across all
/// literals are small (at most 4 bytes) and rarest, and builds a pair-set
/// filter from them.
fn pair_set(lits : Array[Bytes], min_len : Int32) -> @memchr.PairSet? {
  let cands : Array[(Int32, Array[Byte], Int32)] = []
  for o in 0..<min_len {
    let bytes : Array[Byte] = []
    for l in lits {
      if !bytes.contains(l[o]) {
        bytes.push(l[o])
      }
      if bytes.length() > 4 {
        break
      }
    }
    if bytes.length() <= 4 {
      let mut score = 0
      for b in bytes {
        score += @syntax.rank(b.to_int())
      }
      cands.push((o, bytes, score))
    }
  }
  if cands.is_empty() {
    return None
  }
  cands.sort_by((a, b) => a.2.compare(b.2))
  let (o1, s1, _) = cands[0]
  let (o2, s2, _) = if cands.length() > 1 { cands[1] } else { cands[0] }
  Some(@memchr.PairSet::new(o1, s1, o2, s2))
}

///|
/// Returns true if the prefilter is believed to be fast.
pub fn Prefilter::is_fast(self : Prefilter) -> Bool {
  match self {
    Byte(b) => @syntax.rank(b.to_int()) < 250
    Bytes2(_, _) | Bytes3(_, _, _) | Substr(_) | Teddy(_) => true
    ByteSet(_) => false
    Multi(_, _, set, _, _) => {
      let mut n = 0
      for i in 0..<256 {
        if set[i] {
          n += 1
        }
      }
      n <= 16
    }
  }
}

///|
/// Returns the position of the first byte equal to `b` in `hay[start:end]`.
pub fn memchr(
  b : Byte,
  hay : FixedArray[Byte],
  start : Int32,
  end : Int32,
) -> Int32? {
  let i = @memchr.memchr(b, hay, start, end)
  if i < 0 {
    None
  } else {
    Some(i)
  }
}

///|
/// Returns true if `needle` occurs at `hay[at:]` (bounded by `end`).
fn matches_at(
  needle : FixedArray[Byte],
  hay : FixedArray[Byte],
  at : Int32,
  end : Int32,
) -> Bool {
  let n = needle.length()
  if at + n > end {
    return false
  }
  for j in 0..<n {
    if hay[at + j] != needle[j] {
      return false
    }
  }
  true
}

///|
/// Finds the next candidate in `hay[start:end]` like `find`, returning
/// its span packed as `start << 32 | end`, or `NO_SPAN` (this avoids
/// allocating in hot search loops).
pub fn Prefilter::find_span(
  self : Prefilter,
  hay : FixedArray[Byte],
  start : Int32,
  end : Int32,
) -> Int64 {
  let one = (i : Int32) => if i < 0 { NO_SPAN } else { span(i, i + 1) }
  match self {
    Byte(b) => one(@memchr.memchr(b, hay, start, end))
    Bytes2(a, b) => one(@memchr.memchr2(a, b, hay, start, end))
    Bytes3(a, b, c) => one(@memchr.memchr3(a, b, c, hay, start, end))
    ByteSet(set) => {
      for i in start..<end {
        if set[hay[i].to_int()] {
          return span(i, i + 1)
        }
      }
      NO_SPAN
    }
    Teddy(t) => t.find_span(hay, start, end)
    Substr(finder) => {
      let i = finder.find(hay, start, end)
      if i < 0 {
        NO_SPAN
      } else {
        span(i, i + finder.needle().length())
      }
    }
    Multi(pairs, small, set, buckets, min_len) => {
      let last = end - min_len
      let mut i = start
      while i <= last {
        // Jump to the next candidate position.
        i = if pairs is Some(ps) {
          ps.find(hay, i, last + 1)
        } else {
          match small.length() {
            1 => @memchr.memchr(small[0], hay, i, last + 1)
            2 => @memchr.memchr2(small[0], small[1], hay, i, last + 1)
            3 => @memchr.memchr3(small[0], small[1], small[2], hay, i, last + 1)
            _ => {
              let mut j = i
              while j <= last && !set[hay[j].to_int()] {
                j += 1
              }
              if j > last {
                -1
              } else {
                j
              }
            }
          }
        }
        if i < 0 {
          return NO_SPAN
        }
        for lit in buckets[hay[i].to_int()] {
          if matches_at(lit, hay, i, end) {
            return span(i, i + lit.length())
          }
        }
        i += 1
      }
      NO_SPAN
    }
  }
}

///|
/// The packed span returned when there is no candidate.
pub const NO_SPAN : Int64 = -1L

///|
fn span(start : Int32, end : Int32) -> Int64 {
  (start.to_int64() << 32) | end.to_int64()
}

///|
/// The start of a packed span.
pub fn span_start(sp : Int64) -> Int32 {
  (sp >> 32).to_int()
}

///|
/// The end of a packed span.
pub fn span_end(sp : Int64) -> Int32 {
  (sp & 0xFFFFFFFFL).to_int()
}

///|
/// Returns the start of the next candidate in `hay[start:end]`, or `-1`.
pub fn Prefilter::find_start(
  self : Prefilter,
  hay : FixedArray[Byte],
  start : Int32,
  end : Int32,
) -> Int32 {
  let sp = self.find_span(hay, start, end)
  if sp == NO_SPAN {
    -1
  } else {
    span_start(sp)
  }
}

///|
/// Finds the start of the next candidate in `hay[start:end]`, returning
/// the span of the literal that was found (`(start, end)`).
pub fn Prefilter::find(
  self : Prefilter,
  hay : FixedArray[Byte],
  start : Int32,
  end : Int32,
) -> (Int32, Int32)? {
  let sp = self.find_span(hay, start, end)
  if sp == NO_SPAN {
    None
  } else {
    Some((span_start(sp), span_end(sp)))
  }
}
