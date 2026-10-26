///|
/// Information passed to a sink when a search finishes.
pub(all) struct SinkFinish {
  byte_count : Int64
  binary_byte_offset : Int64?
} derive(Debug)

///|
/// A matching line (or lines, in multi-line mode). The matched bytes are
/// `buf[buf_start + start : buf_start + end]`, where `buf[buf_start :
/// buf_start + buf_len]` is the buffer being searched.
///
/// Like Rust's `&SinkMatch`, a value passed to a sink is only valid for the
/// duration of the call: the searcher reuses it for subsequent matches.
pub(all) struct SinkMatch {
  mut line_term : @matcher.LineTerminator
  mut buf : FixedArray[Byte]
  mut buf_start : Int32
  mut buf_len : Int32
  mut start : Int32
  mut end : Int32
  mut absolute_byte_offset : Int64
  mut line_number : Int64?
}

///|
/// Returns a copy of the matched bytes.
pub fn SinkMatch::bytes(self : SinkMatch) -> Bytes {
  Bytes::from_array(
    self.buf[self.buf_start + self.start:self.buf_start + self.end],
  )
}

///|
/// Returns each line in the match (including terminators).
pub fn SinkMatch::lines(self : SinkMatch) -> Array[Bytes] {
  lines_of(self.bytes(), self.line_term.as_byte())
}

///|
/// The kind of context line.
pub(all) enum SinkContextKind {
  Before
  After
  Other
} derive(Debug, Eq)

///|
/// A context line.
///
/// Like `SinkMatch`, a value passed to a sink is only valid for the duration
/// of the call.
pub(all) struct SinkContext {
  mut line_term : @matcher.LineTerminator
  mut buf : FixedArray[Byte]
  mut start : Int32
  mut end : Int32
  mut kind : SinkContextKind
  mut absolute_byte_offset : Int64
  mut line_number : Int64?
}

///|
/// Returns a copy of the context bytes.
pub fn SinkContext::bytes(self : SinkContext) -> Bytes {
  Bytes::from_array(self.buf[self.start:self.end])
}

///|
pub fn SinkContext::lines(self : SinkContext) -> Array[Bytes] {
  lines_of(self.bytes(), self.line_term.as_byte())
}

///|
/// A sink receives search results. Returning false from any method stops
/// the search; raising an error aborts it.
pub(open) trait Sink {
  async fn matched(Self, Searcher, SinkMatch) -> Bool
  async fn context(Self, Searcher, SinkContext) -> Bool = _
  async fn context_break(Self, Searcher) -> Bool = _
  async fn binary_data(Self, Searcher, Int64) -> Bool = _
  async fn begin(Self, Searcher) -> Bool = _
  async fn finish(Self, Searcher, SinkFinish) -> Unit = _
}

///|
impl Sink with fn context(_self, _searcher, _context) {
  true
}

///|
impl Sink with fn context_break(_self, _searcher) {
  true
}

///|
impl Sink with fn binary_data(_self, _searcher, _offset) {
  true
}

///|
impl Sink with fn begin(_self, _searcher) {
  true
}

///|
impl Sink with fn finish(_self, _searcher, _finish) {
  ()
}

///|
/// A sink that calls a function with the line number and the (lossily
/// decoded) matched text.
pub struct Lossy {
  priv f : (Int64, String) -> Bool raise
}

///|
pub fn Lossy::new(f : (Int64, String) -> Bool raise) -> Lossy {
  { f, }
}

///|
pub impl Sink for Lossy with fn matched(self, _searcher, mat) {
  guard mat.line_number is Some(n) else {
    raise SearchIOError("line numbers not enabled")
  }
  (self.f)(n, @utf8.decode_lossy(mat.bytes()))
}

///|
/// A sink that calls a function with the line number and matched bytes.
pub struct BytesSink {
  priv f : (Int64, Bytes) -> Bool raise
}

///|
pub fn BytesSink::new(f : (Int64, Bytes) -> Bool raise) -> BytesSink {
  { f, }
}

///|
pub impl Sink for BytesSink with fn matched(self, _searcher, mat) {
  guard mat.line_number is Some(n) else {
    raise SearchIOError("line numbers not enabled")
  }
  (self.f)(n, mat.bytes())
}
