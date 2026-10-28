///|
/// A builder for a regex matcher.
pub struct RegexMatcherBuilder {
  priv mut config : Config
}

///|
pub fn RegexMatcherBuilder::new() -> RegexMatcherBuilder {
  { config: Config::default(), }
}

///|
/// Builds a matcher from a single pattern.
pub fn RegexMatcherBuilder::build(
  self : RegexMatcherBuilder,
  pattern : String,
) -> RegexMatcher raise GrepRegexError {
  self.build_many([pattern])
}

///|
/// Builds a matcher that matches any of the given patterns.
pub fn RegexMatcherBuilder::build_many(
  self : RegexMatcherBuilder,
  patterns : Array[String],
) -> RegexMatcher raise GrepRegexError {
  let mut chir = ConfiguredHIR::new(self.config, patterns)
  if chir.config.whole_line {
    chir = chir.into_whole_line()
  } else if chir.config.word {
    chir = chir.into_word()
  }
  let regex = chir.to_regex()
  let non_matching = non_matching_bytes(chir.hir)
  let fast_line_regex = inner_literals_regex(chir, regex)
  let config = { ..self.config, line_terminator: chir.line_terminator(), }
  { config, regex, fast_line_regex, non_matching_bytes: non_matching, }
}

///|
pub fn RegexMatcherBuilder::case_insensitive(
  self : RegexMatcherBuilder,
  yes : Bool,
) -> RegexMatcherBuilder {
  self.config = { ..self.config, case_insensitive: yes, }
  self
}

///|
pub fn RegexMatcherBuilder::case_smart(
  self : RegexMatcherBuilder,
  yes : Bool,
) -> RegexMatcherBuilder {
  self.config = { ..self.config, case_smart: yes, }
  self
}

///|
pub fn RegexMatcherBuilder::multi_line(
  self : RegexMatcherBuilder,
  yes : Bool,
) -> RegexMatcherBuilder {
  self.config = { ..self.config, multi_line: yes, }
  self
}

///|
pub fn RegexMatcherBuilder::dot_matches_new_line(
  self : RegexMatcherBuilder,
  yes : Bool,
) -> RegexMatcherBuilder {
  self.config = { ..self.config, dot_matches_new_line: yes, }
  self
}

///|
pub fn RegexMatcherBuilder::unicode(
  self : RegexMatcherBuilder,
  yes : Bool,
) -> RegexMatcherBuilder {
  self.config = { ..self.config, unicode: yes, }
  self
}

///|
pub fn RegexMatcherBuilder::octal(
  self : RegexMatcherBuilder,
  yes : Bool,
) -> RegexMatcherBuilder {
  self.config = { ..self.config, octal: yes, }
  self
}

///|
pub fn RegexMatcherBuilder::size_limit(
  self : RegexMatcherBuilder,
  bytes : Int32,
) -> RegexMatcherBuilder {
  self.config = { ..self.config, size_limit: bytes, }
  self
}

///|
pub fn RegexMatcherBuilder::dfa_size_limit(
  self : RegexMatcherBuilder,
  bytes : Int32,
) -> RegexMatcherBuilder {
  self.config = { ..self.config, dfa_size_limit: bytes, }
  self
}

///|
pub fn RegexMatcherBuilder::line_terminator(
  self : RegexMatcherBuilder,
  line_term : Byte?,
) -> RegexMatcherBuilder {
  self.config = {
    ..self.config,
    line_terminator: line_term.map(@matcher.LineTerminator::byte),
  }
  self
}

///|
pub fn RegexMatcherBuilder::ban_byte(
  self : RegexMatcherBuilder,
  byte : Byte?,
) -> RegexMatcherBuilder {
  self.config = { ..self.config, ban: byte, }
  self
}

///|
pub fn RegexMatcherBuilder::crlf(
  self : RegexMatcherBuilder,
  yes : Bool,
) -> RegexMatcherBuilder {
  self.config = {
    ..self.config,
    line_terminator: if yes {
      Some(@matcher.LineTerminator::crlf())
    } else {
      None
    },
    crlf: yes,
  }
  self
}

///|
pub fn RegexMatcherBuilder::word(
  self : RegexMatcherBuilder,
  yes : Bool,
) -> RegexMatcherBuilder {
  self.config = { ..self.config, word: yes, }
  self
}

///|
pub fn RegexMatcherBuilder::fixed_strings(
  self : RegexMatcherBuilder,
  yes : Bool,
) -> RegexMatcherBuilder {
  self.config = { ..self.config, fixed_strings: yes, }
  self
}

///|
pub fn RegexMatcherBuilder::whole_line(
  self : RegexMatcherBuilder,
  yes : Bool,
) -> RegexMatcherBuilder {
  self.config = { ..self.config, whole_line: yes, }
  self
}

///|
/// A matcher implementation using the regex engine in this module.
pub struct RegexMatcher {
  priv config : Config
  priv regex : @regex.Regex
  priv fast_line_regex : @regex.Regex?
  priv non_matching_bytes : @matcher.ByteSet
}

///|
pub fn RegexMatcher::new(pattern : String) -> RegexMatcher raise GrepRegexError {
  RegexMatcherBuilder::new().build(pattern)
}

///|
pub impl @matcher.Matcher for RegexMatcher with fn find_at(
  self,
  hay,
  hs,
  he,
  at,
) {
  match self.regex.find_at(hay, hs, he, hs + at, he) {
    Some((s, e)) => Some({ start: s - hs, end: e - hs, })
    None => None
  }
}

///|
pub impl @matcher.Matcher for RegexMatcher with fn new_captures(self) {
  @matcher.Captures::new(self.regex.captures_len())
}

///|
pub impl @matcher.Matcher for RegexMatcher with fn capture_count(self) {
  self.regex.captures_len()
}

///|
pub impl @matcher.Matcher for RegexMatcher with fn capture_index(self, name) {
  self.regex.group_index(name)
}

///|
pub impl @matcher.Matcher for RegexMatcher with fn captures_at(
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
pub impl @matcher.Matcher for RegexMatcher with fn shortest_match_at(
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
pub impl @matcher.Matcher for RegexMatcher with fn non_matching_bytes(self) {
  Some(self.non_matching_bytes)
}

///|
pub impl @matcher.Matcher for RegexMatcher with fn literal_overlap(self, term) {
  match self.regex.hir().kind {
    Literal(bytes) if bytes.length() > 0 &&
      bytes.length() <= 4096 &&
      self.non_matching_bytes.contains(term) => Some(bytes.length() - 1)
    _ => None
  }
}

///|
pub impl @matcher.Matcher for RegexMatcher with fn count_matching_lines(
  self,
  hay,
  hs,
  he,
  term,
) {
  if !self.non_matching_bytes.contains(term) {
    return None
  }
  self.regex.count_exact_lines(hay, hs, he, term)
}

///|
pub impl @matcher.Matcher for RegexMatcher with fn line_terminator(self) {
  self.config.line_terminator
}

///|
pub impl @matcher.Matcher for RegexMatcher with fn find_candidate_line(
  self,
  hay,
  hs,
  he,
) {
  match self.fast_line_regex {
    Some(re) =>
      match re.search_half(hay, hs, he, hs, he) {
        Some(e) => Some(Candidate(e - hs))
        None => None
      }
    None =>
      match self.regex.search_half(hay, hs, he, hs, he) {
        Some(e) => Some(Confirmed(e - hs))
        None => None
      }
  }
}
