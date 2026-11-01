///|
priv struct RecordSkip {
  membership : @bytesearch.ByteMembership
}

///|
// Two nibble tables encode all 256 membership bits exactly. Unlike a hashed
// filter, every accepted lane certifies an actual self-loop of this DFA row.
fn RecordSkip::new(members : FixedArray[Bool]) -> RecordSkip {
  { membership: @bytesearch.ByteMembership::new(members), }
}

///|
fn RecordSkip::advance(
  self : RecordSkip,
  data : BytesView,
  start : Int32,
) -> Int32 {
  let membership = self.membership
  let mut pos = start
  while data.length() - pos >= 16 {
    let bytes = @v128.i64x2_replace_lane(
      @v128.i64x2_splat(data.unsafe_read_uint64_le(pos)),
      data.unsafe_read_uint64_le(pos + 8),
      1,
    )
    let exits = membership.mask(bytes) ^ 65535
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
