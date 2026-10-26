///|
/// The binary detection mode for a searcher.
pub(all) enum BinaryDetection {
  /// No binary detection.
  BinaryNone
  /// Stop searching when the given byte is seen.
  BinaryQuit(Byte)
  /// Replace the given byte with the line terminator.
  BinaryConvert(Byte)
} derive(Debug, Eq)

///|
pub fn BinaryDetection::quit_byte(self : BinaryDetection) -> Byte? {
  match self {
    BinaryQuit(b) => Some(b)
    _ => None
  }
}

///|
pub fn BinaryDetection::convert_byte(self : BinaryDetection) -> Byte? {
  match self {
    BinaryConvert(b) => Some(b)
    _ => None
  }
}

///|
fn BinaryDetection::mode(self : BinaryDetection) -> BinaryMode {
  match self {
    BinaryNone => BNone
    BinaryQuit(b) => BQuit(b)
    BinaryConvert(b) => BConvert(b)
  }
}

///|
/// The configuration of a searcher.
pub(all) struct SearcherConfig {
  line_term : @matcher.LineTerminator
  invert_match : Bool
  after_context : Int32
  before_context : Int32
  passthru : Bool
  line_number : Bool
  heap_limit : Int32?
  binary : BinaryDetection
  multi_line : Bool
  encoding : Encoding?
  bom_sniffing : Bool
  stop_on_nonmatch : Bool
  max_matches : Int64?
}

///|
pub fn SearcherConfig::default() -> SearcherConfig {
  {
    line_term: @matcher.LineTerminator::default(),
    invert_match: false,
    after_context: 0,
    before_context: 0,
    passthru: false,
    line_number: true,
    heap_limit: None,
    binary: BinaryNone,
    multi_line: false,
    encoding: None,
    bom_sniffing: true,
    stop_on_nonmatch: false,
    max_matches: None,
  }
}

///|
fn SearcherConfig::max_context(self : SearcherConfig) -> Int32 {
  if self.before_context > self.after_context {
    self.before_context
  } else {
    self.after_context
  }
}

///|
fn SearcherConfig::line_buffer(self : SearcherConfig) -> LineBuffer {
  let (capacity, alloc) = match self.heap_limit {
    None => (DEFAULT_BUFFER_CAPACITY, Eager)
    Some(limit) =>
      if limit <= DEFAULT_BUFFER_CAPACITY {
        (limit, ErrorLimit(0))
      } else {
        (DEFAULT_BUFFER_CAPACITY, ErrorLimit(limit - DEFAULT_BUFFER_CAPACITY))
      }
  }
  LineBuffer::new(capacity, self.line_term.as_byte(), alloc, self.binary.mode())
}

///|
/// A builder for configuring a searcher.
pub struct SearcherBuilder {
  priv mut config : SearcherConfig
}

///|
pub fn SearcherBuilder::new() -> SearcherBuilder {
  { config: SearcherConfig::default(), }
}

///|
pub fn SearcherBuilder::build(self : SearcherBuilder) -> Searcher {
  let mut config = self.config
  if config.passthru {
    config = { ..config, before_context: 0, after_context: 0, }
  }
  {
    config,
    line_buffer: config.line_buffer(),
    multi_line_buffer: FixedArray::make(0, b'\x00'),
    multi_line_len: 0,
  }
}

///|
pub fn SearcherBuilder::line_terminator(
  self : SearcherBuilder,
  line_term : @matcher.LineTerminator,
) -> SearcherBuilder {
  self.config = { ..self.config, line_term, }
  self
}

///|
pub fn SearcherBuilder::invert_match(
  self : SearcherBuilder,
  yes : Bool,
) -> SearcherBuilder {
  self.config = { ..self.config, invert_match: yes, }
  self
}

///|
pub fn SearcherBuilder::line_number(
  self : SearcherBuilder,
  yes : Bool,
) -> SearcherBuilder {
  self.config = { ..self.config, line_number: yes, }
  self
}

///|
pub fn SearcherBuilder::multi_line(
  self : SearcherBuilder,
  yes : Bool,
) -> SearcherBuilder {
  self.config = { ..self.config, multi_line: yes, }
  self
}

///|
pub fn SearcherBuilder::after_context(
  self : SearcherBuilder,
  n : Int32,
) -> SearcherBuilder {
  self.config = { ..self.config, after_context: n, }
  self
}

///|
pub fn SearcherBuilder::before_context(
  self : SearcherBuilder,
  n : Int32,
) -> SearcherBuilder {
  self.config = { ..self.config, before_context: n, }
  self
}

///|
pub fn SearcherBuilder::passthru(
  self : SearcherBuilder,
  yes : Bool,
) -> SearcherBuilder {
  self.config = { ..self.config, passthru: yes, }
  self
}

///|
pub fn SearcherBuilder::heap_limit(
  self : SearcherBuilder,
  bytes : Int32?,
) -> SearcherBuilder {
  self.config = { ..self.config, heap_limit: bytes, }
  self
}

///|
pub fn SearcherBuilder::binary_detection(
  self : SearcherBuilder,
  detection : BinaryDetection,
) -> SearcherBuilder {
  self.config = { ..self.config, binary: detection, }
  self
}

///|
pub fn SearcherBuilder::encoding(
  self : SearcherBuilder,
  encoding : Encoding?,
) -> SearcherBuilder {
  self.config = { ..self.config, encoding, }
  self
}

///|
pub fn SearcherBuilder::bom_sniffing(
  self : SearcherBuilder,
  yes : Bool,
) -> SearcherBuilder {
  self.config = { ..self.config, bom_sniffing: yes, }
  self
}

///|
pub fn SearcherBuilder::stop_on_nonmatch(
  self : SearcherBuilder,
  yes : Bool,
) -> SearcherBuilder {
  self.config = { ..self.config, stop_on_nonmatch: yes, }
  self
}

///|
pub fn SearcherBuilder::max_matches(
  self : SearcherBuilder,
  limit : Int64?,
) -> SearcherBuilder {
  self.config = { ..self.config, max_matches: limit, }
  self
}

///|
/// A searcher executes searches over a haystack and reports results to a
/// sink.
pub struct Searcher {
  priv mut config : SearcherConfig
  priv line_buffer : LineBuffer
  priv mut multi_line_buffer : FixedArray[Byte]
  priv mut multi_line_len : Int32
}

///|
pub fn Searcher::new() -> Searcher {
  SearcherBuilder::new().build()
}

///|
/// Searches the given reader.
pub async fn Searcher::search_reader(
  self : Searcher,
  matcher : &@matcher.Matcher,
  rdr : &Reader,
  sink : &Sink,
) -> Unit {
  self.check_config(matcher)
  let decoder : &Reader = DecodeReader::new(
    rdr,
    self.config.encoding.map(e => e.kind),
    self.config.bom_sniffing,
  )
  if self.multi_line_with_matcher(matcher) {
    self.fill_multi_line_buffer_from_reader(decoder)
    MultiLine::new(
      self,
      matcher,
      self.multi_line_buffer,
      self.multi_line_len,
      sink,
    ).run()
  } else {
    self.line_buffer.clear()
    ReadByLine::new(self, matcher, decoder, sink).run()
  }
}

///|
/// Searches the given slice `buf[0:len]`.
pub async fn Searcher::search_slice(
  self : Searcher,
  matcher : &@matcher.Matcher,
  buf : FixedArray[Byte],
  len : Int32,
  sink : &Sink,
) -> Unit {
  self.check_config(matcher)
  if self.slice_needs_transcoding(buf, len) {
    self.search_reader(matcher, SliceReader::new(buf, 0, len), sink)
    return
  }
  if self.multi_line_with_matcher(matcher) {
    MultiLine::new(self, matcher, buf, len, sink).run()
  } else {
    SliceByLine::new(self, matcher, buf, len, sink).run()
  }
}

///|
/// Convenience: searches a byte string.
pub async fn Searcher::search_bytes(
  self : Searcher,
  matcher : &@matcher.Matcher,
  bytes : Bytes,
  sink : &Sink,
) -> Unit {
  let buf = bytes.to_fixedarray()
  self.search_slice(matcher, buf, buf.length(), sink)
}

///|
pub fn Searcher::set_binary_detection(
  self : Searcher,
  detection : BinaryDetection,
) -> Unit {
  self.config = { ..self.config, binary: detection, }
  self.line_buffer.binary = detection.mode()
}

///|
fn Searcher::check_config(
  self : Searcher,
  matcher : &@matcher.Matcher,
) -> Unit raise SearchError {
  if self.config.heap_limit == Some(0) {
    raise ConfigError("grep config error: no available searchers")
  }
  guard matcher.line_terminator() is Some(mlt) else { return }
  if mlt != self.config.line_term {
    raise ConfigError(
      "grep config error: mismatched line terminators, matcher has \{line_term_debug(mlt)} but searcher has \{line_term_debug(self.config.line_term)}",
    )
  }
}

///|
fn line_term_debug(lt : @matcher.LineTerminator) -> String {
  match lt {
    CRLF => "LineTerminator(CRLF)"
    Byte(b) => "LineTerminator(Byte(\{b.to_int()}))"
  }
}

///|
fn Searcher::slice_needs_transcoding(
  self : Searcher,
  buf : FixedArray[Byte],
  len : Int32,
) -> Bool {
  self.config.encoding is Some(_) ||
  (self.config.bom_sniffing && slice_has_bom(buf, 0, len))
}

///|
pub fn Searcher::line_terminator(self : Searcher) -> @matcher.LineTerminator {
  self.config.line_term
}

///|
pub fn Searcher::binary_detection(self : Searcher) -> BinaryDetection {
  self.config.binary
}

///|
pub fn Searcher::invert_match(self : Searcher) -> Bool {
  self.config.invert_match
}

///|
pub fn Searcher::line_number(self : Searcher) -> Bool {
  self.config.line_number
}

///|
pub fn Searcher::multi_line(self : Searcher) -> Bool {
  self.config.multi_line
}

///|
pub fn Searcher::stop_on_nonmatch(self : Searcher) -> Bool {
  self.config.stop_on_nonmatch
}

///|
pub fn Searcher::max_matches(self : Searcher) -> Int64? {
  self.config.max_matches
}

///|
/// Returns true if this searcher will search in multi-line mode with the
/// given matcher.
pub fn Searcher::multi_line_with_matcher(
  self : Searcher,
  matcher : &@matcher.Matcher,
) -> Bool {
  if !self.multi_line() {
    return false
  }
  if matcher.line_terminator() is Some(lt) && lt == self.line_terminator() {
    return false
  }
  if matcher.non_matching_bytes() is Some(nm) &&
    nm.contains(self.line_terminator().as_byte()) {
    return false
  }
  true
}

///|
pub fn Searcher::after_context(self : Searcher) -> Int32 {
  self.config.after_context
}

///|
pub fn Searcher::before_context(self : Searcher) -> Int32 {
  self.config.before_context
}

///|
pub fn Searcher::passthru(self : Searcher) -> Bool {
  self.config.passthru
}

///|
async fn Searcher::fill_multi_line_buffer_from_reader(
  self : Searcher,
  rdr : &Reader,
) -> Unit {
  let limit = self.config.heap_limit
  if limit == Some(0) {
    raise alloc_error(0)
  }
  let initial = match limit {
    Some(l) =>
      if l < DEFAULT_BUFFER_CAPACITY {
        l
      } else {
        DEFAULT_BUFFER_CAPACITY
      }
    None => DEFAULT_BUFFER_CAPACITY
  }
  let mut buf = if self.multi_line_buffer.length() >= initial {
    self.multi_line_buffer
  } else {
    FixedArray::make(initial, b'\x00')
  }
  let mut pos = 0
  while true {
    if pos == buf.length() {
      let newlen = match limit {
        None => buf.length() * 2
        Some(l) => {
          if buf.length() >= l {
            raise alloc_error(l)
          }
          if buf.length() * 2 < l {
            buf.length() * 2
          } else {
            l
          }
        }
      }
      let nb = FixedArray::make(newlen, b'\x00')
      buf.blit_to(nb, len=pos, src_offset=0, dst_offset=0)
      buf = nb
    }
    let n = rdr.read(buf, pos, buf.length() - pos)
    if n == 0 {
      break
    }
    pos += n
  }
  self.multi_line_buffer = buf
  self.multi_line_len = pos
}
