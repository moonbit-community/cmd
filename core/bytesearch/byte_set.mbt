///|
/// Exact SIMD candidate lookup for an immutable set of 256 byte memberships.
pub struct ByteSetFinder {
  priv members : FixedArray[Bool]
  priv membership : ByteMembership
}

///|
pub fn ByteSetFinder::new(members : FixedArray[Bool]) -> ByteSetFinder {
  {
    members: FixedArray::makei(256, i => members[i]),
    membership: ByteMembership::new(members),
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
  let membership = self.membership
  let mut pos = start
  while end - pos >= 16 {
    let bytes = @v128.v128_load(hay, pos)
    let hits = membership.mask(bytes)
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
