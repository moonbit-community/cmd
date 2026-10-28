///|
/// A window `arr[off : off + len]` of a byte buffer. Ranges used by the
/// core are relative to `off`.
priv struct Win {
  arr : FixedArray[Byte]
  off : Int32
  len : Int32
}

///|
priv enum FastMatchResult {
  Continue
  Stop
  SwitchToSlow
}

///|
priv struct Core {
  config : SearcherConfig
  matcher : &@matcher.Matcher
  searcher : Searcher
  sink : &Sink
  synchronous_matched : ((Searcher, SinkMatch) -> Bool)?
  synchronous_count : ((Int64) -> Unit)?
  mut coalesce_matches : Bool
  mut pending_match : @matcher.Match?
  binary : Bool
  mut pos : Int32
  mut absolute_byte_offset : Int64
  mut binary_byte_offset : Int32?
  mut line_number : Int64?
  mut last_line_counted : Int32
  mut last_line_visited : Int32
  mut after_context_left : Int32
  mut has_sunk : Bool
  mut has_matched : Bool
  mut count : Int64
  /// Reused for every call to the sink (see `SinkMatch`).
  sink_match : SinkMatch
  sink_ctx : SinkContext
}

///|
fn Core::new(
  searcher : Searcher,
  matcher : &@matcher.Matcher,
  sink : &Sink,
  binary : Bool,
) -> Core {
  {
    config: searcher.config,
    matcher,
    searcher,
    sink,
    synchronous_matched: sink.synchronous_matched(),
    coalesce_matches: !binary &&
    !searcher.config.invert_match &&
    searcher.config.max_matches is None &&
    searcher.config.max_context() == 0 &&
    !searcher.config.line_number &&
    !searcher.config.passthru &&
    !searcher.config.stop_on_nonmatch &&
    !searcher.config.multi_line &&
    sink.coalesce_matches(),
    pending_match: None,
    synchronous_count: if !binary &&
      !searcher.config.invert_match &&
      searcher.config.max_matches is None &&
      searcher.config.max_context() == 0 &&
      !searcher.config.passthru &&
      !searcher.config.stop_on_nonmatch &&
      !searcher.config.multi_line &&
      searcher.config.binary.quit_byte() is None {
      sink.synchronous_count()
    } else {
      None
    },
    binary,
    pos: 0,
    absolute_byte_offset: 0,
    binary_byte_offset: None,
    line_number: if searcher.config.line_number {
      Some(1)
    } else {
      None
    },
    last_line_counted: 0,
    last_line_visited: 0,
    after_context_left: 0,
    has_sunk: false,
    has_matched: false,
    count: 0,
    sink_match: {
      line_term: searcher.config.line_term,
      buf: [],
      buf_start: 0,
      buf_len: 0,
      start: 0,
      end: 0,
      absolute_byte_offset: 0,
      line_number: None,
    },
    sink_ctx: {
      line_term: searcher.config.line_term,
      buf: [],
      start: 0,
      end: 0,
      kind: Other,
      absolute_byte_offset: 0,
      line_number: None,
    },
  }
}

///|
fn Core::lineterm(self : Core) -> Byte {
  self.config.line_term.as_byte()
}

///|
fn Core::binary_byte_offset_i64(self : Core) -> Int64? {
  self.binary_byte_offset.map(x => x.to_int64())
}

///|
async fn Core::matched(self : Core, buf : Win, range : @matcher.Match) -> Bool {
  self.sink_matched(buf, range.start, range.end)
}

///|
async fn Core::binary_data(self : Core, offset : Int64) -> Bool {
  self.coalesce_matches = false
  self.sink.binary_data(self.searcher, offset)
}

///|
fn Core::is_match(self : Core, buf : Win, line : @matcher.Match) -> Bool {
  let s = buf.off + line.start
  let e = without_terminator(
    buf.arr,
    s,
    buf.off + line.end,
    self.config.line_term,
  )
  @matcher.is_match_at(self.matcher, buf.arr, s, e, 0)
}

///|
fn Core::find(self : Core, buf : Win, at : Int32) -> @matcher.Match? {
  if self.has_exceeded_match_limit() {
    return None
  }
  match self.matcher.find_at(buf.arr, buf.off + at, buf.off + buf.len, 0) {
    None => None
    Some(m) => {
      self.count += 1
      Some(m.offset(at))
    }
  }
}

///|
fn Core::shortest_match(
  self : Core,
  arr : FixedArray[Byte],
  s : Int32,
  e : Int32,
) -> Int32? {
  if self.has_exceeded_match_limit() {
    return None
  }
  self.matcher.shortest_match_at(arr, s, e, 0)
}

///|
async fn Core::begin(self : Core) -> Bool {
  self.sink.begin(self.searcher)
}

///|
async fn Core::finish(
  self : Core,
  byte_count : Int64,
  binary_byte_offset : Int64?,
) -> Unit {
  self.sink.finish(self.searcher, { byte_count, binary_byte_offset, })
}

///|
async fn Core::match_by_line(self : Core, buf : Win) -> Bool {
  if self.is_line_by_line_fast() {
    if self.synchronous_count is Some(accept) {
      self.match_count_batch(buf, accept)
      return true
    }
    if self.coalesce_matches {
      return self.match_by_line_spans(buf)
    }
    if !self.binary &&
      !self.config.invert_match &&
      self.config.max_context() == 0 &&
      !self.config.stop_on_nonmatch &&
      self.synchronous_matched is Some(accept) {
      return self.match_by_line_synchronous(buf, accept)
    }
    match self.match_by_line_fast(buf) {
      SwitchToSlow => self.match_by_line_slow(buf)
      Continue => true
      Stop => false
    }
  } else {
    self.match_by_line_slow(buf)
  }
}

///|
fn Core::next_match_span(self : Core, buf : Win) -> @matcher.Match? {
  let first = match self.pending_match {
    Some(line) => {
      self.pending_match = None
      line
    }
    None => {
      guard self.find_by_line_fast(buf) is Some(line) else { return None }
      line
    }
  }
  self.count += 1
  self.has_matched = true
  self.pos = first.end
  while self.pos < buf.len {
    guard self.find_by_line_fast(buf) is Some(next) else { break }
    if next.start != self.pos {
      self.pending_match = Some(next)
      break
    }
    self.count += 1
    self.pos = next.end
  }
  Some({ start: first.start, end: self.pos, })
}

///|
async fn Core::match_by_line_spans(self : Core, buf : Win) -> Bool {
  while self.next_match_span(buf) is Some(span) {
    if !self.sink_matched(buf, span.start, span.end) {
      return false
    }
  }
  self.pos = buf.len
  true
}

///|
// Confirmed matches need only the next line boundary. Candidates retain their
// full-line verification. The caller has excluded every early-stop mode.
fn Core::match_count_batch(
  self : Core,
  buf : Win,
  accept : (Int64) -> Unit,
) -> Unit {
  if self.matcher.count_matching_lines(
      buf.arr,
      buf.off + self.pos,
      buf.off + buf.len,
      self.lineterm(),
    )
    is Some(count) {
    if count > 0 {
      self.count += count
      self.has_matched = true
      self.has_sunk = true
      self.last_line_visited = buf.len
      self.after_context_left = 0
      accept(count)
    }
    self.pos = buf.len
    return
  }
  let term = self.lineterm()
  let mut pos = self.pos
  let mut count = 0L
  let mut last = self.last_line_visited
  while pos < buf.len {
    match
      self.matcher.find_candidate_line(
        buf.arr,
        buf.off + pos,
        buf.off + buf.len,
      ) {
      None => break
      Some(Confirmed(end)) => {
        let end = pos + end
        if end == buf.len && buf.arr[buf.off + end - 1] == term {
          break
        }
        pos = match find_byte(buf.arr, term, buf.off + end, buf.off + buf.len) {
          Some(next) => next - buf.off + 1
          None => buf.len
        }
        count += 1
        last = pos
      }
      Some(Candidate(end)) => {
        let line = locate(buf.arr, buf.off, buf.len, term, {
          start: pos + end,
          end: pos + end,
        })
        if line.start == buf.len {
          break
        }
        pos = line.end
        if self.is_match(buf, line) {
          count += 1
          last = pos
        }
      }
    }
  }
  if count > 0 {
    self.count += count
    self.has_matched = true
    self.has_sunk = true
    self.last_line_visited = last
    self.after_context_left = 0
    accept(count)
  }
  self.pos = buf.len
}

///|
// The reader has already performed binary detection. Context, inversion and
// slice/multiline searches keep their existing event-driven path.
fn Core::match_by_line_synchronous(
  self : Core,
  buf : Win,
  accept : (Searcher, SinkMatch) -> Bool,
) -> Bool {
  while self.pos < buf.len {
    guard self.find_by_line_fast(buf) is Some(line) else { break }
    self.has_matched = true
    self.count += 1
    self.pos = line.end
    self.count_lines(buf, line.start)
    let mat = self.sink_match
    mat.buf = buf.arr
    mat.buf_start = buf.off
    mat.buf_len = buf.len
    mat.start = line.start
    mat.end = line.end
    mat.absolute_byte_offset = self.absolute_byte_offset + line.start.to_int64()
    mat.line_number = self.line_number
    if !accept(self.searcher, mat) {
      return false
    }
    self.last_line_visited = line.end
    self.after_context_left = 0
    self.has_sunk = true
  }
  if self.has_exceeded_match_limit() {
    return false
  }
  self.pos = buf.len
  true
}

///|
fn Core::roll(self : Core, buf : Win) -> Int32 {
  let consumed = if self.config.max_context() == 0 {
    buf.len
  } else {
    let context_start = preceding(
      buf.arr,
      buf.off,
      buf.len,
      self.lineterm(),
      self.config.before_context,
    )
    if context_start > self.last_line_visited {
      context_start
    } else {
      self.last_line_visited
    }
  }
  self.count_lines(buf, consumed)
  self.absolute_byte_offset += consumed.to_int64()
  self.last_line_counted = 0
  self.last_line_visited = 0
  self.pos = buf.len - consumed
  consumed
}

///|
async fn Core::detect_binary(
  self : Core,
  buf : Win,
  start : Int32,
  end : Int32,
) -> Bool {
  if self.binary_byte_offset is Some(_) {
    return self.config.binary.quit_byte() is Some(_)
  }
  let binary_byte = match self.config.binary {
    BinaryQuit(b) => b
    BinaryConvert(b) => b
    BinaryNone => return false
  }
  match find_byte(buf.arr, binary_byte, buf.off + start, buf.off + end) {
    Some(i) => {
      let offset = i - buf.off
      self.binary_byte_offset = Some(offset)
      if !self.binary_data(offset.to_int64()) {
        return true
      }
      self.config.binary.quit_byte() is Some(_)
    }
    None => false
  }
}

///|
async fn Core::before_context_by_line(
  self : Core,
  buf : Win,
  upto : Int32,
) -> Bool {
  if self.config.before_context == 0 {
    return true
  }
  let range : @matcher.Match = { start: self.last_line_visited, end: upto, }
  if range.is_empty() {
    return true
  }
  let before_context_start = range.start +
    preceding(
      buf.arr,
      buf.off + range.start,
      range.len(),
      self.lineterm(),
      self.config.before_context - 1,
    )
  let stepper = LineStep::new(self.lineterm(), before_context_start, range.end)
  while stepper.advance(buf.arr, buf.off) {
    let (ls, le) = (stepper.line_start(), stepper.line_end())
    if !self.sink_break_context(ls) {
      return false
    }
    if !self.sink_before_context(buf, ls, le) {
      return false
    }
  }
  true
}

///|
async fn Core::after_context_by_line(
  self : Core,
  buf : Win,
  upto : Int32,
) -> Bool {
  if self.after_context_left == 0 {
    return true
  }
  let exceeded_match_limit = self.has_exceeded_match_limit()
  let stepper = LineStep::new(self.lineterm(), self.last_line_visited, upto)
  while stepper.advance(buf.arr, buf.off) {
    let (ls, le) = (stepper.line_start(), stepper.line_end())
    if exceeded_match_limit &&
      self.is_match(buf, { start: ls, end: le, }) != self.config.invert_match {
      let after_context_left = self.after_context_left
      self.pos = le
      if !self.sink_matched(buf, ls, le) {
        return false
      }
      self.after_context_left = after_context_left - 1
    } else if !self.sink_after_context(buf, ls, le) {
      return false
    }
    if self.after_context_left == 0 {
      break
    }
  }
  true
}

///|
async fn Core::other_context_by_line(
  self : Core,
  buf : Win,
  upto : Int32,
) -> Bool {
  let stepper = LineStep::new(self.lineterm(), self.last_line_visited, upto)
  while stepper.advance(buf.arr, buf.off) {
    if !self.sink_other_context(buf, stepper.line_start(), stepper.line_end()) {
      return false
    }
  }
  true
}

///|
async fn Core::match_by_line_slow(self : Core, buf : Win) -> Bool {
  let stepper = LineStep::new(self.lineterm(), self.pos, buf.len)
  while stepper.next(buf.arr, buf.off) is Some(line) {
    if self.has_exceeded_match_limit() &&
      !self.config.passthru &&
      self.after_context_left == 0 {
      return false
    }
    let matched = {
      let s = buf.off + line.start
      let e = without_terminator(
        buf.arr,
        s,
        buf.off + line.end,
        self.config.line_term,
      )
      self.shortest_match(buf.arr, s, e) is Some(_)
    }
    self.pos = line.end
    let success = matched != self.config.invert_match
    if success {
      self.has_matched = true
      self.count += 1
      if !self.before_context_by_line(buf, line.start) {
        return false
      }
      if !self.sink_matched(buf, line.start, line.end) {
        return false
      }
    } else if self.after_context_left >= 1 {
      if !self.sink_after_context(buf, line.start, line.end) {
        return false
      }
    } else if self.config.passthru {
      if !self.sink_other_context(buf, line.start, line.end) {
        return false
      }
    }
    if self.config.stop_on_nonmatch && !success && self.has_matched {
      return false
    }
  }
  true
}

///|
async fn Core::match_by_line_fast(self : Core, buf : Win) -> FastMatchResult {
  while self.pos < buf.len {
    if self.config.stop_on_nonmatch && self.has_matched {
      return SwitchToSlow
    }
    if self.config.invert_match {
      if !self.match_by_line_fast_invert(buf) {
        break
      }
    } else if self.find_by_line_fast(buf) is Some(line) {
      self.has_matched = true
      self.count += 1
      if self.config.max_context() > 0 {
        if !self.after_context_by_line(buf, line.start) {
          return Stop
        }
        if !self.before_context_by_line(buf, line.start) {
          return Stop
        }
      }
      self.pos = line.end
      if !self.sink_matched(buf, line.start, line.end) {
        return Stop
      }
    } else {
      break
    }
  }
  if !self.after_context_by_line(buf, buf.len) {
    return Stop
  }
  if self.has_exceeded_match_limit() && self.after_context_left == 0 {
    return Stop
  }
  self.pos = buf.len
  Continue
}

///|
async fn Core::match_by_line_fast_invert(self : Core, buf : Win) -> Bool {
  let invert_match : @matcher.Match = match self.find_by_line_fast(buf) {
    None => {
      let range : @matcher.Match = { start: self.pos, end: buf.len, }
      self.pos = range.end
      range
    }
    Some(line) => {
      let range : @matcher.Match = { start: self.pos, end: line.start, }
      self.pos = line.end
      range
    }
  }
  if invert_match.is_empty() {
    return true
  }
  self.has_matched = true
  if !self.after_context_by_line(buf, invert_match.start) {
    return false
  }
  if !self.before_context_by_line(buf, invert_match.start) {
    return false
  }
  let stepper = LineStep::new(
    self.lineterm(),
    invert_match.start,
    invert_match.end,
  )
  while stepper.advance(buf.arr, buf.off) {
    self.count += 1
    if !self.sink_matched(buf, stepper.line_start(), stepper.line_end()) {
      return false
    }
    if self.has_exceeded_match_limit() {
      return false
    }
  }
  true
}

///|
fn Core::find_by_line_fast(self : Core, buf : Win) -> @matcher.Match? {
  let mut pos = self.pos
  while pos < buf.len {
    if self.has_exceeded_match_limit() {
      return None
    }
    match
      self.matcher.find_candidate_line(
        buf.arr,
        buf.off + pos,
        buf.off + buf.len,
      ) {
      None => return None
      Some(Confirmed(i)) => {
        let line = locate(buf.arr, buf.off, buf.len, self.lineterm(), {
          start: i + pos,
          end: i + pos,
        })
        if line.start == buf.len {
          pos = buf.len
          continue
        }
        return Some(line)
      }
      Some(Candidate(i)) => {
        let line = locate(buf.arr, buf.off, buf.len, self.lineterm(), {
          start: i + pos,
          end: i + pos,
        })
        if self.is_match(buf, line) {
          return Some(line)
        }
        pos = line.end
      }
    }
  }
  None
}

///|
async fn Core::sink_matched(
  self : Core,
  buf : Win,
  start : Int32,
  end : Int32,
) -> Bool {
  if self.binary && self.detect_binary(buf, start, end) {
    return false
  }
  if !self.sink_break_context(start) {
    return false
  }
  self.count_lines(buf, start)
  let offset = self.absolute_byte_offset + start.to_int64()
  let mat = self.sink_match
  mat.buf = buf.arr
  mat.buf_start = buf.off
  mat.buf_len = buf.len
  mat.start = start
  mat.end = end
  mat.absolute_byte_offset = offset
  mat.line_number = self.line_number
  let keepgoing = self.sink.matched(self.searcher, mat)
  if !keepgoing {
    return false
  }
  self.last_line_visited = end
  self.after_context_left = self.config.after_context
  self.has_sunk = true
  true
}

///|
async fn Core::sink_context(
  self : Core,
  buf : Win,
  start : Int32,
  end : Int32,
  kind : SinkContextKind,
) -> Bool {
  self.count_lines(buf, start)
  let offset = self.absolute_byte_offset + start.to_int64()
  let ctx = self.sink_ctx
  ctx.buf = buf.arr
  ctx.start = buf.off + start
  ctx.end = buf.off + end
  ctx.kind = kind
  ctx.absolute_byte_offset = offset
  ctx.line_number = self.line_number
  self.sink.context(self.searcher, ctx)
}

///|
async fn Core::sink_before_context(
  self : Core,
  buf : Win,
  start : Int32,
  end : Int32,
) -> Bool {
  if self.binary && self.detect_binary(buf, start, end) {
    return false
  }
  if !self.sink_context(buf, start, end, Before) {
    return false
  }
  self.last_line_visited = end
  self.has_sunk = true
  true
}

///|
async fn Core::sink_after_context(
  self : Core,
  buf : Win,
  start : Int32,
  end : Int32,
) -> Bool {
  guard self.after_context_left >= 1 else { abort("no after context left") }
  if self.binary && self.detect_binary(buf, start, end) {
    return false
  }
  if !self.sink_context(buf, start, end, After) {
    return false
  }
  self.last_line_visited = end
  self.after_context_left -= 1
  self.has_sunk = true
  true
}

///|
async fn Core::sink_other_context(
  self : Core,
  buf : Win,
  start : Int32,
  end : Int32,
) -> Bool {
  if self.binary && self.detect_binary(buf, start, end) {
    return false
  }
  if !self.sink_context(buf, start, end, Other) {
    return false
  }
  self.last_line_visited = end
  self.has_sunk = true
  true
}

///|
async fn Core::sink_break_context(self : Core, start_of_line : Int32) -> Bool {
  let is_gap = self.last_line_visited < start_of_line
  let any_context = self.config.before_context > 0 ||
    self.config.after_context > 0
  if !any_context || !self.has_sunk || !is_gap {
    true
  } else {
    self.sink.context_break(self.searcher)
  }
}

///|
fn Core::count_lines(self : Core, buf : Win, upto : Int32) -> Unit {
  if self.line_number is Some(n) {
    if self.last_line_counted >= upto {
      return
    }
    let count = count_lines(
      buf.arr,
      buf.off + self.last_line_counted,
      buf.off + upto,
      self.lineterm(),
    )
    self.line_number = Some(n + count)
    self.last_line_counted = upto
  }
}

///|
fn Core::is_line_by_line_fast(self : Core) -> Bool {
  if self.config.passthru {
    return false
  }
  if self.config.stop_on_nonmatch && self.has_matched {
    return false
  }
  if self.matcher.line_terminator() is Some(lt) {
    if lt.as_byte() == b'\x00' {
      return false
    }
    if lt == self.config.line_term {
      return true
    }
  }
  if self.matcher.non_matching_bytes() is Some(nm) &&
    nm.contains(self.lineterm()) {
    return true
  }
  false
}

///|
fn Core::has_exceeded_match_limit(self : Core) -> Bool {
  match self.config.max_matches {
    Some(limit) => self.count >= limit
    None => false
  }
}
