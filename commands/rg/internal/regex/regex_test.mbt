///|
fn is_char_boundary(hay : FixedArray[Byte], len : Int32, at : Int32) -> Bool {
  at >= len || at == 0 || (hay[at].to_int() & 0xC0) != 0x80
}

///|
test "corpus: meta regex" {
  let failures = []
  for tc in @testdata.cases {
    if tc.name.has_prefix("regex-lite/") || tc.line_terminator is Some(_) {
      continue
    }
    let config = {
      ..@syntax.ParseConfig::default(),
      case_insensitive: tc.case_insensitive,
      unicode: tc.unicode,
      utf8: tc.utf8,
    }
    let hir = @syntax.parse(tc.regex, config~) catch { _ => continue }
    let re = @regex.Regex::from_hir(hir) catch { _ => abort("build") }
    if tc.anchored {
      continue
    }
    let hay = tc.haystack.to_fixedarray()
    let len = hay.length()
    let (bstart, bend) = match tc.bounds {
      Some(b) => b
      None => (0, len)
    }
    let want_groups = if tc.matches.is_empty() {
      1
    } else {
      tc.matches[0].length()
    }
    let got : Array[Array[(Int32, Int32)?]] = []
    let mut start = bstart
    let mut last_end : Int32? = None
    while start <= bend {
      if tc.match_limit is Some(limit) && got.length() >= limit {
        break
      }
      let slots = FixedArray::make(re.captures_len() * 2, -1)
      if !re.captures_at(hay, 0, len, start, bend, slots) {
        break
      }
      let s = slots[0]
      let e = slots[1]
      if s == e &&
        (last_end == Some(e) || (tc.utf8 && !is_char_boundary(hay, len, e))) {
        start = e + 1
        continue
      }
      let groups = []
      for g in 0..<want_groups {
        if slots[2 * g] >= 0 {
          groups.push(Some((slots[2 * g], slots[2 * g + 1])))
        } else {
          groups.push(None)
        }
      }
      got.push(groups)
      last_end = Some(e)
      start = e
    }
    let expected = tc.matches.map(g => g.copy())
    if got != expected {
      failures.push(
        "\{tc.name}: regex=\{tc.regex} want=\{Repr(expected)} got=\{Repr(got)}",
      )
    }
  }
  for f in failures {
    println(f)
  }
  inspect(failures.length(), content="0")
}

///|
test "basic api" {
  let re = @regex.Regex::new("foo\\d+") catch { _ => abort("") }
  debug_inspect(re.find(b"xx foo123 foo9"), content="Some((3, 9))")
  debug_inspect(re.find_all(b"xx foo123 foo9"), content="[(3, 9), (10, 14)]")
  inspect(re.is_accelerated(), content="true")
  let re = @regex.Regex::new("") catch { _ => abort("") }
  debug_inspect(re.find_all(b"abc"), content="[(0, 0), (1, 1), (2, 2), (3, 3)]")
  let re = @regex.Regex::new("foo|bar") catch { _ => abort("") }
  debug_inspect(re.find_all(b"barfoo"), content="[(0, 3), (3, 6)]")
  let err = try @regex.Regex::new("(") catch {
    e => e.to_string()
  } noraise {
    _ => ""
  }
  inspect(
    err,
    content=(
      #|regex parse error:
      #|    (
      #|    ^
      #|error: unclosed group
    ),
  )
}

///|
test "unicode word boundaries after non-ASCII text" {
  // The lazy DFA can't start a search right after a non-ASCII byte when
  // Unicode word boundaries are involved; it must fall back (like upstream's
  // quit bytes) instead of treating the byte as a non-word byte.
  let hay = b"\xC3\xA9a" // "éa"
  assert_eq(@regex.Regex::new("\\Ba").find(hay), Some((2, 3)))
  assert_eq(@regex.Regex::new("\\ba").find(hay), None)
  assert_eq(@regex.Regex::new("a\\b").find(b"a\xC3\xA9"), None)
  assert_eq(@regex.Regex::new("a\\B").find(b"a\xC3\xA9"), Some((0, 1)))
}

///|
fn with_size_limit(pattern : String, limit : Int32) -> Bool raise {
  let hir = @syntax.parse(pattern)
  let config = { ..@regex.RegexConfig::default(), nfa_size_limit: Some(limit), }
  try {
    @regex.Regex::from_hir(hir, config~) |> ignore
    true
  } catch {
    _ => false
  }
}

///|
test "NFA size limits match regex-automata's accounting" {
  // Literal searches don't build an NFA at all.
  assert_true(with_size_limit("foo", 0))
  assert_true(with_size_limit("foo|bar", 0))
  assert_true(with_size_limit("[abc][123]", 0))
  // The smallest limits accepted by ripgrep 15.2.0 (regex-automata 0.4.18).
  for
    case in [
      ("a*", 280),
      ("(a|b)*c", 416),
      ("a{1,50}", 3800),
      ("(a)(b)(c)", 496),
    ] {
    let (pattern, limit) = case
    assert_true(with_size_limit(pattern, limit))
    assert_false(with_size_limit(pattern, limit - 1))
  }
}
