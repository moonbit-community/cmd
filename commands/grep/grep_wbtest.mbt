///|
test "record splitting preserves content and byte offsets" {
  let records = split_records(b"zero\nneedle\n", b'\n')
  assert_eq(records.length(), 2)
  assert_eq(records[0].data, b"zero")
  assert_eq(records[1].data, b"needle")
  assert_eq(records[1].offset, 5L)
}

///|
test "fixed matcher accepts byte-decoded records" {
  let matcher = Matcher::Fixed(["needle"], false, false)
  let decoded = bytes_as_string(b"needle")
  assert_eq(decoded, "needle")
  assert_true(matcher.matches(decoded, false))
}

///|
test "BRE operators are literal until escaped and ERE operators are active" {
  let basic = Regex(translate_regexp("a+b", false))
  assert_true(basic.execute("a+b") is Some(_))
  assert_true(basic.execute("aaab") is None)
  assert_true(
    Regex(translate_regexp("a\\+b", false)).execute("aaab") is Some(_),
  )
  assert_true(Regex(translate_regexp("a+b", true)).execute("aaab") is Some(_))
  assert_true(Regex(translate_regexp("a\\+b", true)).execute("a+b") is Some(_))
  assert_true(
    Regex(translate_regexp("\\(ab\\)\\{2\\}", false)).execute("abab") is Some(_),
  )
}

///|
test "only matching chooses leftmost longest across alternatives and patterns" {
  let regex = Matcher::Regular(Some(Regex("a|aa")), false, false)
  assert_eq(regex.next_match("zaaa", 0), Some((1, 3)))
  assert_eq(regex.next_match("zaaa", 3), Some((3, 4)))
  let fixed = Matcher::Fixed(["a", "aa"], false, false)
  assert_eq(fixed.next_match("zaaa", 0), Some((1, 3)))
}

///|
test "only matching preserves anchors and word boundaries on resumed searches" {
  let anchored = Matcher::Regular(Some(Regex("^a|b$")), false, false)
  assert_eq(anchored.next_match("aaab", 0), Some((0, 1)))
  assert_eq(anchored.next_match("aaab", 1), Some((3, 4)))
  let words = Matcher::Regular(Some(Regex("a|aa")), false, true)
  assert_eq(words.next_match("za aa a!", 0), Some((3, 5)))
  assert_eq(words.next_match("za aa a!", 5), Some((6, 7)))
}

///|
test "unsupported backreferences fail before matching" {
  let failed = try {
    ignore(translate_regexp("\\(a\\)\\1", false))
    false
  } catch {
    _ => true
  }
  assert_true(failed)
}
