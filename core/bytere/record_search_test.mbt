///|
test "byte searches preserve resumed offsets and fallback decoding" {
  for
    (source, extended) in [
      ("a|aa", true),
      ("^aa|a$", true),
      ("\\(a\\)\\1", false),
    ] {
    let pattern = @bytere.compile(source, extended~)
    let matcher = pattern.record_matcher()
    let storage = b"prefix\xffaaa\x00a!suffix"
    let value = storage[6:13]
    let search = matcher.search_bytes(value)
    for start in -1..<=(value.length() + 1) {
      assert_eq(
        search.find_span(start~),
        pattern.find_span(@bytere.text(value), start~),
      )
    }
  }
}

///|
test "byte searches retain every byte under ASCII folding" {
  for source in ["[[:alpha:]]+", "A+b", "[^a]*", "\u00ff+"] {
    let pattern = @bytere.compile(source, extended=true, ignore_case=true)
    let matcher = pattern.record_matcher()
    for first in 0..<256 {
      let input = Bytes::from_array([first.to_byte(), b'b', b'\x00'])
      assert_eq(
        matcher.search_bytes(input).find_span(),
        pattern.find_span(@bytere.text(input)),
      )
    }
  }
}

///|
test "endpoint search chooses earliest start even when it accepts later" {
  for source in ["a.*z|b", "ab|a", "a.*z|a", "(a|aa)*", "(a|b)*a(a|b){9}"] {
    let pattern = @bytere.compile(source, extended=true)
    let matcher = pattern.record_matcher()
    for input in [b"abz", b"abzb", b"aaa", b"aaabaaababa", b"", b"zaaaaazb"] {
      let search = matcher.search_bytes(input)
      for start in 0..<=input.length() {
        assert_eq(
          search.find_span(start~),
          pattern.find_span(@bytere.text(input), start~),
        )
      }
    }
  }
}

///|
test "shared byte searches keep independent pattern and resume state" {
  let patterns = [
    @bytere.compile("a+$", extended=true).record_matcher(),
    @bytere.compile("\\(a\\)\\1").record_matcher(),
  ]
  let searches = @bytere.search_bytes(patterns, b"zaaa")
  assert_eq(searches[0].find_span(), Some((1, 4)))
  assert_eq(searches[1].find_span(), Some((1, 3)))
  assert_eq(searches[1].find_span(start=2), Some((2, 4)))
  assert_eq(searches[0].find_span(start=2), Some((2, 4)))
  assert_true(@bytere.search_bytes([], b"anything").is_empty())
}
