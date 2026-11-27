///|
// Strategy: exact-byte-membership

///|
/// Immutable exact membership for all byte values. The SIMD mask has one bit
/// per lane; callers retain their own loading, polarity and scalar-tail rules.
pub struct ByteMembership {
  priv low : V128
  priv high : V128
}

///|
pub fn ByteMembership::new(members : FixedArray[Bool]) -> ByteMembership {
  let low = FixedArray::make(16, b'\x00')
  let high = FixedArray::make(16, b'\x00')
  for byte in 0..<256 {
    if members[byte] {
      let table = if byte < 128 { low } else { high }
      table[byte & 15] = table[byte & 15] | (1 << ((byte >> 4) & 7)).to_byte()
    }
  }
  { low: @simd.v128_load(low, 0), high: @simd.v128_load(high, 0), }
}

///|
#inline
pub fn ByteMembership::mask(self : ByteMembership, bytes : V128) -> Int32 {
  let bits = @simd.i64x2_const(0x8040201008040201UL, 0x8040201008040201UL)
  let mask = @simd.i8x16_splat(b'\x0f')
  let zero = @simd.i8x16_splat(b'\x00')
  let indices = @simd.v128_and_(bytes, mask)
  let membership = @simd.v128_bitselect(
    @simd.i8x16_swizzle(self.high, indices),
    @simd.i8x16_swizzle(self.low, indices),
    @simd.i8x16_lt_s(bytes, zero),
  )
  let bit = @simd.i8x16_swizzle(bits, @simd.i8x16_shr_u(bytes, 4))
  @simd.i8x16_bitmask(@simd.i8x16_ne(@simd.v128_and_(membership, bit), zero))
}
