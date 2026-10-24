///|
test "byte regex conversion is reversible for all byte values" {
  let data = Bytes::makei(256, i => i.to_byte())
  assert_eq(@bytere.bytes(@bytere.text(data)), data)
}

///|
test "byte regex is leftmost longest and captures BRE groups" {
  let basic = @bytere.compile("a\\|ab")
  let hit = basic.find("zabc").unwrap()
  assert_eq(hit.start, 1)
  assert_eq(hit.end, 3)
  let capture = @bytere.compile("a\\(b.*\\)").find("abc").unwrap()
  assert_eq(capture.groups[1], Some("bc"))
  assert_eq(@bytere.compile("a+", extended=false).find("a+").unwrap().end, 2)
  assert_eq(@bytere.compile("a+", extended=true).find("aaa").unwrap().end, 3)
}

///|
test "byte regex captures follow GNU sed 4.9 alternative order" {
  assert_eq(
    @bytere.compile("\\(foo\\|bar\\)[0-9]*").find("foo12").unwrap().groups[1],
    Some("foo"),
  )
  assert_eq(
    @bytere.compile("\\(a\\|aa\\)").find("aa").unwrap().groups[1],
    Some("aa"),
  )
  assert_eq(
    @bytere.compile("\\(a\\|aa\\)\\(a*\\)").find("aa").unwrap().groups[1],
    Some("a"),
  )
}

///|
test "byte regex parses repetition and branch anchor spelling once" {
  assert_eq(@bytere.compile("ab\\{2,3\\}c").find_span("abbbc"), Some((0, 5)))
  assert_eq(
    @bytere.compile("ab{2,3}c", extended=true).find_span("abbc"),
    Some((0, 4)),
  )
  assert_eq(@bytere.compile("a\\{,2\\}").find_span("aaa"), Some((0, 2)))
  assert_eq(@bytere.compile("a\\{0\\}").find_span("b"), Some((0, 0)))
  assert_eq(
    @bytere.compile("a{b", extended=true, grep_syntax=true).find_span("a{b"),
    Some((0, 3)),
  )
  assert_eq(@bytere.compile("*a").find_span("*a"), Some((0, 2)))
  assert_eq(@bytere.compile("a^b$c").find_span("a^b$c"), Some((0, 5)))
  let anchored = @bytere.compile("^a\\|b$")
  assert_eq(anchored.find_span("ab", start=1), Some((1, 2)))
  assert_eq(@bytere.compile("^a").find_span("aa", start=1), None)
  assert_eq(@bytere.compile("$").find_span("a\n"), Some((2, 2)))
  assert_eq(@bytere.compile(".").find_span("\n"), Some((0, 1)))
  assert_eq(@bytere.compile("\\n").find_span("n"), Some((0, 1)))
  assert_eq(@bytere.compile("\\t").find_span("t"), Some((0, 1)))
  assert_eq(@bytere.compile("\\\\n").find_span("\\n"), Some((0, 2)))
  assert_eq(
    @bytere.compile("a{2x}", extended=true, grep_syntax=true).find_span("a{2x}"),
    Some((0, 5)),
  )
  assert_eq(
    @bytere.compile("(a))", extended=true, grep_syntax=true).find_span("a)"),
    Some((0, 2)),
  )
  assert_eq(
    @bytere.compile(")", extended=true, grep_syntax=true).find_span("a)b"),
    Some((1, 2)),
  )
}

///|
test "byte regex C classes and bracket bytes include no Unicode folding" {
  let all = @bytere.text(Bytes::makei(256, i => i.to_byte()))
  assert_eq(@bytere.compile("[[:alpha:]]\\+").find_span(all), Some((65, 91)))
  assert_eq(@bytere.compile("[[:space:]]\\+").find_span(all), Some((9, 14)))
  assert_eq(@bytere.compile("[[:cntrl:]]\\+").find_span(all), Some((0, 32)))
  assert_eq(
    @bytere.compile("[[:xdigit:]]\\+").find_span("xyAF09z"),
    Some((2, 6)),
  )
  assert_eq(@bytere.compile("[]a-]\\+").find_span("-a]z"), Some((0, 3)))
  assert_eq(@bytere.compile("[[.a.]-c]").find_span("b"), Some((0, 1)))
  assert_eq(@bytere.compile("[[=a=]]").find_span("a"), Some((0, 1)))
  assert_eq(
    @bytere.compile("[^[:print:]]").find_span(@bytere.text(b"\xff")),
    Some((0, 1)),
  )
  assert_eq(
    @bytere.compile("[[:alpha:]]").find_span(@bytere.text(b"\xe9")),
    None,
  )
  assert_eq(@bytere.compile("[\\]").find_span("\\"), Some((0, 1)))
}

///|
test "byte regex directional and nondirectional word assertions use record context" {
  assert_eq(@bytere.compile("\\<foo\\>").find_span("_foo foo!"), Some((5, 8)))
  assert_eq(@bytere.compile("\\bfoo\\b").find_span("foo_ foo"), Some((5, 8)))
  assert_eq(@bytere.compile("\\Boo\\B").find_span("food"), Some((1, 3)))
  assert_eq(@bytere.compile("\\B").find_span(""), Some((0, 0)))
  assert_eq(@bytere.compile("\\b").find_span(""), None)
  assert_eq(@bytere.compile("\\w\\+\\s\\W").find_span("ab_ !"), Some((0, 5)))
  assert_eq(
    @bytere.compile("\\<foo").find_span("xfoo foo", start=2),
    Some((5, 8)),
  )
}

///|
test "byte regex backreferences retain distinct capture states" {
  let repeated = @bytere.compile("\\(a\\|ab\\)\\1")
  let hit = repeated.find("zabab").unwrap()
  assert_eq((hit.start, hit.end), (1, 5))
  assert_eq(hit.groups, [Some("abab"), Some("ab")])
  assert_eq(
    @bytere.compile("^(a|aa)\\1$", extended=true).find_span("aaaa"),
    Some((0, 4)),
  )
  assert_eq(@bytere.compile("(a)?b\\1", extended=true).find_span("b"), None)
  assert_eq(
    @bytere.compile("()\\1", extended=true).find_span("x"),
    Some((0, 0)),
  )
  assert_eq(
    @bytere.compile("(a*)b\\1", extended=true).find_span("aabaa"),
    Some((0, 5)),
  )
  assert_eq(
    @bytere.compile("(a|b)*\\1", extended=true).find_span("abb"),
    Some((0, 3)),
  )
  let raw = @bytere.text(b"\x00\xff\x00\xff")
  assert_eq(
    @bytere.compile("(..)\\1", extended=true).find_span(raw),
    Some((0, 4)),
  )
  assert_eq(
    @bytere.compile("(a*)*\\1", extended=true).find("a").unwrap().groups,
    [Some("a"), Some("")],
  )
  assert_eq(
    @bytere.compile("(a*)*\\1", extended=true).find("aa").unwrap().groups,
    [Some("aa"), Some("a")],
  )
  assert_eq(
    @bytere.compile("(a*)*\\1", extended=true).find("aaaa").unwrap().groups,
    [Some("aaaa"), Some("aa")],
  )
  assert_eq(
    @bytere.compile("(a|aa)*\\1", extended=true).find("aaaa").unwrap().groups,
    [Some("aaaa"), Some("a")],
  )
  assert_eq(
    @bytere.compile("^(a|aa)(a*)\\1$", extended=true).find("aaaa").unwrap().groups,
    [Some("aaaa"), Some("a"), Some("aa")],
  )
  // GNU reports the previous non-empty optional capture after an empty final
  // iteration; the reference itself used that iteration's raw empty span.
  let optional = @bytere.compile("(a?)*\\1", extended=true)
  assert_eq(optional.find("").unwrap().groups, [Some(""), Some("")])
  assert_eq(optional.find("a").unwrap().groups, [Some("a"), Some("a")])
  assert_eq(optional.find("aa").unwrap().groups, [Some("aa"), Some("a")])
  assert_eq(optional.find("aaaa").unwrap().groups, [Some("aaaa"), Some("a")])
  assert_eq(optional.find_span("a"), Some((0, 1)))
}

///|
test "cloned nullable captures follow GNU candidate selection" {
  for source in ["(a*){0,2}\\1", "(a*){2,}\\1"] {
    let pattern = @bytere.compile(source, extended=true)
    for input in ["", "a", "aa", "aaaa", "baab"] {
      assert_true(pattern.find(input) is None, msg=source + " on " + input)
      assert_eq(
        pattern.find_span(input),
        None,
        msg=source + " span on " + input,
      )
    }
  }
  for
    (source, input, expected) in [
      ("(a*){1,2}\\1", "aaa", [Some("aa"), Some("a")]),
      ("(a?){2}\\1", "aaaa", [Some("aaa"), Some("a")]),
      ("(a*){1,2}(a*){1,2}\\1\\2", "aaa", [Some("aaa"), Some(""), Some("a")]),
      ("(a*){1,2}(a*){1,2}\\1\\2", "abb", [Some(""), Some(""), Some("")]),
    ] {
    assert_eq(
      @bytere.compile(source, extended=true).find(input).unwrap().groups,
      expected,
      msg=source,
    )
  }
  assert_eq(
    @bytere.compile("(a?){0,2}(a?){1,2}\\1\\2", extended=true).find_span("aaaa"),
    None,
  )
  let repeated = @bytere.compile("(a|b?){2}\\1", extended=true)
  assert_eq(repeated.find("abb").unwrap().groups, [Some("abb"), Some("b")])
  assert_eq(repeated.find_span("xabb"), None)
  assert_eq(
    @bytere.compile("(a|b?){2}\\1$", extended=true).find_span("xabb"),
    Some((1, 4)),
  )
  let anchored = @bytere.compile("^(a*){1,2}(a*){1,2}\\1\\2$", extended=true)
  assert_eq(anchored.find_span(""), None)
  assert_eq(anchored.find_span("a"), Some((0, 0)))
  assert_eq(anchored.find_span("a", whole=true), None)
}

///|
test "byte regex counted capture controls agree with GNU" {
  for
    (source, input, expected) in [
      ("(a){2}\\1", "aaa", Some((0, 3))),
      ("(a+){2}\\1", "aaaaaa", None),
      ("(a(b?)){2}\\1", "aaa", Some((0, 3))),
      ("(a*){0,1}\\1", "aaaa", Some((0, 4))),
      ("(a*){1}\\1", "aaaa", Some((0, 4))),
      ("(a*)*\\1", "aaaa", Some((0, 4))),
      ("(a?)*\\1", "a", Some((0, 1))),
      ("(){0}\\1", "", None),
    ] {
    assert_eq(
      @bytere.compile(source, extended=true).find_span(input),
      expected,
      msg=source,
    )
  }
  assert_eq(
    @bytere.compile("((a*){2})\\1", extended=true).find("aa").unwrap().groups,
    [Some("aa"), Some("a"), Some("")],
  )
  assert_eq(
    @bytere.compile("^(a){2}\\1$", extended=true, ignore_case=true)
    .find("aAA")
    .unwrap().groups,
    [Some("aAA"), Some("A")],
  )
}

///|
test "byte regex repeated groups retain GNU empty iteration captures" {
  assert_eq(
    @bytere.compile("((a*)*){2}", extended=true).find("aa").unwrap().groups,
    [Some("aa"), Some(""), Some("")],
  )
  assert_eq(
    @bytere.compile("(a*)*", extended=true).find("aa").unwrap().groups[1],
    Some("aa"),
  )
  assert_eq(
    @bytere.compile("(a*)*", extended=true).find("x").unwrap().groups[1],
    Some(""),
  )
  assert_eq(
    @bytere.compile("((a*)*)*", extended=true).find("aa").unwrap().groups,
    [Some("aa"), Some("aa"), Some("aa")],
  )
  assert_eq(
    @bytere.compile("(a*){2}", extended=true).find("aa").unwrap().groups[1],
    Some(""),
  )
  assert_eq(
    @bytere.compile("(a*){2,}", extended=true).find("aa").unwrap().groups[1],
    Some("aa"),
  )
  assert_eq(
    @bytere.compile("(a*){0,2}", extended=true).find("aa").unwrap().groups[1],
    Some(""),
  )
  assert_eq(
    @bytere.compile("(a|(b))*", extended=true).find("ba").unwrap().groups,
    [Some("ba"), Some("a"), Some("b")],
  )
  assert_eq(
    @bytere.compile("(a*)*\\1", extended=true).find_span("aaaa"),
    Some((0, 4)),
  )
}

///|
test "byte regex endpoint filters consider shorter accepted alternatives" {
  let pattern = @bytere.compile("a-|a", extended=true)
  assert_eq(pattern.find_span("a-x"), Some((0, 2)))
  assert_eq(pattern.find_span("a-x", word=true), Some((0, 1)))
  assert_eq(
    @bytere.compile("[a!]*b").find_span("za!b", word=true),
    Some((3, 4)),
  )
  assert_eq(
    @bytere.compile("a|aa", extended=true).find_span("aa", whole=true),
    Some((0, 2)),
  )
  assert_eq(
    @bytere.compile("a|aa", extended=true).find_span("zaa", whole=true),
    None,
  )
  assert_eq(@bytere.compile("a").find_span("a", start=2), None)
  assert_eq(@bytere.compile("a").find_span("a", start=-1), None)
}

///|
test "byte regex literal prefix and capture-free rejection scan long records" {
  let input = String::make(12000, 'a')
  assert_eq(@bytere.compile("a*b").find_span(input), None)
  assert_eq(@bytere.compile("(a*)*b", extended=true).find_span(input), None)
  assert_eq(
    @bytere.compile("prefix[0-9]*").find_span(input + "prefix123"),
    Some((12000, 12009)),
  )
  assert_eq(
    @bytere.compile("literal").find_span(input + "literal"),
    Some((12000, 12007)),
  )
  assert_eq(@bytere.compile("").find_span("abc", start=2), Some((2, 2)))
  let prefix = @bytere.compile("prefix[0-9]+$", extended=true)
  assert_eq(
    prefix.find_span("prefixX" + input + "prefix123"),
    Some((12007, 12016)),
  )
  assert_eq(prefix.find_span("prefixX" + input), None)
  assert_eq(
    prefix.find_span("prefixX" + input + "prefix123", start=7),
    Some((12007, 12016)),
  )
  assert_eq(prefix.find_span("prefixX" + input + "prefix123", whole=true), None)
  assert_eq(prefix.find_span("prefixX" + input + "prefix123", word=true), None)
}

///|
test "literal anchors use absolute record boundaries including empty spans" {
  let prefix = @bytere.compile("^ab")
  assert_eq(prefix.find_span("ab\nab"), Some((0, 2)))
  assert_eq(prefix.find_span("zab"), None)
  assert_eq(prefix.find_span("ab", start=1), None)
  let suffix = @bytere.compile("ab$")
  assert_eq(suffix.find_span("ab\nab", start=2), Some((3, 5)))
  assert_eq(suffix.find_span("ab", start=1), None)
  assert_eq(suffix.find_span("ab\n"), None)
  assert_eq(suffix.find_span("a"), None)
  let full = @bytere.compile("^ab$")
  assert_eq(full.find_span("ab"), Some((0, 2)))
  assert_eq(full.find_span("ab\n"), None)
  assert_eq(full.find_span("zab"), None)
  assert_eq(@bytere.compile("^").find_span("abc"), Some((0, 0)))
  assert_eq(@bytere.compile("^").find_span("abc", start=1), None)
  assert_eq(@bytere.compile("$").find_span("abc", start=3), Some((3, 3)))
  assert_eq(@bytere.compile("^$").find_span(""), Some((0, 0)))
  assert_eq(@bytere.compile("^$").find_span("\n"), None)
  assert_eq(@bytere.compile("^a\nb$").find_span("a\nb"), Some((0, 3)))
  assert_eq(@bytere.compile("^ab").find_span("ab", start=-1), None)
  assert_eq(@bytere.compile("ab$").find_span("ab", start=3), None)
}

///|
test "literal anchors retain whole-record and word endpoint filters" {
  let prefix = @bytere.compile("^ab")
  assert_eq(prefix.find_span("ab!", word=true), Some((0, 2)))
  assert_eq(prefix.find_span("abc", word=true), None)
  assert_eq(prefix.find_span("ab!", whole=true), None)
  assert_eq(prefix.find_span("ab", whole=true, word=true), Some((0, 2)))
  let suffix = @bytere.compile("ab$")
  assert_eq(suffix.find_span("!ab", word=true), Some((1, 3)))
  assert_eq(suffix.find_span("cab", word=true), None)
  assert_eq(suffix.find_span("!ab", whole=true), None)
  assert_eq(suffix.find_span("ab", whole=true, word=true), Some((0, 2)))
  assert_eq(@bytere.compile("^-").find_span("-a", word=true), None)
  assert_eq(@bytere.compile("^-").find_span("-!", word=true), Some((0, 1)))
  assert_eq(@bytere.compile("^").find_span("abc", word=true), None)
  assert_eq(@bytere.compile("$").find_span("abc", word=true), None)
  assert_eq(
    @bytere.compile("^").find_span("", whole=true, word=true),
    Some((0, 0)),
  )
}

///|
test "literal anchor optimization leaves classes and captures on regex matching" {
  let folded = @bytere.compile("^Ab$", ignore_case=true)
  assert_eq(folded.find_span("aB", whole=true, word=true), Some((0, 2)))
  assert_eq(folded.find_span("Ab", start=1), None)
  assert_eq(@bytere.compile("^Ab$").find_span("aB"), None)
  assert_eq(@bytere.compile("^a.b$").find_span("a\nb"), Some((0, 3)))
  assert_eq(@bytere.compile("^a[bc]$").find_span("ac"), Some((0, 2)))
  assert_eq(
    @bytere.compile("^ab?$", extended=true).find_span("a"),
    Some((0, 1)),
  )
  assert_eq(
    @bytere.compile("^a|b$", extended=true).find_span("ab"),
    Some((0, 1)),
  )
  assert_eq(@bytere.compile("ab^", extended=true).find_span("ab"), None)
  let captured = @bytere.compile("^(ab)$", extended=true)
  assert_eq(captured.group_count(), 1)
  assert_eq(captured.find_span("ab"), Some((0, 2)))
  assert_eq(captured.find("ab").unwrap().groups, [Some("ab"), Some("ab")])
  assert_eq(@bytere.compile("^ab$").find("ab").unwrap().groups, [Some("ab")])
}

///|
test "GNU predicates do not request output capture registers" {
  for source in ["(a*){0,2}\\1", "(a*){2,}\\1"] {
    let pattern = @bytere.compile(source, extended=true)
    assert_true(pattern.is_match("aaaa"))
    assert_true(pattern.find("aaaa") is None)
    assert_eq(pattern.find_span("aaaa"), None)
  }
  assert_true(@bytere.compile("^ab$").is_match("ab"))
  assert_true(!@bytere.compile("^ab$").is_match("zab"))
}

///|
test "byte regex invalid syntax fails at compilation" {
  for
    source in [
      "\\", "[a", "[z-a]", "[[:unknown:]]", "\\(", "\\)", "\\1", "\\(a\\1\\)", "a\\{3,2\\}",
      "a\\{32768\\}",
    ] {
    let rejected = try {
      ignore(@bytere.compile(source))
      false
    } catch {
      _ => true
    }
    assert_true(rejected, msg=source)
  }
  for
    source in [
      "(?x)", "(a", "a)", "{1}", "{b", "a{3,2}", "a{32768}", "a{b", "a{2x}", "a{}",
    ] {
    let rejected = try {
      ignore(@bytere.compile(source, extended=true))
      false
    } catch {
      _ => true
    }
    assert_true(rejected, msg=source)
  }
}

///|
test "ASCII case folding preserves assertion grammar and negated classes" {
  for
    (source, input, expected) in [
      ("\\B[A-Z]+\\W", "aB!", Some((1, 3))),
      ("[[:upper:]]+", "aAz", Some((0, 3))),
      ("[^A]+", "aAbB", Some((2, 4))),
      ("\\S+", " Aa ", Some((1, 3))),
      ("\\W+", "Ab !", Some((2, 4))),
    ] {
    let pattern = @bytere.compile(source, extended=true, ignore_case=true)
    assert_eq(pattern.find_span(input), expected, msg=source)
  }
  let pattern = @bytere.compile("\\([A-Z]\\)\\1", ignore_case=true)
  let hit = pattern.find("Aa").unwrap()
  assert_eq(hit.groups, [Some("Aa"), Some("A")])
  assert_true(@bytere.compile("A").find("a") is None)
}
