///|
/// Static specialization keeps byte searches in their borrowed storage while
/// retaining the public String search's code-unit semantics.
priv trait SpanInput {
  fn span_length(Self) -> Int32
  fn span_code(Self, Int32) -> Int32
  fn span_prefix(Self, String, Bytes?, Int32) -> Int32?
}

///|
impl SpanInput for StringView with fn span_length(self) {
  self.length()
}

///|
impl SpanInput for StringView with fn span_code(self, index) {
  self[index].to_int()
}

///|
impl SpanInput for StringView with fn span_prefix(self, prefix, _, start) {
  self[start:].find(prefix)
}

///|
impl SpanInput for BytesView with fn span_length(self) {
  self.length()
}

///|
impl SpanInput for BytesView with fn span_code(self, index) {
  self[index].to_int()
}

///|
impl SpanInput for BytesView with fn span_prefix(self, _, prefix, start) {
  match prefix {
    Some(prefix) => self[start:].find(prefix)
    None => None
  }
}

///|
fn[I : SpanInput] span_word(value : I, index : Int32) -> Bool {
  if index < 0 || index >= value.span_length() {
    return false
  }
  let code = value.span_code(index)
  code == 95 || code is (48..<=57 | 65..<=90 | 97..<=122)
}

///|
fn[I : SpanInput] span_prefix_at(
  value : I,
  prefix : String,
  position : Int32,
) -> Bool {
  if prefix.length() > value.span_length() - position {
    return false
  }
  for index in 0..<prefix.length() {
    if value.span_code(position + index) != prefix[index].to_int() {
      return false
    }
  }
  true
}

///|
/// Borrow one record and cache fallback decoding once across resumed searches.
struct RecordSearch {
  matcher : RecordMatcher
  value : BytesView
  whole : Bool
  word : Bool
  input : RecordText
  mut starts : FixedArray[UInt64]?
  mut suffix : SpanSuffix?
}

///|
priv struct RecordText {
  value : BytesView
  mut decoded : String?
}

///|
/// Create a byte-oriented search over one immutable record. Returned offsets
/// are relative to this view, including when its backing storage has an offset.
///
/// ```mbt check
/// test {
///   let matcher = @bytere.compile("a|aa", extended=true).record_matcher()
///   let search = matcher.search_bytes(b"zaaa")
///   assert_eq(search.find_span(), Some((1, 3)))
///   assert_eq(search.find_span(start=3), Some((3, 4)))
/// }
/// ```
pub fn RecordMatcher::search_bytes(
  self : RecordMatcher,
  value : BytesView,
  whole~ : Bool = false,
  word~ : Bool = false,
) -> RecordSearch {
  {
    matcher: self,
    value,
    whole,
    word,
    input: { value, decoded: None, },
    starts: None,
    suffix: None,
  }
}

///|
/// Search several patterns over one borrowed record, sharing any fallback text
/// conversion. Each search retains independent match offsets and start bits.
///
/// ```mbt check
/// test {
///   let patterns = [
///     @bytere.compile("a").record_matcher(),
///     @bytere.compile("b").record_matcher(),
///   ]
///   let searches = @bytere.search_bytes(patterns, b"ab")
///   assert_eq(searches[0].find_span(), Some((0, 1)))
///   assert_eq(searches[1].find_span(), Some((1, 2)))
/// }
/// ```
pub fn search_bytes(
  patterns : ArrayView[RecordMatcher],
  value : BytesView,
  whole~ : Bool = false,
  word~ : Bool = false,
) -> Array[RecordSearch] {
  let input : RecordText = { value, decoded: None, }
  patterns.map(matcher => {
    matcher,
    value,
    whole,
    word,
    input,
    starts: None,
    suffix: None,
  })
}

///|
/// Return the leftmost-longest span at or after start. Empty spans are retained;
/// callers enumerating them must advance by one byte to make progress.
pub fn RecordSearch::find_span(
  self : RecordSearch,
  start~ : Int32 = 0,
) -> (Int32, Int32)? {
  if start < 0 || start > self.value.length() || (self.whole && start != 0) {
    return None
  }
  let matcher = self.matcher
  let required = matcher.pattern.required_literal
  if start == 0 && required.length() >= 2 && self.value.find(required) is None {
    return None
  }
  if matcher.pattern.literal is Some(literal) &&
    matcher.byte_literal is Some(needle) {
    return self.find_literal(literal, needle, start)
  }
  if !self.whole && !self.word {
    if !matcher.span_dfa_initialized {
      matcher.span_dfa = SpanDfa::new(matcher.pattern)
      matcher.span_dfa_initialized = true
    }
    if matcher.span_dfa is Some(dfa) {
      if self.starts is None {
        self.starts = dfa.starts(self.value)
      }
      match self.starts {
        Some(bits) => {
          guard next_start(bits, start) is Some(left) else { return None }
          if self.suffix is None && self.value.length() - left >= 4096 {
            self.suffix = Some({ state: -1, start: 0, accepting: false, })
          }
          let right = match self.suffix {
            Some(suffix) => dfa.longest_skipping(self.value, left, suffix)
            None => dfa.longest(self.value, left)
          }
          if right >= left {
            return Some((left, right))
          }
        }
        None => ()
      }
      // Cache limits fall back on this same query, never on a partial result.
      matcher.span_dfa = None
    }
  }
  if !matcher.span_initialized {
    matcher.span_plan = SpanPlan::new(matcher.pattern)
    matcher.span_initialized = true
  }
  if matcher.span_plan is Some(plan) {
    return plan.find(matcher.pattern, self.value, start, self.whole, self.word)
  }
  let decoded = match self.input.decoded {
    Some(decoded) => decoded
    None => {
      let decoded = text(self.input.value)
      self.input.decoded = Some(decoded)
      decoded
    }
  }
  matcher.pattern.find_span(decoded, start~, whole=self.whole, word=self.word)
}

///|
fn RecordSearch::accepts(
  self : RecordSearch,
  left : Int32,
  end : Int32,
) -> Bool {
  (!self.whole || (left == 0 && end == self.value.length())) &&
  (
    !self.word ||
    (!span_word(self.value, left - 1) && !span_word(self.value, end))
  )
}

///|
fn RecordSearch::find_literal(
  self : RecordSearch,
  literal : LiteralPattern,
  needle : BytesView,
  start : Int32,
) -> (Int32, Int32)? {
  let value = self.value
  if literal.begin || literal.end {
    let left = if literal.begin { 0 } else { value.length() - needle.length() }
    let end = left + needle.length()
    return if left >= start &&
      end <= value.length() &&
      (!literal.end || end == value.length()) &&
      value[left:end] == needle &&
      self.accepts(left, end) {
      Some((left, end))
    } else {
      None
    }
  }
  let mut position = start
  while position <= value.length() {
    guard value[position:].find(needle) is Some(relative) else { return None }
    let left = position + relative
    let end = left + needle.length()
    if self.accepts(left, end) {
      return Some((left, end))
    }
    position = left + 1
    if self.whole {
      return None
    }
  }
  None
}
