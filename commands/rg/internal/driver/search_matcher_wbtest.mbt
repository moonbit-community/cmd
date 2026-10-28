///|
fn is_match(m : SearchMatcher, hay : Bytes) -> Bool {
  let h = hay.to_fixedarray()
  @matcher.is_match_at(m, h, 0, h.length(), 0)
}

///|
test "word" {
  let m = SearchMatcher::new(["-2"], boundary=Some(Word))
  inspect(is_match(m, b"abc -2 foo"), content="true")
  let m = SearchMatcher::new(["\\b-2\\b"])
  inspect(is_match(m, b"abc -2 foo"), content="false")
}

///|
test "line terminator" {
  let m = SearchMatcher::new(["abc\\sxyz"])
  inspect(is_match(m, b"abc\nxyz"), content="true")
  let m = SearchMatcher::new(
    ["abc\\sxyz"],
    line_terminator=Some(b'\n').map(@matcher.LineTerminator::byte),
  )
  inspect(is_match(m, b"abc\nxyz"), content="false")
  let r = try
    SearchMatcher::new(
      ["a\\nz"],
      line_terminator=Some(b'\n').map(@matcher.LineTerminator::byte),
    )
  catch {
    e => e.to_string()
  } noraise {
    _ => "ok"
  }
  inspect(r, content="the literal \"\\n\" is not allowed in a regex")
}

///|
test "line terminator crlf" {
  let m = SearchMatcher::new(["abc$"], multi_line=true)
  inspect(is_match(m, b"abc\n"), content="true")
  inspect(is_match(m, b"abc\r\n"), content="false")
  let m = SearchMatcher::new(
    ["abc$"],
    multi_line=true,
    crlf=true,
    line_terminator=Some(@matcher.LineTerminator::crlf()),
  )
  inspect(is_match(m, b"abc\r\n"), content="true")
}

///|
test "case smart" {
  let m = SearchMatcher::new(["abc"], case_mode=Smart)
  inspect(is_match(m, b"ABC"), content="true")
  let m = SearchMatcher::new(["aBc"], case_mode=Smart)
  inspect(is_match(m, b"ABC"), content="false")
}

///|
test "candidate lines" {
  let m = SearchMatcher::new(["\\wfoo\\s"])
  let h = b"afoo ".to_fixedarray()
  debug_inspect(
    @matcher.Matcher::find_candidate_line(m, h, 0, h.length()),
    content="Some(Confirmed(5))",
  )
  let m = SearchMatcher::new(
    ["\\wfoo\\s"],
    line_terminator=Some(b'\n').map(@matcher.LineTerminator::byte),
  )
  debug_inspect(
    @matcher.Matcher::find_candidate_line(m, h, 0, h.length()),
    content="Some(Candidate(4))",
  )
}

///|
test "find iter and captures" {
  let m = SearchMatcher::new(["(?P<w>\\w+)@(\\d)"])
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
    let m = SearchMatcher::new([pat], boundary=Some(Word))
    assert_true(@matcher.Matcher::find_at(m, hay, 0, hay.length(), 0) is None)
  }
}
