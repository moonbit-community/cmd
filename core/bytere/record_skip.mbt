///|
priv struct RecordSkip {
  low : V128
  high : V128
}

///|
// Two nibble tables encode all 256 membership bits exactly. Unlike a hashed
// filter, every accepted lane certifies an actual self-loop of this DFA row.
fn RecordSkip::new(members : FixedArray[Bool]) -> RecordSkip {
  let low = FixedArray::make(16, b'\x00')
  let high = FixedArray::make(16, b'\x00')
  for byte in 0..<256 {
    if members[byte] {
      let table = if byte < 128 { low } else { high }
      table[byte & 15] = table[byte & 15] | (1 << ((byte >> 4) & 7)).to_byte()
    }
  }
  { low: @v128.v128_load(low, 0), high: @v128.v128_load(high, 0), }
}

///|
fn RecordSkip::advance(
  self : RecordSkip,
  data : BytesView,
  start : Int32,
) -> Int32 {
  let bits = @v128.i64x2_const(0x8040201008040201UL, 0x8040201008040201UL)
  let mask = @v128.i8x16_splat(b'\x0f')
  let zero = @v128.i8x16_splat(b'\x00')
  let mut pos = start
  while data.length() - pos >= 16 {
    let bytes = @v128.i64x2_replace_lane(
      @v128.i64x2_splat(data.unsafe_read_uint64_le(pos)),
      data.unsafe_read_uint64_le(pos + 8),
      1,
    )
    let indices = @v128.v128_and_(bytes, mask)
    let membership = @v128.v128_bitselect(
      @v128.i8x16_swizzle(self.high, indices),
      @v128.i8x16_swizzle(self.low, indices),
      @v128.i8x16_lt_s(bytes, zero),
    )
    let bit = @v128.i8x16_swizzle(bits, @v128.i8x16_shr_u(bytes, 4))
    let exits = @v128.i8x16_bitmask(
      @v128.i8x16_eq(@v128.v128_and_(membership, bit), zero),
    )
    if exits != 0 {
      return pos + exits.ctz()
    }
    pos += 16
  }
  pos
}

///|
fn RecordDfa::skip_plan(self : RecordDfa, row : Int32) -> RecordSkip? {
  let id = row / self.representatives.length()
  if self.skip_planned[id] {
    return self.skip_plans[id]
  }
  self.skip_planned[id] = true
  if self.skip_budget == 0 {
    return None
  }
  self.skip_budget -= 1
  for class in 0..<self.representatives.length() {
    if self.transition(row, class) == -3 {
      return None
    }
  }
  let members = FixedArray::makei(256, byte => {
    self.edges[row + self.classes[byte]] == row
  })
  if members.iter().filter(x => x).count() < 128 {
    return None
  }
  let plan = RecordSkip::new(members)
  self.skip_plans[id] = Some(plan)
  Some(plan)
}
