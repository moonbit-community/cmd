///|
/// Bound the optional record copy independently of previous long records.
let maximum_buffered_match_bytes : Int32 = 65536

///|
/// Use the existing block-output permission for bounded synchronous delivery.
/// Styled, captured, statistical and replacement output keeps ordered events.
pub impl @searcher.Sink for StandardSink with fn buffered_matched(self) {
  let config = self.standard.config
  if config.coalesce_matches &&
    !self.needs_match_granularity &&
    !self.standard.wtr.supports_color() &&
    config.hyperlink.format.is_empty() {
    Some((searcher, mat) => self.try_buffer_match(searcher, mat))
  } else {
    None
  }
}

///|
fn StandardSink::try_buffer_match(
  self : StandardSink,
  searcher : @searcher.Searcher,
  mat : @searcher.SinkMatch,
) -> Bool raise {
  // The first event may emit file headings or separators. Binary events keep
  // their ordinary stop/diagnostic path. A decline changes no visible state.
  if self.standard.wtr.count() == 0 || self.binary_byte_offset is Some(_) {
    return false
  }
  let imp = StandardImpl::from_match(searcher, self, mat)
  if imp.multi_line() {
    return false
  }
  if !imp.try_buffer_line(
      mat.absolute_byte_offset,
      mat.line_number,
      None,
      imp.sunk.buf,
      imp.sunk.start,
      imp.sunk.end,
    ) {
    return false
  }
  self.match_count += 1
  true
}

///|
/// Admit one fully formatted plain record atomically. Match extraction,
/// replacement and statistics remain with the ordinary sink event. Declining
/// changes no output or counters, so the caller may use its ordered writer.
fn StandardImpl::try_buffer_line(
  self : StandardImpl,
  absolute_byte_offset : Int64,
  line_number : Int64?,
  column : Int64?,
  buf : FixedArray[Byte],
  start : Int32,
  end : Int32,
) -> Bool raise {
  if !self.config().coalesce_matches ||
    self.wtr().supports_color() ||
    !self.config().hyperlink.format.is_empty() {
    return false
  }
  let range = self.trim_ascii_prefix(
    buf,
    start,
    @matcher.Match::new(0, end - start),
  )
  let start = start + range.start
  if end - start > maximum_buffered_match_bytes ||
    self.exceeds_max_columns(end - start) {
    return false
  }
  let bytes = match self.plain_prelude {
    Some(bytes) => bytes
    None => {
      let bytes = @termcolor.ByteVec::new()
      self.plain_prelude = Some(bytes)
      bytes
    }
  }
  format_plain_prelude(
    bytes,
    if self.config().heading {
      None
    } else {
      self.path().map(p => p.bytes)
    },
    self.config().path_terminator,
    line_number,
    if self.config().column {
      column
    } else {
      None
    },
    if self.config().byte_offset {
      Some(absolute_byte_offset)
    } else {
      None
    },
    self.separator_field(),
  )
  let ending = if self.has_line_terminator(buf, start, end) {
    b""
  } else {
    self.searcher.line_terminator().as_bytes()
  }
  if bytes.length() >
    maximum_buffered_match_bytes - (end - start) - ending.length() {
    return false
  }
  if bytes.length() == 0 && ending.is_empty() {
    if !@termcolor.Write::try_write_slice(self.wtr(), buf, start, end) {
      return false
    }
    return true
  }
  bytes.extend_slice(buf, start, end)
  bytes.extend_bytes(ending)
  if !@termcolor.Write::try_write_slice(
      self.wtr(),
      bytes.storage(),
      0,
      bytes.length(),
    ) {
    return false
  }
  true
}
