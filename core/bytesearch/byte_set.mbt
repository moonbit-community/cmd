///|
/// Exact SIMD candidate lookup for an immutable set of 256 byte memberships.
pub struct ByteSetFinder {
  priv members : FixedArray[Bool]
  priv low : V128
  priv high : V128
}

///|
pub fn ByteSetFinder::new(members : FixedArray[Bool]) -> ByteSetFinder {
  let low = FixedArray::make(16, b'\x00')
  let high = FixedArray::make(16, b'\x00')
  for byte in 0..<256 {
    if members[byte] {
      let table = if byte < 128 { low } else { high }
      table[byte & 15] = table[byte & 15] | (1 << ((byte >> 4) & 7)).to_byte()
    }
  }
  {
    members: FixedArray::makei(256, i => members[i]),
    low: @v128.v128_load(low, 0),
    high: @v128.v128_load(high, 0),
  }
}

///|
pub fn ByteSetFinder::contains(self : ByteSetFinder, byte : Byte) -> Bool {
  self.members[byte.to_int()]
}

///|
pub fn ByteSetFinder::find(
  self : ByteSetFinder,
  hay : FixedArray[Byte],
  start : Int32,
  end : Int32,
) -> Int32 {
  let bits = @v128.i64x2_const(0x8040201008040201UL, 0x8040201008040201UL)
  let mask = @v128.i8x16_splat(b'\x0f')
  let zero = @v128.i8x16_splat(b'\x00')
  let mut pos = start
  while end - pos >= 16 {
    let bytes = @v128.v128_load(hay, pos)
    let indices = @v128.v128_and_(bytes, mask)
    let membership = @v128.v128_bitselect(
      @v128.i8x16_swizzle(self.high, indices),
      @v128.i8x16_swizzle(self.low, indices),
      @v128.i8x16_lt_s(bytes, zero),
    )
    let bit = @v128.i8x16_swizzle(bits, @v128.i8x16_shr_u(bytes, 4))
    let hits = @v128.i8x16_bitmask(
      @v128.i8x16_ne(@v128.v128_and_(membership, bit), zero),
    )
    if hits != 0 {
      return pos + hits.ctz()
    }
    pos += 16
  }
  while pos < end {
    if self.members[hay[pos].to_int()] {
      return pos
    }
    pos += 1
  }
  -1
}
