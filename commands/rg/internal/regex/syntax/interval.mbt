///|
/// Increments a bound. For Unicode scalar values, the surrogate range is
/// skipped.
fn bound_increment(x : Int32, unicode : Bool) -> Int32 {
  if unicode && x == 0xD7FF {
    0xE000
  } else {
    x + 1
  }
}

///|
fn bound_decrement(x : Int32, unicode : Bool) -> Int32 {
  if unicode && x == 0xE000 {
    0xD7FF
  } else {
    x - 1
  }
}

///|
fn max_bound(unicode : Bool) -> Int32 {
  if unicode {
    0x10FFFF
  } else {
    0xFF
  }
}

///|
/// Sorts and merges overlapping or adjacent ranges.
pub fn canonicalize_ranges(
  ranges : Array[(Int32, Int32)],
  unicode~ : Bool = true,
) -> Array[(Int32, Int32)] {
  ignore(unicode)
  let rs = ranges.map(r => if r.0 <= r.1 { r } else { (r.1, r.0) })
  rs.sort_by((a, b) => if a.0 != b.0 { a.0 - b.0 } else { a.1 - b.1 })
  let out : Array[(Int32, Int32)] = []
  for r in rs {
    match out.last() {
      Some(last) =>
        if r.0 <= last.1 + 1 {
          if r.1 > last.1 {
            out[out.length() - 1] = (last.0, r.1)
          }
        } else {
          out.push(r)
        }
      None => out.push(r)
    }
  }
  out
}

///|
fn ranges_union(
  a : Array[(Int32, Int32)],
  b : Array[(Int32, Int32)],
) -> Array[(Int32, Int32)] {
  if b.is_empty() {
    return a
  }
  if a.is_empty() {
    return b
  }
  let all = a.copy()
  all.append(b)
  canonicalize_ranges(all)
}

///|
fn ranges_intersect(
  a : Array[(Int32, Int32)],
  b : Array[(Int32, Int32)],
) -> Array[(Int32, Int32)] {
  let out = []
  let mut i = 0
  let mut j = 0
  while i < a.length() && j < b.length() {
    let lo = if a[i].0 > b[j].0 { a[i].0 } else { b[j].0 }
    let hi = if a[i].1 < b[j].1 { a[i].1 } else { b[j].1 }
    if lo <= hi {
      out.push((lo, hi))
    }
    if a[i].1 < b[j].1 {
      i += 1
    } else {
      j += 1
    }
  }
  out
}

///|
fn ranges_difference(
  a : Array[(Int32, Int32)],
  b : Array[(Int32, Int32)],
  unicode : Bool,
) -> Array[(Int32, Int32)] {
  let out = []
  let mut j = 0
  for r in a {
    while j < b.length() && b[j].1 < r.0 {
      j += 1
    }
    let mut cur = r.0
    let mut k = j
    while k < b.length() && b[k].0 <= r.1 && cur <= r.1 {
      if b[k].0 > cur {
        out.push((cur, bound_decrement(b[k].0, unicode)))
      }
      let next = bound_increment(b[k].1, unicode)
      if next > cur {
        cur = next
      }
      k += 1
    }
    if cur <= r.1 {
      out.push((cur, r.1))
    }
  }
  out
}

///|
fn ranges_symmetric_difference(
  a : Array[(Int32, Int32)],
  b : Array[(Int32, Int32)],
  unicode : Bool,
) -> Array[(Int32, Int32)] {
  let inter = ranges_intersect(a, b)
  ranges_difference(ranges_union(a, b), inter, unicode)
}

///|
fn ranges_negate(
  a : Array[(Int32, Int32)],
  unicode : Bool,
) -> Array[(Int32, Int32)] {
  let max = max_bound(unicode)
  if a.is_empty() {
    return [(0, max)]
  }
  let out = []
  if a[0].0 > 0 {
    out.push((0, bound_decrement(a[0].0, unicode)))
  }
  for i in 1..<a.length() {
    let lo = bound_increment(a[i - 1].1, unicode)
    let hi = bound_decrement(a[i].0, unicode)
    out.push(if lo <= hi { (lo, hi) } else { (hi, lo) })
  }
  if a[a.length() - 1].1 < max {
    out.push((bound_increment(a[a.length() - 1].1, unicode), max))
  }
  out
}

///|
fn ranges_case_fold_unicode(a : Array[(Int32, Int32)]) -> Array[(Int32, Int32)] {
  let extra = []
  for r in a {
    if !@unicode.fold_overlaps(r.0, r.1) {
      continue
    }
    @unicode.each_fold_in_range(r.0, r.1, (_, mapped) => {
      for m in mapped {
        extra.push((m, m))
      }
    })
  }
  if extra.is_empty() {
    a
  } else {
    ranges_union(a, extra)
  }
}

///|
fn ranges_case_fold_bytes(a : Array[(Int32, Int32)]) -> Array[(Int32, Int32)] {
  let extra = []
  for r in a {
    let lo = if r.0 > 'a' { r.0 } else { 'a' }
    let hi = if r.1 < 'z' { r.1 } else { 'z' }
    if lo <= hi {
      extra.push((lo - 32, hi - 32))
    }
    let lo = if r.0 > 'A' { r.0 } else { 'A' }
    let hi = if r.1 < 'Z' { r.1 } else { 'Z' }
    if lo <= hi {
      extra.push((lo + 32, hi + 32))
    }
  }
  if extra.is_empty() {
    a
  } else {
    ranges_union(a, extra)
  }
}

///|
fn ranges_is_ascii(a : Array[(Int32, Int32)]) -> Bool {
  a.is_empty() || a[a.length() - 1].1 <= 0x7F
}

///|
/// A character class: either a set of Unicode scalar value ranges or a set
/// of byte ranges. Ranges are always canonical (sorted, non-overlapping and
/// non-adjacent).
pub(all) enum Class {
  Unicode(Array[(Int32, Int32)])
  Bytes(Array[(Int32, Int32)])
} derive(Debug, Eq)

///|
pub fn Class::ranges(self : Class) -> Array[(Int32, Int32)] {
  match self {
    Unicode(r) | Bytes(r) => r
  }
}

///|
pub fn Class::is_unicode(self : Class) -> Bool {
  self is Unicode(_)
}

///|
pub fn Class::is_empty(self : Class) -> Bool {
  self.ranges().is_empty()
}

///|
pub fn Class::is_ascii(self : Class) -> Bool {
  ranges_is_ascii(self.ranges())
}

///|
pub fn Class::union(self : Class, other : Class) -> Class {
  match (self, other) {
    (Unicode(a), Unicode(b)) => Unicode(ranges_union(a, b))
    (Bytes(a), Bytes(b)) => Bytes(ranges_union(a, b))
    _ => abort("class kind mismatch")
  }
}

///|
pub fn Class::intersect(self : Class, other : Class) -> Class {
  match (self, other) {
    (Unicode(a), Unicode(b)) => Unicode(ranges_intersect(a, b))
    (Bytes(a), Bytes(b)) => Bytes(ranges_intersect(a, b))
    _ => abort("class kind mismatch")
  }
}

///|
pub fn Class::difference(self : Class, other : Class) -> Class {
  match (self, other) {
    (Unicode(a), Unicode(b)) => Unicode(ranges_difference(a, b, true))
    (Bytes(a), Bytes(b)) => Bytes(ranges_difference(a, b, false))
    _ => abort("class kind mismatch")
  }
}

///|
pub fn Class::symmetric_difference(self : Class, other : Class) -> Class {
  match (self, other) {
    (Unicode(a), Unicode(b)) => Unicode(ranges_symmetric_difference(a, b, true))
    (Bytes(a), Bytes(b)) => Bytes(ranges_symmetric_difference(a, b, false))
    _ => abort("class kind mismatch")
  }
}

///|
pub fn Class::negate(self : Class) -> Class {
  match self {
    Unicode(a) => Unicode(ranges_negate(a, true))
    Bytes(a) => Bytes(ranges_negate(a, false))
  }
}

///|
pub fn Class::case_fold_simple(self : Class) -> Class {
  match self {
    Unicode(a) => Unicode(ranges_case_fold_unicode(a))
    Bytes(a) => Bytes(ranges_case_fold_bytes(a))
  }
}

///|
/// Creates a Unicode class from arbitrary ranges.
pub fn Class::new_unicode(ranges : Array[(Int32, Int32)]) -> Class {
  Unicode(canonicalize_ranges(ranges))
}

///|
/// Creates a byte class from arbitrary ranges.
pub fn Class::new_bytes(ranges : Array[(Int32, Int32)]) -> Class {
  Bytes(canonicalize_ranges(ranges))
}

///|
/// Converts to a byte class if every range is ASCII.
pub fn Class::to_bytes(self : Class) -> Class? {
  match self {
    Bytes(_) => Some(self)
    Unicode(a) => if ranges_is_ascii(a) { Some(Bytes(a)) } else { None }
  }
}

///|
/// Converts to a Unicode class if every range is ASCII.
pub fn Class::to_unicode(self : Class) -> Class? {
  match self {
    Unicode(_) => Some(self)
    Bytes(a) => if ranges_is_ascii(a) { Some(Unicode(a)) } else { None }
  }
}

///|
/// Returns the number of bytes needed to encode the scalar value in UTF-8.
pub fn utf8_len(c : Int32) -> Int32 {
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
/// Encodes a scalar value as UTF-8 into the buffer.
pub fn encode_utf8(buf : Buffer, c : Int32) -> Unit {
  if c < 0x80 {
    buf.write_byte(c.to_byte())
  } else if c < 0x800 {
    buf.write_byte((0xC0 | (c >> 6)).to_byte())
    buf.write_byte((0x80 | (c & 0x3F)).to_byte())
  } else if c < 0x10000 {
    buf.write_byte((0xE0 | (c >> 12)).to_byte())
    buf.write_byte((0x80 | ((c >> 6) & 0x3F)).to_byte())
    buf.write_byte((0x80 | (c & 0x3F)).to_byte())
  } else {
    buf.write_byte((0xF0 | (c >> 18)).to_byte())
    buf.write_byte((0x80 | ((c >> 12) & 0x3F)).to_byte())
    buf.write_byte((0x80 | ((c >> 6) & 0x3F)).to_byte())
    buf.write_byte((0x80 | (c & 0x3F)).to_byte())
  }
}

///|
pub fn Class::minimum_len(self : Class) -> Int32? {
  match self {
    Unicode(a) => if a.is_empty() { None } else { Some(utf8_len(a[0].0)) }
    Bytes(a) => if a.is_empty() { None } else { Some(1) }
  }
}

///|
pub fn Class::maximum_len(self : Class) -> Int32? {
  match self {
    Unicode(a) =>
      if a.is_empty() {
        None
      } else {
        Some(utf8_len(a[a.length() - 1].1))
      }
    Bytes(a) => if a.is_empty() { None } else { Some(1) }
  }
}

///|
/// If this class matches exactly one character (or byte), returns its
/// encoding as a literal.
pub fn Class::literal(self : Class) -> Bytes? {
  match self {
    Unicode(a) =>
      if a.length() == 1 && a[0].0 == a[0].1 {
        let buf = Buffer()
        encode_utf8(buf, a[0].0)
        Some(buf.to_bytes())
      } else {
        None
      }
    Bytes(a) =>
      if a.length() == 1 && a[0].0 == a[0].1 {
        Some(Bytes::make(1, a[0].0.to_byte()))
      } else {
        None
      }
  }
}
