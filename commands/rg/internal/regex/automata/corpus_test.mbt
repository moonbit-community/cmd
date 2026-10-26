///|
/// Returns true if `at` is on a UTF-8 character boundary of `hay`.
fn is_char_boundary(hay : FixedArray[Byte], len : Int32, at : Int32) -> Bool {
  at >= len || at == 0 || (hay[at].to_int() & 0xC0) != 0x80
}

///|
/// Runs a test case using `find(start, end, anchored, slots) -> Bool` and
/// returns a description of the failure, if any.
fn run_case(
  tc : @testdata.TestCase,
  find : (FixedArray[Byte], Int32, Int32, Int32, Bool, FixedArray[Int32]) -> Bool,
  ngroups : Int32,
) -> String? {
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
  let nslots = if want_groups > 1 { ngroups * 2 } else { 2 }
  let got : Array[Array[(Int32, Int32)?]] = []
  let mut start = bstart
  let mut last_end : Int32? = None
  while start <= bend {
    if tc.match_limit is Some(limit) && got.length() >= limit {
      break
    }
    let slots = FixedArray::make(nslots, -1)
    if !find(hay, len, start, bend, tc.anchored, slots) {
      break
    }
    let s = slots[0]
    let e = slots[1]
    if s == e {
      // Empty match handling.
      if last_end == Some(e) {
        start = e + 1
        continue
      }
      if tc.utf8 && !is_char_boundary(hay, len, e) {
        if tc.anchored {
          break
        }
        start = e + 1
        continue
      }
    }
    let groups = []
    for g in 0..<want_groups {
      if 2 * g + 1 < nslots && slots[2 * g] >= 0 && slots[2 * g + 1] >= 0 {
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
    Some(
      "\{tc.name}: regex=\{tc.regex} want=\{Repr(expected)} got=\{Repr(got)}",
    )
  } else {
    None
  }
}

///|
fn parse_case(tc : @testdata.TestCase) -> @syntax.Hir? {
  let config = {
    ..@syntax.ParseConfig::default(),
    case_insensitive: tc.case_insensitive,
    unicode: tc.unicode,
    utf8: tc.utf8,
    line_terminator: tc.line_terminator.unwrap_or('\n'),
  }
  try @syntax.parse(tc.regex, config~) catch {
    _ => None
  } noraise {
    h => Some(h)
  }
}

///|
test "corpus: pikevm" {
  let failures = []
  let mut ran = 0
  for tc in @testdata.cases {
    if tc.name.has_prefix("regex-lite/") {
      continue
    }
    let hir = match parse_case(tc) {
      None => {
        if tc.compiles {
          failures.push("\{tc.name}: failed to compile \{tc.regex}")
        }
        continue
      }
      Some(h) => h
    }
    if !tc.compiles {
      failures.push("\{tc.name}: compiled but should not \{tc.regex}")
      continue
    }
    if tc.line_terminator is Some(_) || tc.name.has_prefix("regex-lite/") {
      continue
    }
    let nfa = @automata.compile_nfa(hir) catch { _ => abort("nfa") }
    let vm = @automata.PikeVM::new(nfa)
    ran += 1
    let find = (hay, len, start, end, anchored, slots) => {
      vm.search_slots(hay, 0, len, start, end, anchored, false, slots)
    }
    if run_case(tc, find, nfa.group_len()) is Some(f) {
      failures.push(f)
    }
  }
  for f in failures {
    println(f)
  }
  inspect(failures.length(), content="0")
  inspect(ran > 600, content="true")
}

///|
test "corpus: lazy dfa" {
  let failures = []
  let mut fallbacks = 0
  for tc in @testdata.cases {
    if tc.name.has_prefix("regex-lite/") || tc.line_terminator is Some(_) {
      continue
    }
    let hir = match parse_case(tc) {
      None => continue
      Some(h) => h
    }
    let fwd = @automata.compile_nfa(hir) catch { _ => abort("nfa") }
    let rev = @automata.compile_nfa(hir, config={
      reverse: true,
      captures: false,
      unanchored_prefix: false,
      size_limit: None,
    }) catch {
      _ => abort("nfa")
    }
    let fdfa = @automata.LazyDFA::new(fwd)
    let rdfa = @automata.LazyDFA::new(rev, match_all=true)
    let vm = @automata.PikeVM::new(fwd)
    let find = (hay, len, start, end, anchored, slots : FixedArray[Int32]) => {
      let e = fdfa.find_fwd(hay, 0, len, start, end, anchored, false)
      if e == @automata.DFA_FAILED {
        fallbacks += 1
        return vm.search_slots(hay, 0, len, start, end, anchored, false, slots)
      }
      if e < 0 {
        return false
      }
      let s = rdfa.find_rev(hay, 0, len, start, e, true, false)
      if s == @automata.DFA_FAILED {
        fallbacks += 1
        return vm.search_slots(hay, 0, len, start, end, anchored, false, slots)
      }
      if s < 0 {
        abort("reverse search failed to find start: \{tc.name}")
      }
      if slots.length() > 2 {
        // Captures: run the PikeVM on the match span.
        return vm.search_slots(hay, 0, len, s, e, true, false, slots)
      }
      slots[0] = s
      slots[1] = e
      true
    }
    if run_case(tc, find, fwd.group_len()) is Some(f) {
      failures.push(f)
    }
  }
  for f in failures {
    println(f)
  }
  inspect(failures.length(), content="0")
  inspect(fallbacks > 0, content="true")
}
