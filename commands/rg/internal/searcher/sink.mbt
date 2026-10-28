///|
/// Information passed to a sink when a search finishes.
pub(all) struct SinkFinish {
  byte_count : Int64
  binary_byte_offset : Int64?
} derive(Debug)

///|
/// A matching span: one line, adjacent lines for an opted-in sink, or a
/// multi-line match. The matched bytes are
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
/// A sink receives search results. Returning false from any method stops
/// the search; raising an error aborts it.
pub(open) trait Sink {
  // Opt in to adjacent matching lines in one callback. Reader boundaries
  // and non-match gaps are never crossed.
  fn coalesce_matches(Self) -> Bool = _
  // Opt in to complete-reader line counts without per-match events. Binary,
  // begin and finish events retain their existing path; the count cannot stop.
  fn synchronous_count(Self) -> ((Int64) -> Unit)? = _
  // Opt in only for complete scans whose observable result is a final summary.
  // A larger read may detect binary data before earlier match callbacks.
  fn bulk_scan(Self) -> Bool = _
  // Opt in only when match handling needs no I/O or suspension. Reader loops
  // may call this callback synchronously; all other sink events stay ordered.
  fn synchronous_matched(Self) -> ((Searcher, SinkMatch) -> Bool)? = _
  async fn matched(Self, Searcher, SinkMatch) -> Bool
  async fn context(Self, Searcher, SinkContext) -> Bool = _
  async fn context_break(Self, Searcher) -> Bool = _
  async fn binary_data(Self, Searcher, Int64) -> Bool = _
  async fn begin(Self, Searcher) -> Bool = _
  async fn finish(Self, Searcher, SinkFinish) -> Unit = _
}

///|
impl Sink with fn coalesce_matches(_self) {
  false
}

///|
impl Sink with fn bulk_scan(_self) {
  false
}

///|
impl Sink with fn synchronous_count(_self) {
  None
}

///|
impl Sink with fn synchronous_matched(_self) {
  None
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
