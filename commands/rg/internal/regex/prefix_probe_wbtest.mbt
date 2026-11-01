///|
test "byte prefix proof covers absent present and bounded spans" {
  let re = Regex::new("[0-9]{4}.*gamma")
  assert_true(re.pre is Some(@automata.Prefilter::ByteSet(_)))
  let hay = b"xxxx gamma\n0001 gamma\n".to_fixedarray()
  assert_eq(re.byte_prefix_start(hay, 0, hay.length()), Some(11))
  assert_eq(re.byte_prefix_start(hay, 0, 11), Some(-1))
  assert_eq(re.byte_prefix_start(hay, 12, 15), Some(12))
  assert_eq(re.byte_prefix_start(hay, 15, hay.length()), Some(-1))
  for pattern in ["", "a*", ".*gamma", "gamma", "^gamma"] {
    let regex = Regex::new(pattern)
    assert_eq(regex.byte_prefix_start(hay, 0, hay.length()), None)
  }
}
