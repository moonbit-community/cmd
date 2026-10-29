///|
test "shared SIMD membership is exact for every singleton byte and both polarities" {
  let hay = FixedArray::makei(256, i => i.to_byte())
  for selected in 0..<256 {
    let members = FixedArray::makei(256, i => i == selected)
    let prepared = ByteMembership::new(members)
    members[selected] = false
    for group in 0..<16 {
      let mask = prepared.mask(@v128.v128_load(hay, group * 16))
      let expected = if selected / 16 == group {
        1 << (selected % 16)
      } else {
        0
      }
      assert_eq(mask, expected)
      assert_eq(mask ^ 65535, expected ^ 65535)
    }
  }
}
