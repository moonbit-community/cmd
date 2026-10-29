///|
/// Searches a reader by filling a line buffer.
priv struct ReadByLine {
  config : SearcherConfig
  core : Core
  rdr : &Reader
  lb : LineBuffer
}

///|
fn ReadByLine::new(
  searcher : Searcher,
  matcher : &@matcher.Matcher,
  rdr : &Reader,
  sink : &Sink,
) -> ReadByLine {
  {
    config: searcher.config,
    core: Core::new(searcher, matcher, sink, false),
    rdr,
    lb: searcher.line_buffer,
  }
}

///|
fn ReadByLine::win(self : ReadByLine) -> Win {
  { arr: self.lb.buf, off: self.lb.pos, len: self.lb.buffer_len(), }
}

///|
async fn ReadByLine::run(
  self : ReadByLine,
  begun~ : Bool = false,
  prefetched~ : Bool = false,
  ended~ : Bool = false,
) -> Unit {
  if begun || self.core.begin() {
    // A declined probe is already decoded in this reader's original buffer.
    // Process its complete records before another read can report an error.
    if prefetched && (ended || self.lb.buffer_len() > 0) {
      let keep_reading = self.core.match_by_line(self.win())
      if ended || !keep_reading {
        self.lb.consume(self.core.pos)
        self.core.finish(
          self.lb.absolute_byte_offset,
          self.lb.binary_byte_offset,
        )
        return
      }
    }
    while self.fill() {
      if !self.core.match_by_line(self.win()) {
        self.lb.consume(self.core.pos)
        break
      }
    }
  }
  self.core.finish(self.lb.absolute_byte_offset, self.lb.binary_byte_offset)
}

///|
async fn ReadByLine::fill(self : ReadByLine) -> Bool {
  let already_binary = self.lb.binary_byte_offset is Some(_)
  let old_buf_len = self.lb.buffer_len()
  let consumed = self.core.roll(self.win())
  self.lb.consume(consumed)
  let didread = self.lb.fill(self.rdr)
  if !already_binary {
    if self.lb.binary_byte_offset is Some(offset) {
      if !self.core.binary_data(offset) {
        return false
      }
    }
  }
  if !didread || self.should_binary_quit() {
    return false
  }
  if consumed == 0 && old_buf_len == self.lb.buffer_len() {
    self.lb.consume(old_buf_len)
    return false
  }
  true
}

///|
fn ReadByLine::should_binary_quit(self : ReadByLine) -> Bool {
  self.lb.binary_byte_offset is Some(_) &&
  self.config.binary.quit_byte() is Some(_)
}

///|
/// Searches an in-memory slice line by line.
priv struct SliceByLine {
  core : Core
  buf : Win
}

///|
fn SliceByLine::new(
  searcher : Searcher,
  matcher : &@matcher.Matcher,
  arr : FixedArray[Byte],
  len : Int32,
  sink : &Sink,
) -> SliceByLine {
  {
    core: Core::new(searcher, matcher, sink, true),
    buf: { arr, off: 0, len, },
  }
}

///|
async fn SliceByLine::run(self : SliceByLine) -> Unit {
  if self.core.begin() {
    let binary_upto = if self.buf.len < DEFAULT_BUFFER_CAPACITY {
      self.buf.len
    } else {
      DEFAULT_BUFFER_CAPACITY
    }
    if !self.core.detect_binary(self.buf, 0, binary_upto) {
      while self.core.pos < self.buf.len && self.core.match_by_line(self.buf) {

      }
    }
  }
  let byte_count = self.byte_count()
  self.core.finish(byte_count, self.core.binary_byte_offset_i64())
}

///|
fn SliceByLine::byte_count(self : SliceByLine) -> Int64 {
  match self.core.binary_byte_offset {
    Some(offset) if offset < self.core.pos => offset.to_int64()
    _ => self.core.pos.to_int64()
  }
}

///|
/// Searches an in-memory slice where matches may span multiple lines.
priv struct MultiLine {
  config : SearcherConfig
  core : Core
  buf : Win
  mut last_match : @matcher.Match?
}

///|
fn MultiLine::new(
  searcher : Searcher,
  matcher : &@matcher.Matcher,
  arr : FixedArray[Byte],
  len : Int32,
  sink : &Sink,
) -> MultiLine {
  {
    config: searcher.config,
    core: Core::new(searcher, matcher, sink, true),
    buf: { arr, off: 0, len, },
    last_match: None,
  }
}

///|
async fn MultiLine::run(self : MultiLine) -> Unit {
  if self.core.begin() {
    let binary_upto = if self.buf.len < DEFAULT_BUFFER_CAPACITY {
      self.buf.len
    } else {
      DEFAULT_BUFFER_CAPACITY
    }
    if !self.core.detect_binary(self.buf, 0, binary_upto) {
      let mut keepgoing = true
      while self.core.pos < self.buf.len && keepgoing {
        keepgoing = self.sink()
      }
      if keepgoing {
        keepgoing = match self.last_match {
          None => true
          Some(last_match) => {
            self.last_match = None
            if self.sink_context(last_match) {
              ignore(self.sink_matched(last_match))
            }
            true
          }
        }
      }
      if keepgoing {
        if self.config.passthru {
          ignore(self.core.other_context_by_line(self.buf, self.buf.len))
        } else {
          ignore(self.core.after_context_by_line(self.buf, self.buf.len))
        }
      }
    }
  }
  let byte_count = self.byte_count()
  self.core.finish(byte_count, self.core.binary_byte_offset_i64())
}

///|
async fn MultiLine::sink(self : MultiLine) -> Bool {
  if self.config.invert_match {
    return self.sink_matched_inverted()
  }
  let mat = match self.core.find(self.buf, self.core.pos) {
    Some(m) => m
    None => {
      self.core.pos = self.buf.len
      return true
    }
  }
  self.advance(mat)
  let line = locate(
    self.buf.arr,
    self.buf.off,
    self.buf.len,
    self.config.line_term.as_byte(),
    mat,
  )
  match self.last_match {
    None => {
      self.last_match = Some(line)
      true
    }
    Some(last_match) =>
      if last_match.end >= line.start {
        self.last_match = Some(last_match.with_end(line.end))
        true
      } else {
        self.last_match = Some(line)
        if !self.sink_context(last_match) {
          return false
        }
        self.sink_matched(last_match)
      }
  }
}

///|
async fn MultiLine::sink_matched_inverted(self : MultiLine) -> Bool {
  let invert_match : @matcher.Match = match
    self.core.find(self.buf, self.core.pos) {
    None => {
      let range : @matcher.Match = { start: self.core.pos, end: self.buf.len, }
      self.core.pos = range.end
      range
    }
    Some(mat) => {
      let line = locate(
        self.buf.arr,
        self.buf.off,
        self.buf.len,
        self.config.line_term.as_byte(),
        mat,
      )
      let range : @matcher.Match = { start: self.core.pos, end: line.start, }
      self.advance(line)
      range
    }
  }
  if invert_match.is_empty() {
    return true
  }
  if !self.sink_context(invert_match) {
    return false
  }
  let stepper = LineStep::new(
    self.config.line_term.as_byte(),
    invert_match.start,
    invert_match.end,
  )
  while stepper.next(self.buf.arr, self.buf.off) is Some(line) {
    if !self.sink_matched(line) {
      return false
    }
  }
  true
}

///|
async fn MultiLine::sink_matched(
  self : MultiLine,
  range : @matcher.Match,
) -> Bool {
  if range.is_empty() {
    return false
  }
  self.core.matched(self.buf, range)
}

///|
async fn MultiLine::sink_context(
  self : MultiLine,
  range : @matcher.Match,
) -> Bool {
  if self.config.passthru {
    if !self.core.other_context_by_line(self.buf, range.start) {
      return false
    }
  } else {
    if !self.core.after_context_by_line(self.buf, range.start) {
      return false
    }
    if !self.core.before_context_by_line(self.buf, range.start) {
      return false
    }
  }
  true
}

///|
fn MultiLine::advance(self : MultiLine, range : @matcher.Match) -> Unit {
  self.core.pos = range.end
  if range.is_empty() && self.core.pos < self.buf.len {
    self.core.pos += 1
  }
}

///|
fn MultiLine::byte_count(self : MultiLine) -> Int64 {
  match self.core.binary_byte_offset {
    Some(offset) if offset < self.core.pos => offset.to_int64()
    _ => self.core.pos.to_int64()
  }
}
