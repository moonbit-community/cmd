// Teddy: a SIMD multi-literal searcher (as in Rust's `aho-corasick`).
//
// Literals are assigned to 8 buckets. For each of the first `masks` (1 to 3)
// byte positions of a literal, two 16-entry tables map the low and high
// nibbles of a byte to the set of buckets with a literal having a byte with
// that nibble at that position. Shuffling the tables by the nibbles of 16
// haystack bytes at once, and AND-ing the results over all positions, gives
// for each of 16 starting positions the buckets that may match there, which
// are then verified.

///|
pub struct Teddy {
  priv lits : Array[FixedArray[Byte]]
  priv buckets : FixedArray[Array[Int32]]
  priv masks : Int32
  priv lo : FixedArray[Byte]
  priv hi : FixedArray[Byte]
  priv min_len : Int32
  priv scratch : FixedArray[Byte]
}

///|
/// The maximum number of literals Teddy is used for.
pub let teddy_max_literals : Int32 = 64

///|
/// Builds a Teddy searcher for `lits` (in priority order). Returns `None` if
/// there are no literals, too many, or an empty one.
pub fn Teddy::new(lits : Array[FixedArray[Byte]]) -> Teddy? {
  let n = lits.length()
  if n == 0 || n > teddy_max_literals || lits.iter().any(l => l.length() == 0) {
    return None
  }
  let mut min_len = lits[0].length()
  for l in lits {
    if l.length() < min_len {
      min_len = l.length()
    }
  }
  let masks = if min_len < 3 { min_len } else { 3 }
  // Literals sharing their first `masks` bytes go to the same bucket.
  let key = (l : FixedArray[Byte]) => {
    let mut k = 0
    for j in 0..<masks {
      k = (k << 8) | l[j].to_int()
    }
    k
  }
  let keys : Array[Int32] = []
  for l in lits {
    let k = key(l)
    if !keys.contains(k) {
      keys.push(k)
    }
  }
  keys.sort()
  let buckets : FixedArray[Array[Int32]] = FixedArray::makei(8, _ => [])
  for idx, l in lits {
    let pos = keys.search(key(l)).unwrap()
    buckets[pos * 8 / keys.length()].push(idx)
  }
  let lo = FixedArray::make(48, b'\x00')
  let hi = FixedArray::make(48, b'\x00')
  for b in 0..<8 {
    for idx in buckets[b] {
      let l = lits[idx]
      for k in 0..<masks {
        let c = l[k].to_int()
        let bit = 1 << b
        lo[k * 16 + (c & 15)] = (lo[k * 16 + (c & 15)].to_int() | bit).to_byte()
        hi[k * 16 + (c >> 4)] = (hi[k * 16 + (c >> 4)].to_int() | bit).to_byte()
      }
    }
  }
  // Unused positions match everything.
  for k in masks..<3 {
    for j in 0..<16 {
      lo[k * 16 + j] = b'\xff'
      hi[k * 16 + j] = b'\xff'
    }
  }
  Some({
    lits,
    buckets,
    masks,
    lo,
    hi,
    min_len,
    scratch: FixedArray::make(16, b'\x00'),
  })
}

///|
fn lit_at(lit : FixedArray[Byte], hay : FixedArray[Byte], at : Int32) -> Bool {
  for j in 0..<lit.length() {
    if hay[at + j] != lit[j] {
      return false
    }
  }
  true
}

///|
/// Verifies the literals in the buckets `bits` at `at`, returning the index
/// of the highest priority literal matching there (or `-1`).
fn Teddy::verify(
  self : Teddy,
  hay : FixedArray[Byte],
  end : Int32,
  at : Int32,
  bits : Int32,
) -> Int32 {
  let mut best = -1
  let mut bits = bits
  while bits != 0 {
    let b = bits.ctz()
    bits = bits & (bits - 1)
    for idx in self.buckets[b] {
      if best >= 0 && idx >= best {
        break
      }
      let lit = self.lits[idx]
      if at + lit.length() <= end && lit_at(lit, hay, at) {
        best = idx
        break
      }
    }
  }
  best
}

///|
/// Like `find`, but returns the span packed as `start << 32 | end`, or `-1`
/// if there is no match (without allocating).
pub fn Teddy::find_span(
  self : Teddy,
  hay : FixedArray[Byte],
  start : Int32,
  end : Int32,
) -> Int64 {
  let limit = end - self.min_len + 1
  let lo = self.lo
  let hi = self.hi
  // Offsets of the (up to 3) fingerprint positions; unused ones read
  // position 0 (in bounds) and their tables match everything.
  let o1 = if self.masks > 1 { 1 } else { 0 }
  let o2 = if self.masks > 2 { 2 } else { 0 }
  let mut i = start
  if limit - start >= LANES {
    let nib = @v128.i8x16_splat(b'\x0f')
    let zero = @v128.i8x16_splat(b'\x00')
    let lo0 = @v128.v128_load(lo, 0)
    let lo1 = @v128.v128_load(lo, 16)
    let lo2 = @v128.v128_load(lo, 32)
    let hi0 = @v128.v128_load(hi, 0)
    let hi1 = @v128.v128_load(hi, 16)
    let hi2 = @v128.v128_load(hi, 32)
    let scratch = self.scratch
    while i + LANES <= limit {
      let c0 = @v128.v128_load(hay, i)
      let c1 = @v128.v128_load(hay, i + o1)
      let c2 = @v128.v128_load(hay, i + o2)
      let r0 = @v128.v128_and_(
        @v128.i8x16_swizzle(lo0, @v128.v128_and_(c0, nib)),
        @v128.i8x16_swizzle(hi0, @v128.i8x16_shr_u(c0, 4)),
      )
      let r1 = @v128.v128_and_(
        @v128.i8x16_swizzle(lo1, @v128.v128_and_(c1, nib)),
        @v128.i8x16_swizzle(hi1, @v128.i8x16_shr_u(c1, 4)),
      )
      let r2 = @v128.v128_and_(
        @v128.i8x16_swizzle(lo2, @v128.v128_and_(c2, nib)),
        @v128.i8x16_swizzle(hi2, @v128.i8x16_shr_u(c2, 4)),
      )
      let res = @v128.v128_and_(r0, @v128.v128_and_(r1, r2))
      // A cheap "any candidate" test before computing the bitmask.
      if @v128.v128_any_true(res) {
        let mut m = @v128.i8x16_bitmask(@v128.i8x16_ne(res, zero))
        @v128.v128_store(scratch, 0, res)
        while m != 0 {
          let j = m.ctz()
          m = m & (m - 1)
          let idx = self.verify(hay, end, i + j, scratch[j].to_int())
          if idx >= 0 {
            return pack(i + j, i + j + self.lits[idx].length())
          }
        }
      }
      i += LANES
    }
  }
  while i < limit {
    let mut bits = 0xff
    for k in 0..<self.masks {
      let c = hay[i + k].to_int()
      bits = bits &
        lo[k * 16 + (c & 15)].to_int() &
        hi[k * 16 + (c >> 4)].to_int()
    }
    if bits != 0 {
      let idx = self.verify(hay, end, i, bits)
      if idx >= 0 {
        return pack(i, i + self.lits[idx].length())
      }
    }
    i += 1
  }
  -1L
}

///|
fn pack(start : Int32, end : Int32) -> Int64 {
  (start.to_int64() << 32) | end.to_int64()
}

///|
/// Returns the start and end of the leftmost occurrence of any literal in
/// `hay[start:end]`, preferring the literal with the highest priority among
/// those starting at the same position.
pub fn Teddy::find(
  self : Teddy,
  hay : FixedArray[Byte],
  start : Int32,
  end : Int32,
) -> (Int32, Int32)? {
  let sp = self.find_span(hay, start, end)
  if sp < 0L {
    None
  } else {
    Some(((sp >> 32).to_int(), (sp & 0xFFFFFFFFL).to_int()))
  }
}
