///|
fn is_match(m : @grep_regex.RegexMatcher, hay : Bytes) -> Bool {
  let h = hay.to_fixedarray()
  @matcher.is_match_at(m, h, 0, h.length(), 0)
}

///|
test "word" {
  let m = @grep_regex.RegexMatcherBuilder::new().word(true).build("-2")
  inspect(is_match(m, b"abc -2 foo"), content="true")
  let m = @grep_regex.RegexMatcherBuilder::new().word(false).build("\\b-2\\b")
  inspect(is_match(m, b"abc -2 foo"), content="false")
}

///|
test "line terminator" {
  let m = @grep_regex.RegexMatcherBuilder::new().build("abc\\sxyz")
  inspect(is_match(m, b"abc\nxyz"), content="true")
  let m = @grep_regex.RegexMatcherBuilder::new()
    .line_terminator(Some(b'\n'))
    .build("abc\\sxyz")
  inspect(is_match(m, b"abc\nxyz"), content="false")
  let r = try
    @grep_regex.RegexMatcherBuilder::new()
    .line_terminator(Some(b'\n'))
    .build("a\\nz")
  catch {
    e => e.to_string()
  } noraise {
    _ => "ok"
  }
  inspect(r, content="the literal \"\\n\" is not allowed in a regex")
}

///|
test "line terminator crlf" {
  let m = @grep_regex.RegexMatcherBuilder::new().multi_line(true).build("abc$")
  inspect(is_match(m, b"abc\n"), content="true")
  inspect(is_match(m, b"abc\r\n"), content="false")
  let m = @grep_regex.RegexMatcherBuilder::new()
    .multi_line(true)
    .crlf(true)
    .build("abc$")
  inspect(is_match(m, b"abc\r\n"), content="true")
}

///|
test "case smart" {
  let m = @grep_regex.RegexMatcherBuilder::new().case_smart(true).build("abc")
  inspect(is_match(m, b"ABC"), content="true")
  let m = @grep_regex.RegexMatcherBuilder::new().case_smart(true).build("aBc")
  inspect(is_match(m, b"ABC"), content="false")
}

///|
test "candidate lines" {
  let m = @grep_regex.RegexMatcherBuilder::new().build("\\wfoo\\s")
  let h = b"afoo ".to_fixedarray()
  debug_inspect(
    @matcher.Matcher::find_candidate_line(m, h, 0, h.length()),
    content="Some(Confirmed(5))",
  )
  let m = @grep_regex.RegexMatcherBuilder::new()
    .line_terminator(Some(b'\n'))
    .build("\\wfoo\\s")
  debug_inspect(
    @matcher.Matcher::find_candidate_line(m, h, 0, h.length()),
    content="Some(Candidate(4))",
  )
}

///|
test "find iter and captures" {
  let m = @grep_regex.RegexMatcher::new("(?P<w>\\w+)@(\\d)")
  let h = b"xx foo@1 bar@2".to_fixedarray()
  let found = []
  @matcher.find_iter(m, h, 0, h.length(), mat => {
    found.push(mat)
    true
  })
  debug_inspect(found, content="[{ start: 3, end: 8 }, { start: 9, end: 14 }]")
  let caps = @matcher.Matcher::new_captures(m)
  debug_inspect(@matcher.Matcher::capture_index(m, "w"), content="Some(1)")
  inspect(
    @matcher.Matcher::captures_at(m, h, 0, h.length(), 4, caps),
    content="true",
  )
  debug_inspect(caps.get(1), content="Some({ start: 4, end: 6 })")
  let dst = Buffer()
  @matcher.replace_with_captures_at(m, h, 0, h.length(), 0, caps, dst, (
    caps,
    dst,
  ) => {
    caps.interpolate(
      name => @matcher.Matcher::capture_index(m, name),
      h,
      0,
      b"[$2:$w]",
      dst,
    )
    true
  })
  inspect(@utf8.decode_lossy(dst.to_bytes()), content="xx [1:foo] [2:bar]")
}

///|
test "word mode never matches inside a codepoint" {
  // `-w` wraps the pattern in Unicode half word boundaries, which must not
  // match next to invalid UTF-8 (e.g. between the bytes of "é").
  let hay = b"\xC3\xA9".to_fixedarray()
  for pat in ["", "(?-u:.)"] {
    let m = @grep_regex.RegexMatcherBuilder::new().word(true).build(pat)
    assert_true(@matcher.Matcher::find_at(m, hay, 0, hay.length(), 0) is None)
  }
}
