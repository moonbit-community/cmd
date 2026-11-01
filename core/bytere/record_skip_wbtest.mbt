///|
test "certified SIMD membership covers every byte and nonzero view offsets" {
  for seed in 0..<16 {
    let members = FixedArray::makei(256, byte => {
      (byte * 37 + seed * 19) % 17 < 13
    })
    let plan = RecordSkip::new(members)
    for byte in 0..<256 {
      let data = Bytes::makei(65, index => {
        if index == 19 {
          byte.to_byte()
        } else {
          (seed * 13 % 256).to_byte()
        }
      })
      for start in [0, 1, 3] {
        let value = data[start:]
        let skipped = plan.advance(value, 0)
        assert_true(skipped <= value.length())
        for b in value[:skipped] {
          assert_true(members[b.to_int()])
        }
        if value.length() - skipped >= 16 {
          assert_true(!members[value[skipped].to_int()])
        }
      }
    }
  }
}

///|
test "certified skips preserve boolean matching for reused states long tails and all byte classes" {
  for
    source in [
      "[0-9]{4}.*Q|ZZ", "a+b", "a.*b", "(ab|cd)+Z", "a?b*", "[a-z]+[0-9]", "[^x]+Z",
      "[[:alpha:]]{3}.*!",
    ] {
    let pattern = compile(source, extended=true)
    let dfa = RecordDfa::new(pattern).unwrap()
    for
      data in [
        b"",
        Bytes::make(4096, b'a'),
        b"1234" + Bytes::make(4097, b'a') + b"Q",
        b"1234" + Bytes::make(4097, b'a') + b"X",
        Bytes::makei(4096, i => (i % 256).to_byte()),
        Bytes::makei(4096, i => ((i * 37 + 71) % 256).to_byte()),
        b"headZZtail",
      ] {
      let expected = pattern.find_span(text(data[:])) is Some(_)
      assert_eq(dfa.matches_accelerated(data[:]), Some(expected), msg=source)
      assert_eq(dfa.matches(data[:]), Some(expected), msg=source)
    }
    assert_true(dfa.skip_budget >= 0)
  }
}
