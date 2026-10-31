///|
test "block boolean counts agree with independent record matching and ignore incomplete tails" {
  for
    source in [
      "", "a", "a.*b", "[0-9]{4}.*Q|ZZ", "(ab|cd)+Z", "[^x]+Z", "(a|b)*a(a|b){8}",
      "^a", "(a|b)\\1",
    ] {
    for separator in [b'\n', b'\x00', b'a'] {
      let pattern = @bytere.compile(source, extended=true)
      let matcher = pattern.record_matcher()
      for
        data in [
          b"",
          b"a\n\nZ\x00a",
          Bytes::make(4097, b'a') + b"b\n",
          Bytes::makei(4097, i => (i % 256).to_byte()),
          b"1234Q\nZZ\npartial",
        ] {
        let mut start = 0
        let mut matched = 0
        let mut records = 0
        for i in 0..<data.length() {
          if data[i] == separator {
            if pattern.record_matcher().matches(data[start:i]) {
              matched += 1
            }
            records += 1
            start = i + 1
          }
        }
        if matcher.count_records(data[:], separator) is Some(counts) {
          assert_eq(counts, (matched, records), msg=source)
        } else {
          assert_true(
            source == "^a" ||
            source == "(a|b)\\1" ||
            source == "(a|b)*a(a|b){8}",
            msg=source,
          )
        }
      }
    }
  }
}
