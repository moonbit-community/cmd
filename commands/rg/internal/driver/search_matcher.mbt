///|
/// Compiled search rules adapted to the searcher's matcher protocol.
priv struct SearchMatcher {
  line_terminator : @matcher.LineTerminator?
  regex : @regex.Regex
  fast_line_regex : @regex.Regex?
  non_matching_bytes : @matcher.ByteSet
}

///|
impl @matcher.Matcher for SearchMatcher with fn find_at(self, hay, hs, he, at) {
  match self.regex.find_at(hay, hs, he, hs + at, he) {
    Some((s, e)) => Some({ start: s - hs, end: e - hs, })
    None => None
  }
}

///|
impl @matcher.Matcher for SearchMatcher with fn new_captures(self) {
  @matcher.Captures::new(self.regex.captures_len())
}

///|
impl @matcher.Matcher for SearchMatcher with fn capture_count(self) {
  self.regex.captures_len()
}

///|
impl @matcher.Matcher for SearchMatcher with fn capture_index(self, name) {
  self.regex.group_index(name)
}

///|
impl @matcher.Matcher for SearchMatcher with fn captures_at(
  self,
  hay,
  hs,
  he,
  at,
  caps,
) {
  let slots = caps.slots
  if !self.regex.captures_at(hay, hs, he, hs + at, he, slots) {
    return false
  }
  for i in 0..<slots.length() {
    if slots[i] >= 0 {
      slots[i] = slots[i] - hs
    }
  }
  true
}

///|
impl @matcher.Matcher for SearchMatcher with fn shortest_match_at(
  self,
  hay,
  hs,
  he,
  at,
) {
  match self.regex.search_half(hay, hs, he, hs + at, he) {
    Some(e) => Some(e - hs)
    None => None
  }
}

///|
impl @matcher.Matcher for SearchMatcher with fn non_matching_bytes(self) {
  Some(self.non_matching_bytes)
}

///|
impl @matcher.Matcher for SearchMatcher with fn literal_overlap(self, term) {
  match self.regex.hir().kind {
    Literal(bytes) if bytes.length() > 0 &&
      bytes.length() <= 4096 &&
      self.non_matching_bytes.contains(term) => Some(bytes.length() - 1)
    _ => None
  }
}

///|
impl @matcher.Matcher for SearchMatcher with fn count_matching_lines(
  self,
  hay,
  hs,
  he,
  term,
) {
  if !self.non_matching_bytes.contains(term) {
    return None
  }
  if self.regex.count_exact_lines(hay, hs, he, term) is Some(count) {
    return Some(count)
  }
  if he - hs >= 4096 && self.regex.byte_prefix_start(hay, hs, he) == Some(-1) {
    return Some(0L)
  }
  if he - hs < 4096 || self.regex.is_accelerated() {
    return None
  }
  if he - hs > 262144 && self.fast_line_regex is Some(filter) {
    if filter.search_half(hay, hs, he, hs, he) is None {
      return Some(0L)
    }
  }
  // Retain the mandatory-literal rejection pass. Dense candidates may
  // use a count-only DFA; sparse candidates keep the existing verifier.
  if he - hs <= 262144 && self.fast_line_regex is Some(filter) {
    let mut at = hs
    for sample in 0..<8 {
      match filter.search_half(hay, hs, he, at, he) {
        None => return if sample == 0 { Some(0L) } else { None }
        Some(end) => {
          if end - hs > 4096 {
            return None
          }
          at = end.max(at + 1)
          if at >= he {
            return None
          }
        }
      }
    }
  }
  self.regex.count_boolean_lines(
    hay,
    hs,
    he,
    term,
    required=self.fast_line_regex,
  )
}

///|
impl @matcher.Matcher for SearchMatcher with fn line_terminator(self) {
  self.line_terminator
}

///|
impl @matcher.Matcher for SearchMatcher with fn find_candidate_line(
  self,
  hay,
  hs,
  he,
) {
  match self.fast_line_regex {
    Some(re) => {
      let at = if he - hs >= 4096 {
        match self.regex.byte_prefix_start(hay, hs, he) {
          Some(-1) => return None
          Some(start) => start
          None => hs
        }
      } else {
        hs
      }
      match re.search_half(hay, hs, he, at, he) {
        Some(e) => Some(Candidate(e - hs))
        None => None
      }
    }
    None => {
      if he - hs > 262144 && self.line_terminator is Some(_) {
        match self.regex.search_boolean_long(hay, hs, he) {
          Some(-1) => return None
          Some(end) => return Some(Confirmed(end - hs))
          None => ()
        }
      }
      match self.regex.search_half(hay, hs, he, hs, he) {
        Some(e) => Some(Confirmed(e - hs))
        None => None
      }
    }
  }
}
