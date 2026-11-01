///|
/// Wu-Manber style two-byte shifts over the shortest literal prefix. Hash
/// collisions only lower shifts or add verification candidates, never skip a
/// possible start. All candidates at a start are verified for longest selection.
priv struct LiteralShift {
  minimum : Int32
  shifts : FixedArray[Int32]
  buckets : Map[Int32, Array[Bytes]]
  patterns : Array[Bytes]
  can_switch : Bool
}

///|
// Search outcomes are not spans until every candidate start has been resolved.
priv enum LiteralOutcome {
  Found
  Resume
  Absent
}

///|
#valtype
priv struct LiteralSearch {
  outcome : LiteralOutcome
  start : Int32
  end : Int32
}

///|
fn LiteralSearch::span(self : LiteralSearch) -> (Int32, Int32)? {
  match self.outcome {
    Found => Some((self.start, self.end))
    Absent => None
    Resume => abort("unresolved literal handoff")
  }
}

///|
#inline
fn pair_hash(first : Byte, second : Byte) -> Int32 {
  ((first.to_int() << 4) ^ second.to_int()) & 4095
}

///|
fn LiteralShift::new(patterns : Array[Bytes]) -> LiteralShift? {
  let mut minimum = patterns[0].length()
  for pattern in patterns {
    minimum = minimum.min(pattern.length())
  }
  if minimum < 3 {
    return None
  }
  let shifts = FixedArray::make(4096, minimum - 1)
  let buckets : Map[Int32, Array[Bytes]] = Map([])
  for pattern in patterns {
    for index in 1..<minimum {
      let key = pair_hash(pattern[index - 1], pattern[index])
      shifts[key] = shifts[key].min(minimum - 1 - index)
    }
    let key = pair_hash(pattern[minimum - 2], pattern[minimum - 1])
    match buckets.get(key) {
      Some(group) => group.push(pattern)
      None => buckets[key] = [pattern]
    }
  }
  let mut can_switch = false
  for (_, group) in buckets {
    can_switch = can_switch || group.length() > 4
  }
  Some({ minimum, shifts, buckets, patterns: patterns.copy(), can_switch, })
}

///|
fn LiteralShift::find(
  self : LiteralShift,
  value : BytesView,
  start : Int32,
  first_only : Bool,
  allow_switch~ : Bool,
) -> LiteralSearch {
  if start < 0 || self.minimum > value.length() - start {
    return { outcome: Absent, start: 0, end: 0, }
  }
  let mut position = start + self.minimum - 1
  let mut window_start = position
  let mut checks = 0
  let adaptive = allow_switch && self.can_switch
  while position < value.length() {
    let key = pair_hash(value[position - 1], value[position])
    let shift = self.shifts[key]
    if shift > 0 {
      if shift >= value.length() - position {
        break
      }
      position += shift
      continue
    }
    let left = position - self.minimum + 1
    let mut length = 0
    if self.buckets.get(key) is Some(group) {
      if adaptive {
        if position - window_start >= literal_shift_density_window_bytes {
          window_start = position
          checks = 0
        }
        checks += group.length()
      }
      for pattern in group {
        if pattern.length() > length &&
          pattern.length() <= value.length() - left &&
          value[left:left + pattern.length()] == pattern[:] {
          if first_only {
            return {
              outcome: Found,
              start: left,
              end: left + pattern.length(),
            }
          }
          length = pattern.length()
        }
      }
    }
    if length > 0 {
      return { outcome: Found, start: left, end: left + length, }
    }
    // All candidate starts through `left` are resolved. The counter only
    // chooses an engine; it never establishes a match or skips an unchecked start.
    if adaptive &&
      checks >= literal_shift_minimum_checks &&
      checks > (position - window_start + 1) * 4 {
      return { outcome: Resume, start: left + 1, end: 0, }
    }
    position += 1
  }
  { outcome: Absent, start: 0, end: 0, }
}
