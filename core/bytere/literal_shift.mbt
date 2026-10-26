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
) -> (Int32, Int32)? {
  if start < 0 || self.minimum > value.length() - start {
    return None
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
        if position - window_start >= 4096 {
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
            return Some((left, left + pattern.length()))
          }
          length = pattern.length()
        }
      }
    }
    if length > 0 {
      return Some((left, left + length))
    }
    // All candidate starts through `left` are resolved. The counter only
    // chooses an engine; it never establishes a match or skips an unchecked start.
    if adaptive && checks >= 256 && checks > (position - window_start + 1) * 4 {
      // A negative start is an internal handoff, never a match. Returning
      // ordinary spans directly avoids allocating a second result per hit.
      return Some((-1, left + 1))
    }
    position += 1
  }
  None
}
