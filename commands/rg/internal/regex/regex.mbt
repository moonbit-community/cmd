///|
/// An error that occurred while building a regex.
pub suberror RegexError {
  /// A syntax error, rendered in the same format as Rust's regex crate.
  Syntax(@syntax.SyntaxError)
  /// The compiled regex exceeded the configured size limit.
  TooBig(Int32)
} derive(Debug)

///|
pub fn RegexError::to_string(self : RegexError) -> String {
  match self {
    Syntax(e) => e.to_string()
    TooBig(limit) => "compiled regex exceeds size limit of \{limit} bytes"
  }
}

///|
pub impl Show for RegexError with fn output(self, logger) {
  logger.write_string(self.to_string())
}

///|
/// Configuration for building a `Regex` from an HIR.
pub(all) struct RegexConfig {
  /// Maximum approximate size of the compiled NFA, in bytes.
  nfa_size_limit : Int32?
  /// Maximum number of states in each lazy DFA cache before it is cleared.
  dfa_state_limit : Int32
}

///|
pub fn RegexConfig::default() -> RegexConfig {
  { nfa_size_limit: None, dfa_state_limit: 10000, }
}

///|
/// A compiled regular expression that searches byte haystacks with
/// leftmost-first semantics (like Rust's regex crate).
pub struct Regex {
  priv hir : @syntax.Hir
  priv pikevm : @automata.PikeVM
  priv fwd : @automata.LazyDFA
  priv rev : @automata.LazyDFA
  priv pre : @automata.Prefilter?
  /// When true, the prefilter itself finds exact matches.
  priv pre_is_exact : Bool
  priv group_names : Array[String?]
}

///|
/// Compiles a pattern with the default syntax configuration.
pub fn Regex::new(pattern : String) -> Regex raise RegexError {
  let hir = @syntax.parse(pattern) catch { e => raise Syntax(e) }
  Regex::from_hir(hir)
}

///|
/// Compiles an HIR into a regex.
pub fn Regex::from_hir(
  hir : @syntax.Hir,
  config~ : RegexConfig = RegexConfig::default(),
) -> Regex raise RegexError {
  // Build a prefilter from prefix literals.
  let mut pre : @automata.Prefilter? = None
  let mut pre_is_exact = false
  let seq = @syntax.Extractor::new().extract(hir)
  seq.optimize_for_prefix_by_preference()
  if seq.literals() is Some(lits) && lits.length() > 0 {
    pre = @automata.Prefilter::new(lits.map(l => l.bytes))
    // Like regex-automata's `Pre::from_prefixes`: if the extracted prefixes
    // are exact (e.g. 'foo', '[abc][123]' or 'foo|bar') and the regex has no
    // captures or look-around, the prefilter is the regex.
    if pre is Some(_) &&
      seq.is_exact() &&
      hir.props.look_set.is_empty() &&
      hir.props.explicit_captures_len == 0 {
      pre_is_exact = true
    }
  }
  // Like regex-automata's meta regex, a regex that is just a literal search
  // doesn't need a regex engine, so the NFA size limit doesn't apply to it.
  let size_limit = if pre_is_exact { None } else { config.nfa_size_limit }
  let nfa = @automata.compile_nfa(hir, config={
    ..@automata.NFAConfig::default(),
    size_limit,
  }) catch {
    TooBig(n) => raise TooBig(n)
  }
  let rev_nfa = @automata.compile_nfa(hir, config={
    reverse: true,
    captures: false,
    unanchored_prefix: false,
    size_limit,
  }) catch {
    TooBig(n) => raise TooBig(n)
  }
  {
    hir,
    pikevm: @automata.PikeVM::new(nfa),
    fwd: @automata.LazyDFA::new(nfa, state_limit=config.dfa_state_limit),
    rev: @automata.LazyDFA::new(
      rev_nfa,
      match_all=true,
      state_limit=config.dfa_state_limit,
    ),
    pre,
    pre_is_exact,
    group_names: nfa.group_names(),
  }
}

///|
/// Returns the HIR this regex was compiled from.
pub fn Regex::hir(self : Regex) -> @syntax.Hir {
  self.hir
}

///|
/// Returns true if this regex has a prefilter that is believed to make
/// searching fast.
pub fn Regex::is_accelerated(self : Regex) -> Bool {
  match self.pre {
    Some(p) => p.is_fast()
    None => false
  }
}

///|
/// The number of capture groups, including the implicit group 0.
pub fn Regex::captures_len(self : Regex) -> Int32 {
  self.group_names.length()
}

///|
/// The names of each capture group, indexed by group index.
pub fn Regex::group_names(self : Regex) -> Array[String?] {
  self.group_names
}

///|
/// Returns the index of the capture group with the given name.
pub fn Regex::group_index(self : Regex, name : String) -> Int32? {
  for i, n in self.group_names {
    if n == Some(name) {
      return Some(i)
    }
  }
  None
}

///|
/// Searches for the end of the leftmost-first match in `hay[start:end]`,
/// where the haystack is `hay[hs:he]`. All offsets are absolute indices
/// into `hay`. When `earliest` is true, the search
/// may stop as soon as any match is known to exist.
pub fn Regex::search_half(
  self : Regex,
  hay : FixedArray[Byte],
  hs : Int32,
  he : Int32,
  start : Int32,
  end : Int32,
  earliest~ : Bool = false,
) -> Int32? {
  if self.pre_is_exact {
    let sp = self.pre.unwrap().find_span(hay, start, end)
    return if sp == @automata.NO_SPAN {
      None
    } else {
      Some(@automata.span_end(sp))
    }
  }
  let e = self.fwd.find_fwd(
    hay,
    hs,
    he,
    start,
    end,
    false,
    earliest,
    pre?=self.pre,
  )
  if e == @automata.DFA_FAILED {
    let slots = FixedArray::make(2, -1)
    if self.pikevm.search_slots(
        hay,
        hs,
        he,
        start,
        end,
        false,
        earliest,
        slots,
        pre?=self.pre,
      ) {
      Some(slots[1])
    } else {
      None
    }
  } else if e < 0 {
    None
  } else {
    Some(e)
  }
}

///|
/// Returns true if there is a match in `hay[start:end]`.
pub fn Regex::is_match_at(
  self : Regex,
  hay : FixedArray[Byte],
  hs : Int32,
  he : Int32,
  start : Int32,
  end : Int32,
) -> Bool {
  self.search_half(hay, hs, he, start, end, earliest=true) is Some(_)
}

///|
/// Finds the leftmost-first match in `hay[start:end]`, returning its span.
pub fn Regex::find_at(
  self : Regex,
  hay : FixedArray[Byte],
  hs : Int32,
  he : Int32,
  start : Int32,
  end : Int32,
) -> (Int32, Int32)? {
  if self.pre_is_exact {
    return self.pre.unwrap().find(hay, start, end)
  }
  let e = self.fwd.find_fwd(
    hay,
    hs,
    he,
    start,
    end,
    false,
    false,
    pre?=self.pre,
  )
  if e == @automata.DFA_FAILED {
    return self.find_pikevm(hay, hs, he, start, end)
  }
  if e < 0 {
    return None
  }
  let s = self.rev.find_rev(hay, hs, he, start, e, true, false)
  if s == @automata.DFA_FAILED {
    return self.find_pikevm(hay, hs, he, start, end)
  }
  if s < 0 {
    // This should never happen: a forward match implies a reverse match.
    return self.find_pikevm(hay, hs, he, start, end)
  }
  Some((s, e))
}

///|
fn Regex::find_pikevm(
  self : Regex,
  hay : FixedArray[Byte],
  hs : Int32,
  he : Int32,
  start : Int32,
  end : Int32,
) -> (Int32, Int32)? {
  let slots = FixedArray::make(2, -1)
  if self.pikevm.search_slots(
      hay,
      hs,
      he,
      start,
      end,
      false,
      false,
      slots,
      pre?=self.pre,
    ) {
    Some((slots[0], slots[1]))
  } else {
    None
  }
}

///|
/// Finds the leftmost-first match in `hay[start:end]` and records the
/// capture group positions in `slots` (two per group; -1 for groups that
/// did not participate). Returns true if a match was found.
pub fn Regex::captures_at(
  self : Regex,
  hay : FixedArray[Byte],
  hs : Int32,
  he : Int32,
  start : Int32,
  end : Int32,
  slots : FixedArray[Int32],
) -> Bool {
  for i in 0..<slots.length() {
    slots[i] = -1
  }
  if slots.length() <= 2 {
    match self.find_at(hay, hs, he, start, end) {
      Some((s, e)) => {
        if slots.length() > 0 {
          slots[0] = s
        }
        if slots.length() > 1 {
          slots[1] = e
        }
        return true
      }
      None => return false
    }
  }
  match self.find_at(hay, hs, he, start, end) {
    None => false
    Some((s, e)) =>
      // Run the PikeVM only on the match span to resolve capture groups.
      self.pikevm.search_slots(hay, hs, he, s, e, true, false, slots)
  }
}

///|
/// Convenience: finds the first match in a byte string.
pub fn Regex::find(self : Regex, hay : Bytes) -> (Int32, Int32)? {
  let h = hay.to_fixedarray()
  self.find_at(h, 0, h.length(), 0, h.length())
}

///|
/// Convenience: returns true if the regex matches anywhere in `hay`.
pub fn Regex::is_match(self : Regex, hay : Bytes) -> Bool {
  let h = hay.to_fixedarray()
  self.is_match_at(h, 0, h.length(), 0, h.length())
}

///|
/// Convenience: returns all non-overlapping matches in `hay`, following
/// the same empty-match rules as ripgrep.
pub fn Regex::find_all(self : Regex, hay : Bytes) -> Array[(Int32, Int32)] {
  let h = hay.to_fixedarray()
  let len = h.length()
  let out = []
  let mut at = 0
  let mut last_match : Int32? = None
  while at <= len {
    match self.find_at(h, 0, len, at, len) {
      None => break
      Some((s, e)) => {
        if s == e {
          at = e + 1
          if last_match == Some(e) {
            continue
          }
        } else {
          at = e
        }
        last_match = Some(e)
        out.push((s, e))
      }
    }
  }
  out
}
