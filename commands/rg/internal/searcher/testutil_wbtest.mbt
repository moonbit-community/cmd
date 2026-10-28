///|
/// A simple matcher for tests, using `(?m)` regexes.
struct TestMatcher {
  regex : @regex.Regex
  mut line_term : @matcher.LineTerminator?
  mut every_line_is_candidate : Bool
}

///|
fn TestMatcher::new(pattern : String) -> TestMatcher {
  let hir = @syntax.parse(pattern, config={
    ..@syntax.ParseConfig::default(),
    multi_line: true,
  }) catch {
    e => abort(e.to_string())
  }
  let regex = @regex.Regex::from_hir(hir) catch { e => abort(e.to_string()) }
  { regex, line_term: None, every_line_is_candidate: false, }
}

///|
fn TestMatcher::copy(self : TestMatcher) -> TestMatcher {
  {
    regex: self.regex,
    line_term: self.line_term,
    every_line_is_candidate: self.every_line_is_candidate,
  }
}

///|
impl @matcher.Matcher for TestMatcher with fn find_at(self, hay, hs, he, at) {
  match self.regex.find_at(hay, hs, he, hs + at, he) {
    Some((s, e)) => Some({ start: s - hs, end: e - hs, })
    None => None
  }
}

///|
impl @matcher.Matcher for TestMatcher with fn new_captures(_self) {
  @matcher.Captures::new(0)
}

///|
impl @matcher.Matcher for TestMatcher with fn line_terminator(self) {
  self.line_term
}

///|
impl @matcher.Matcher for TestMatcher with fn find_candidate_line(
  self,
  hay,
  hs,
  he,
) {
  if self.every_line_is_candidate {
    if hs == he {
      return None
    }
    let i = match find_byte(hay, self.line_term.unwrap().as_byte(), hs, he) {
      Some(i) => i - hs
      None => he - hs - 1
    }
    Some(Candidate(i))
  } else {
    match @matcher.Matcher::shortest_match_at(self, hay, hs, he, 0) {
      Some(e) => Some(Confirmed(e))
      None => None
    }
  }
}

///|
/// A sink that records everything it sees.
struct KitchenSink {
  buf : StringBuilder
}

///|
fn KitchenSink::new() -> KitchenSink {
  { buf: StringBuilder(), }
}

///|
fn KitchenSink::as_string(self : KitchenSink) -> String {
  self.buf.to_string()
}

///|
impl Sink for KitchenSink with fn matched(self, _searcher, mat) {
  guard mat.bytes().length() > 0 else { abort("empty match") }
  let mut line_number = mat.line_number
  let mut byte_offset = mat.absolute_byte_offset
  for line in mat.lines() {
    if line_number is Some(n) {
      self.buf.write_string("\{n}:")
      line_number = Some(n + 1)
    }
    self.buf.write_string("\{byte_offset}:")
    byte_offset += line.length().to_int64()
    self.buf.write_string(@utf8.decode_lossy(line))
  }
  true
}

///|
impl Sink for KitchenSink with fn context(self, _searcher, context) {
  guard context.bytes().length() > 0 else { abort("empty context") }
  guard context.lines().length() == 1 else { abort("multi-line context") }
  if context.line_number is Some(n) {
    self.buf.write_string("\{n}-")
  }
  self.buf.write_string("\{context.absolute_byte_offset}-")
  self.buf.write_string(@utf8.decode_lossy(context.bytes()))
  true
}

///|
impl Sink for KitchenSink with fn context_break(self, _searcher) {
  self.buf.write_string("--\n")
  true
}

///|
impl Sink for KitchenSink with fn finish(self, _searcher, finish) {
  self.buf.write_string("\n")
  self.buf.write_string("byte count:\{finish.byte_count}\n")
  if finish.binary_byte_offset is Some(offset) {
    self.buf.write_string("binary offset:\{offset}\n")
  }
}

///|
struct SearcherTester {
  haystack : String
  pattern : String
  mut expected_no_line_number : String?
  mut expected_with_line_number : String?
  mut expected_slice_no_line_number : String?
  expected_slice_with_line_number : String?
  mut by_line : Bool
  multi_line : Bool
  mut invert_match : Bool
  mut line_number : Bool
  mut binary : BinaryDetection
  mut auto_heap_limit : Bool
  mut after_context : Int32
  mut before_context : Int32
  mut passthru : Bool
}

///|
fn SearcherTester::new(haystack : String, pattern : String) -> SearcherTester {
  {
    haystack,
    pattern,
    expected_no_line_number: None,
    expected_with_line_number: None,
    expected_slice_no_line_number: None,
    expected_slice_with_line_number: None,
    by_line: true,
    multi_line: true,
    invert_match: false,
    line_number: true,
    binary: BinaryNone,
    auto_heap_limit: true,
    after_context: 0,
    before_context: 0,
    passthru: false,
  }
}

///|
fn SearcherTester::expected_no_line_number(
  self : SearcherTester,
  exp : String,
) -> SearcherTester {
  self.expected_no_line_number = Some(exp)
  self
}

///|
fn SearcherTester::expected_with_line_number(
  self : SearcherTester,
  exp : String,
) -> SearcherTester {
  self.expected_with_line_number = Some(exp)
  self
}

///|
fn SearcherTester::expected_slice_no_line_number(
  self : SearcherTester,
  exp : String,
) -> SearcherTester {
  self.expected_slice_no_line_number = Some(exp)
  self
}

///|
fn SearcherTester::line_number(
  self : SearcherTester,
  yes : Bool,
) -> SearcherTester {
  self.line_number = yes
  self
}

///|
fn SearcherTester::by_line(self : SearcherTester, yes : Bool) -> SearcherTester {
  self.by_line = yes
  self
}

///|
fn SearcherTester::invert_match(
  self : SearcherTester,
  yes : Bool,
) -> SearcherTester {
  self.invert_match = yes
  self
}

///|
fn SearcherTester::binary_detection(
  self : SearcherTester,
  d : BinaryDetection,
) -> SearcherTester {
  self.binary = d
  self
}

///|
fn SearcherTester::auto_heap_limit(
  self : SearcherTester,
  yes : Bool,
) -> SearcherTester {
  self.auto_heap_limit = yes
  self
}

///|
fn SearcherTester::after_context(
  self : SearcherTester,
  n : Int32,
) -> SearcherTester {
  self.after_context = n
  self
}

///|
fn SearcherTester::before_context(
  self : SearcherTester,
  n : Int32,
) -> SearcherTester {
  self.before_context = n
  self
}

///|
fn SearcherTester::passthru(
  self : SearcherTester,
  yes : Bool,
) -> SearcherTester {
  self.passthru = yes
  self
}

///|
/// Splits like Rust's `str::lines` (no trailing empty line).
fn rust_lines(s : String) -> Array[String] {
  let out = []
  for part in s.split("\n") {
    out.push(part.to_owned())
  }
  if out.length() > 0 && out[out.length() - 1] == "" {
    ignore(out.pop())
  }
  out
}

///|
fn SearcherTester::minimal_heap_limit(
  self : SearcherTester,
  multi_line : Bool,
) -> Int32 {
  let hay_len = @utf8.encode(self.haystack).length()
  if multi_line {
    1 + hay_len
  } else if self.before_context == 0 && self.after_context == 0 {
    let mut m = 0
    for l in rust_lines(self.haystack) {
      let n = @utf8.encode(l).length()
      if n > m {
        m = n
      }
    }
    1 + m
  } else {
    let lens = rust_lines(self.haystack).map(l => @utf8.encode(l).length())
    lens.sort()
    lens.rev_in_place()
    let context_count = if self.passthru {
      rust_lines(self.haystack).length()
    } else {
      2 + self.before_context + self.after_context
    }
    let mut sum = 0
    for i, len in lens {
      if i >= context_count {
        break
      }
      sum += len + 1
    }
    sum
  }
}

///|
struct TesterConfig {
  label : String
  expected_reader : String
  expected_slice : String
  builder : SearcherConfig
  matcher : TestMatcher
}

///|
fn SearcherTester::configs(self : SearcherTester) -> Array[TesterConfig] {
  let configs = []
  let matcher = TestMatcher::new(self.pattern)
  let base : SearcherConfig = {
    ..SearcherConfig::default(),
    line_number: false,
    invert_match: self.invert_match,
    binary: self.binary,
    after_context: self.after_context,
    before_context: self.before_context,
    passthru: self.passthru,
  }
  if self.by_line {
    let matcher = matcher.copy()
    let expected_reader = self.expected_no_line_number.unwrap()
    let expected_slice = self.expected_slice_no_line_number.unwrap_or(
      expected_reader,
    )
    configs.push({
      label: "byline-noterm-nonumber",
      expected_reader,
      expected_slice,
      builder: base,
      matcher: matcher.copy(),
    })
    if self.auto_heap_limit {
      configs.push({
        label: "byline-noterm-nonumber-heaplimit",
        expected_reader,
        expected_slice,
        builder: { ..base, heap_limit: Some(self.minimal_heap_limit(false)), },
        matcher: matcher.copy(),
      })
    }
    matcher.line_term = Some(Byte(b'\n'))
    configs.push({
      label: "byline-term-nonumber",
      expected_reader,
      expected_slice,
      builder: base,
      matcher: matcher.copy(),
    })
    matcher.every_line_is_candidate = true
    configs.push({
      label: "byline-term-nonumber-candidates",
      expected_reader,
      expected_slice,
      builder: base,
      matcher: matcher.copy(),
    })
  }
  if self.by_line && self.line_number {
    let matcher = matcher.copy()
    let expected_reader = self.expected_with_line_number.unwrap()
    let expected_slice = self.expected_slice_with_line_number.unwrap_or(
      expected_reader,
    )
    let builder = { ..base, line_number: true, }
    configs.push({
      label: "byline-noterm-number",
      expected_reader,
      expected_slice,
      builder,
      matcher: matcher.copy(),
    })
    matcher.line_term = Some(Byte(b'\n'))
    configs.push({
      label: "byline-term-number",
      expected_reader,
      expected_slice,
      builder,
      matcher: matcher.copy(),
    })
    matcher.every_line_is_candidate = true
    configs.push({
      label: "byline-term-number-candidates",
      expected_reader,
      expected_slice,
      builder,
      matcher: matcher.copy(),
    })
  }
  if self.multi_line {
    let expected_slice = match self.expected_slice_no_line_number {
      None => self.expected_no_line_number.unwrap()
      Some(e) => e
    }
    let builder = { ..base, multi_line: true, }
    configs.push({
      label: "multiline-nonumber",
      expected_reader: expected_slice,
      expected_slice,
      builder,
      matcher: matcher.copy(),
    })
    if self.auto_heap_limit {
      configs.push({
        label: "multiline-nonumber-heaplimit",
        expected_reader: expected_slice,
        expected_slice,
        builder: { ..builder, heap_limit: Some(self.minimal_heap_limit(true)), },
        matcher: matcher.copy(),
      })
    }
  }
  if self.multi_line && self.line_number {
    let expected_slice = match self.expected_slice_with_line_number {
      None => self.expected_with_line_number.unwrap()
      Some(e) => e
    }
    let builder = { ..base, multi_line: true, line_number: true, }
    configs.push({
      label: "multiline-number",
      expected_reader: expected_slice,
      expected_slice,
      builder,
      matcher: matcher.copy(),
    })
    configs.push({
      label: "multiline-number-heaplimit",
      expected_reader: expected_slice,
      expected_slice,
      builder: { ..builder, heap_limit: Some(self.minimal_heap_limit(true)), },
      matcher: matcher.copy(),
    })
  }
  configs
}

///|
fn build_searcher(config : SearcherConfig) -> Searcher {
  let b = SearcherBuilder::new()
  b.config = config
  b.build()
}

///|
async fn TesterConfig::search_reader(
  self : TesterConfig,
  haystack : String,
) -> String {
  let sink = KitchenSink::new()
  let searcher = build_searcher(self.builder)
  searcher.search_reader(
    self.matcher,
    SliceReader::from_bytes(@utf8.encode(haystack)),
    sink,
  ) catch {
    e => abort("error running 'reader-\{self.label}': \{e}")
  }
  sink.as_string()
}

///|
async fn TesterConfig::search_slice(
  self : TesterConfig,
  haystack : String,
) -> String {
  let sink = KitchenSink::new()
  let searcher = build_searcher(self.builder)
  searcher.search_bytes(self.matcher, @utf8.encode(haystack), sink) catch {
    e => abort("error running 'slice-\{self.label}': \{e}")
  }
  sink.as_string()
}

///|
async fn SearcherTester::run(self : SearcherTester) -> Unit {
  guard self.expected_no_line_number is Some(_) else {
    abort("an 'expected' string with NO line numbers must be given")
  }
  if self.line_number && self.expected_with_line_number is None {
    abort("an 'expected' string with line numbers must be given")
  }
  let configs = self.configs()
  for config in configs {
    let got = config.search_reader(self.haystack)
    if got != config.expected_reader {
      fail(
        "reader-\{config.label}:\nexpected:\n\{config.expected_reader}\ngot:\n\{got}",
      )
    }
    let got = config.search_slice(self.haystack)
    if got != config.expected_slice {
      fail(
        "slice-\{config.label}:\nexpected:\n\{config.expected_slice}\ngot:\n\{got}",
      )
    }
  }
}

///|
fn SinkContext::bytes(self : SinkContext) -> Bytes {
  Bytes::from_array(self.buf[self.start:self.end])
}

///|
priv struct Lossy {
  f : (Int64, String) -> Bool raise
}

///|
fn Lossy::new(f : (Int64, String) -> Bool raise) -> Lossy {
  { f, }
}

///|
impl Sink for Lossy with fn matched(self, _searcher, mat) {
  guard mat.line_number is Some(n) else {
    raise SearchIOError("line numbers not enabled")
  }
  (self.f)(n, @utf8.decode_lossy(mat.bytes()))
}

///|
fn SinkMatch::bytes(self : SinkMatch) -> Bytes {
  Bytes::from_array(
    self.buf[self.buf_start + self.start:self.buf_start + self.end],
  )
}

///|
fn lines_of(bytes : Bytes, line_term : Byte) -> Array[Bytes] {
  let buf = bytes.to_fixedarray()
  let step = LineStep::new(line_term, 0, buf.length())
  let out = []
  while step.next(buf, 0) is Some(m) {
    out.push(bytes[m.start:m.end].to_owned())
  }
  out
}

///|
fn SinkMatch::lines(self : SinkMatch) -> Array[Bytes] {
  lines_of(self.bytes(), self.line_term.as_byte())
}

///|
fn SinkContext::lines(self : SinkContext) -> Array[Bytes] {
  lines_of(self.bytes(), self.line_term.as_byte())
}
