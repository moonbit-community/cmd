///|
/// Count lines containing this literal. The literal must not contain `term`.
/// Pair-filter vectors and needle metadata stay live across all record hits.
pub fn Finder::count_lines(
  self : Finder,
  hay : FixedArray[Byte],
  start : Int32,
  end : Int32,
  term : Byte,
) -> Int64 {
  let n = self.needle.length()
  let limit = end - n + 1
  let mut pos = start
  let mut count = 0L
  if n >= 2 && limit - start >= 32 {
    let i1 = self.i1
    let i2 = self.i2
    let v1 = @simd.i8x16_splat(self.needle[i1])
    let v2 = @simd.i8x16_splat(self.needle[i2])
    while pos + 32 <= limit {
      let a = @simd.v128_and_(
        @simd.i8x16_eq(@simd.v128_load(hay, pos + i1), v1),
        @simd.i8x16_eq(@simd.v128_load(hay, pos + i2), v2),
      )
      let b = @simd.v128_and_(
        @simd.i8x16_eq(@simd.v128_load(hay, pos + 16 + i1), v1),
        @simd.i8x16_eq(@simd.v128_load(hay, pos + 16 + i2), v2),
      )
      let mut next = pos + 32
      if @simd.v128_any_true(@simd.v128_or_(a, b)) {
        let mut mask = @simd.i8x16_bitmask(a) | (@simd.i8x16_bitmask(b) << 16)
        while mask != 0 {
          let at = pos + mask.ctz()
          if self.verify(hay, at) {
            count += 1L
            let boundary = memchr(term, hay, at + n, end)
            if boundary < 0 {
              return count
            }
            next = boundary + 1
            break
          }
          mask = mask & (mask - 1)
        }
      }
      pos = next
    }
  }
  while pos < end {
    let at = self.find(hay, pos, end)
    if at < 0 {
      break
    }
    count += 1L
    let boundary = memchr(term, hay, at + n, end)
    if boundary < 0 {
      break
    }
    pos = boundary + 1
  }
  count
}
