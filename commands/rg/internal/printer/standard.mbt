///|
/// The configuration for the standard printer.
priv struct StandardConfig {
  coalesce_matches : Bool
  colors : ColorSpecs
  hyperlink : HyperlinkConfig
  stats : Bool
  heading : Bool
  path : Bool
  only_matching : Bool
  per_match : Bool
  per_match_one_line : Bool
  replacement : Bytes?
  max_columns : Int64?
  max_columns_preview : Bool
  column : Bool
  byte_offset : Bool
  trim_ascii : Bool
  separator_search : Bytes?
  separator_context : Bytes?
  separator_field_match : Bytes
  separator_field_context : Bytes
  separator_path : Byte?
  path_terminator : Byte?
  clock : () -> Int64
}

///|
/// The default clock used for timing statistics: it always returns `0`.
/// Callers that collect timings provide a monotonic clock to the constructor.
fn zero_clock() -> Int64 {
  0
}

///|
/// The standard printer, which implements grep-like formatting, including
/// color support.
pub struct Standard {
  priv config : StandardConfig
  priv wtr : CounterWriter
  priv matches : Array[@matcher.Match]
}

///|
/// Return a standard printer with a default configuration that writes
/// matches to the given byte sink, dropping all color information.
pub fn Standard::new_no_color(wtr : &@termcolor.Write) -> Standard {
  Standard::new(@termcolor.NoColor::new(wtr))
}

///|
/// Return an implementation of `Sink` for the standard printer.
pub fn Standard::sink(
  self : Standard,
  matcher : &@matcher.Matcher,
) -> StandardSink {
  let interpolator = Interpolator::new(self.config.hyperlink)
  let stats = if self.config.stats { Some(Stats::new()) } else { None }
  let needs_match_granularity = self.needs_match_granularity()
  {
    matcher,
    standard: self,
    replacer: Replacer::new(),
    interpolator,
    path: None,
    start_time: (self.config.clock)(),
    match_count: 0,
    binary_byte_offset: None,
    stats,
    needs_match_granularity,
    cache: None,
  }
}

///|
/// Return an implementation of `Sink` associated with a file path.
///
/// When the printer is associated with a path, then it may, depending on
/// its configuration, print the path along with the matches found.
pub fn Standard::sink_with_path(
  self : Standard,
  matcher : &@matcher.Matcher,
  path : String,
) -> StandardSink {
  if !self.config.path {
    return self.sink(matcher)
  }
  let interpolator = Interpolator::new(self.config.hyperlink)
  let stats = if self.config.stats { Some(Stats::new()) } else { None }
  let ppath = PrinterPath::new(path).with_separator(self.config.separator_path)
  let needs_match_granularity = self.needs_match_granularity()
  {
    matcher,
    standard: self,
    replacer: Replacer::new(),
    interpolator,
    path: Some(ppath),
    start_time: (self.config.clock)(),
    match_count: 0,
    binary_byte_offset: None,
    stats,
    needs_match_granularity,
    cache: None,
  }
}

///|
/// Returns true if and only if the configuration of the printer requires
/// us to find each individual match in the lines reported by the searcher.
fn Standard::needs_match_granularity(self : Standard) -> Bool {
  let supports_color = self.wtr.supports_color()
  let match_colored = !self.config.colors.matched().is_none()
  // Coloring requires identifying each individual match.
  (supports_color && match_colored) ||
  // The column feature requires finding the position of the first match.
  self.config.column ||
  // Requires finding each match for performing replacement.
  self.config.replacement is Some(_) ||
  // Emitting a line for each match requires finding each match.
  self.config.per_match ||
  // Emitting only the match requires finding each match.
  self.config.only_matching ||
  // Computing certain statistics requires finding each match.
  self.config.stats
}

///|
/// Return the underlying writer.
pub fn Standard::get_mut(self : Standard) -> &@termcolor.WriteColor {
  self.wtr.get_mut()
}

///|
/// An implementation of `Sink` associated with a matcher and an optional
/// file path for the standard printer.
pub struct StandardSink {
  priv matcher : &@matcher.Matcher
  priv standard : Standard
  priv replacer : Replacer
  priv interpolator : Interpolator
  priv path : PrinterPath?
  priv mut start_time : Int64
  priv mut match_count : Int64
  priv mut binary_byte_offset : Int64?
  priv stats : Stats?
  priv needs_match_granularity : Bool
  /// The implementation object, reused for every line printed.
  priv mut cache : StandardImpl?
}

///|
/// Returns true if and only if this printer received a match in the
/// previous search.
pub fn StandardSink::has_match(self : StandardSink) -> Bool {
  self.match_count > 0
}

///|
/// If binary data was found in the previous search, this returns the
/// offset at which the binary data was first detected.
pub fn StandardSink::binary_byte_offset(self : StandardSink) -> Int64? {
  self.binary_byte_offset
}

///|
/// Return a reference to the stats produced by the printer for all
/// searches executed on this sink. Only available if `stats` was enabled.
pub fn StandardSink::stats(self : StandardSink) -> Stats? {
  self.stats
}

///|
/// Execute the matcher over `hay[hs:he]` and record the match locations if
/// the current configuration demands match granularity.
fn StandardSink::record_matches(
  self : StandardSink,
  searcher : @searcher.Searcher,
  hay : FixedArray[Byte],
  hs : Int32,
  he : Int32,
  range_start : Int32,
  range_end : Int32,
) -> Unit {
  let matches = self.standard.matches
  matches.clear()
  if !self.needs_match_granularity {
    return
  }
  // If printing requires knowing the location of each individual match,
  // then compute and stored those right now for use later.
  find_iter_at_in_context(
    searcher,
    self.matcher,
    hay,
    hs,
    he,
    range_start,
    range_end,
    m => {
      matches.push(
        @matcher.Match::new(m.start - range_start, m.end - range_start),
      )
      true
    },
  )
  // Don't report empty matches appearing at the end of the bytes.
  if matches.last() is Some(last) && last.is_empty() && last.start >= range_end {
    matches.pop() |> ignore
  }
}

///|
/// If the configuration specifies a replacement, then this executes the
/// replacement, lazily allocating memory if necessary.
fn StandardSink::replace(
  self : StandardSink,
  searcher : @searcher.Searcher,
  hay : FixedArray[Byte],
  hs : Int32,
  he : Int32,
  range_start : Int32,
  range_end : Int32,
) -> Unit {
  self.replacer.clear()
  if self.standard.config.replacement is Some(replacement) {
    self.replacer.replace_all(
      searcher,
      self.matcher,
      hay,
      hs,
      he,
      range_start,
      range_end,
      replacement,
    )
  }
}

///|
pub impl @searcher.Sink for StandardSink with fn matched(self, searcher, mat) {
  self.match_count += 1
  let hs = mat.buf_start
  let he = mat.buf_start + mat.buf_len
  self.record_matches(searcher, mat.buf, hs, he, mat.start, mat.end)
  self.replace(searcher, mat.buf, hs, he, mat.start, mat.end)
  if self.stats is Some(stats) {
    stats.add_matches(self.standard.matches.length().to_int64())
    stats.add_matched_lines(
      count_lines_in(
        mat.buf,
        hs + mat.start,
        hs + mat.end,
        searcher.line_terminator().as_byte(),
      ),
    )
  }
  if searcher.binary_detection().convert_byte() is Some(_) {
    if self.binary_byte_offset is Some(_) {
      return false
    }
  }
  StandardImpl::from_match(searcher, self, mat).sink()
  true
}

///|
pub impl @searcher.Sink for StandardSink with fn coalesce_matches(self) {
  let config = self.standard.config
  config.coalesce_matches &&
  !self.needs_match_granularity &&
  self.path is None &&
  !config.heading &&
  !config.byte_offset &&
  !config.trim_ascii &&
  config.max_columns is None &&
  config.separator_search is None
}

///|
pub impl @searcher.Sink for StandardSink with fn context(self, searcher, ctx) {
  self.standard.matches.clear()
  self.replacer.clear()
  if searcher.invert_match() {
    let len = ctx.end - ctx.start
    self.record_matches(searcher, ctx.buf, ctx.start, ctx.end, 0, len)
    self.replace(searcher, ctx.buf, ctx.start, ctx.end, 0, len)
  }
  if searcher.binary_detection().convert_byte() is Some(_) {
    if self.binary_byte_offset is Some(_) {
      return false
    }
  }
  StandardImpl::from_context(searcher, self, ctx).sink()
  true
}

///|
pub impl @searcher.Sink for StandardSink with fn context_break(self, searcher) {
  StandardImpl::new(searcher, self).write_context_separator()
  true
}

///|
pub impl @searcher.Sink for StandardSink with fn binary_data(
  self,
  _searcher,
  binary_byte_offset,
) {
  self.binary_byte_offset = Some(binary_byte_offset)
  true
}

///|
pub impl @searcher.Sink for StandardSink with fn begin(self, _searcher) {
  self.standard.wtr.reset_count()
  self.start_time = (self.standard.config.clock)()
  self.match_count = 0
  self.binary_byte_offset = None
  true
}

///|
pub impl @searcher.Sink for StandardSink with fn finish(self, searcher, finish) {
  if self.binary_byte_offset is Some(offset) {
    StandardImpl::new(searcher, self).write_binary_message(offset)
  }
  if self.stats is Some(stats) {
    stats.add_elapsed((self.standard.config.clock)() - self.start_time)
    stats.add_searches(1)
    if self.match_count > 0 {
      stats.add_searches_with_match(1)
    }
    stats.add_bytes_searched(finish.byte_count)
    stats.add_bytes_printed(self.standard.wtr.count())
  }
}

///|
/// The actual implementation of the standard printer. This couples
/// together the searcher, the sink implementation and information about
/// the match.
priv struct StandardImpl {
  mut searcher : @searcher.Searcher
  sink : StandardSink
  sunk : Sunk
  /// Set to true if and only if we are writing a match with color.
  mut in_color_match : Bool
  /// The prelude writer, reused for every line.
  mut prelude : PreludeWriter?
}

///|
/// Returns the sink's (reused) implementation object, reset for a new line
/// with an empty `Sunk`.
fn StandardImpl::new(
  searcher : @searcher.Searcher,
  sink : StandardSink,
) -> StandardImpl {
  let imp = StandardImpl::reuse(searcher, sink)
  imp.sunk.set_empty()
  imp
}

///|
/// Returns the sink's (reused) implementation object for a new line,
/// leaving its `Sunk` for the caller to set.
fn StandardImpl::reuse(
  searcher : @searcher.Searcher,
  sink : StandardSink,
) -> StandardImpl {
  match sink.cache {
    Some(imp) => {
      imp.searcher = searcher
      imp.in_color_match = false
      imp
    }
    None => {
      let imp = {
        searcher,
        sink,
        sunk: Sunk::empty(),
        in_color_match: false,
        prelude: None,
      }
      sink.cache = Some(imp)
      imp
    }
  }
}

///|
fn StandardImpl::from_match(
  searcher : @searcher.Searcher,
  sink : StandardSink,
  mat : @searcher.SinkMatch,
) -> StandardImpl {
  let imp = StandardImpl::reuse(searcher, sink)
  imp.sunk.set_match(mat, sink.standard.matches, sink.replacer.replacement())
  imp
}

///|
fn StandardImpl::from_context(
  searcher : @searcher.Searcher,
  sink : StandardSink,
  ctx : @searcher.SinkContext,
) -> StandardImpl {
  let imp = StandardImpl::reuse(searcher, sink)
  imp.sunk.set_context(ctx, sink.standard.matches, sink.replacer.replacement())
  imp
}

///|
async fn StandardImpl::sink(self : StandardImpl) -> Unit {
  if self.wtr().count() == 0 {
    self.write_search_prelude()
  }
  if self.sunk.matches.is_empty() {
    if self.multi_line() && !self.is_context() {
      self.sink_fast_multi_line()
    } else {
      self.sink_fast()
    }
  } else if self.multi_line() && !self.is_context() {
    self.sink_slow_multi_line()
  } else {
    self.sink_slow()
  }
}

///|
/// Print matches (limited to one line) quickly by avoiding the detection
/// of each individual match in the lines reported in the given
/// `SinkMatch`.
async fn StandardImpl::sink_fast(self : StandardImpl) -> Unit {
  self.write_prelude(
    self.sunk.absolute_byte_offset,
    self.sunk.line_number,
    None,
  )
  self.write_line(self.sunk.buf, self.sunk.start, self.sunk.end)
}

///|
/// Print matches (possibly spanning more than one line) quickly by avoiding
/// the detection of each individual match in the lines reported.
async fn StandardImpl::sink_fast_multi_line(self : StandardImpl) -> Unit {
  let line_term = self.searcher.line_terminator().as_byte()
  let mut absolute_byte_offset = self.sunk.absolute_byte_offset
  let stepper = @searcher.LineStep::new(line_term, 0, self.sunk.len())
  let mut i = 0L
  while stepper.next(self.sunk.buf, self.sunk.start) is Some(line) {
    self.write_prelude(
      absolute_byte_offset,
      self.sunk.line_number.map(n => n + i),
      None,
    )
    absolute_byte_offset += (line.end - line.start).to_int64()
    self.write_line(
      self.sunk.buf,
      self.sunk.start + line.start,
      self.sunk.start + line.end,
    )
    i += 1
  }
}

///|
/// Print a matching line where the configuration of the printer requires
/// finding each individual match (e.g., for coloring).
async fn StandardImpl::sink_slow(self : StandardImpl) -> Unit {
  let buf = self.sunk.buf
  let base = self.sunk.start
  if self.config().only_matching {
    for m in self.sunk.matches {
      self.write_prelude(
        self.sunk.absolute_byte_offset + m.start.to_int64(),
        self.sunk.line_number,
        Some(m.start.to_int64() + 1),
      )
      self.write_colored_line(
        [@matcher.Match::new(0, m.end - m.start)],
        buf,
        base + m.start,
        base + m.end,
      )
    }
  } else if self.config().per_match {
    for m in self.sunk.matches {
      self.write_prelude(
        self.sunk.absolute_byte_offset + m.start.to_int64(),
        self.sunk.line_number,
        Some(m.start.to_int64() + 1),
      )
      self.write_colored_line([m], buf, base, self.sunk.end)
    }
  } else {
    self.write_prelude(
      self.sunk.absolute_byte_offset,
      self.sunk.line_number,
      Some(self.sunk.matches[0].start.to_int64() + 1),
    )
    self.write_colored_line(self.sunk.matches, buf, base, self.sunk.end)
  }
}

///|
async fn StandardImpl::sink_slow_multi_line(self : StandardImpl) -> Unit {
  if self.config().only_matching {
    return self.sink_slow_multi_line_only_matching()
  } else if self.config().per_match {
    return self.sink_slow_multi_per_match()
  }
  let line_term = self.searcher.line_terminator().as_byte()
  let buf = self.sunk.buf
  let base = self.sunk.start
  let matches = self.sunk.matches
  let midx = Ref(0)
  let mut count = 0L
  let stepper = @searcher.LineStep::new(line_term, 0, self.sunk.len())
  while stepper.next(buf, base) is Some(line) {
    self.write_prelude(
      self.sunk.absolute_byte_offset + line.start.to_int64(),
      self.sunk.line_number.map(n => n + count),
      Some(matches[0].start.to_int64() + 1),
    )
    count += 1
    let line = self.trim_ascii_prefix(buf, base, line)
    if self.exceeds_max_columns(line.end - line.start) {
      self.write_exceeded_line(buf, base, line, matches, midx)
    } else {
      self.write_colored_matches(buf, base, line, matches, midx)
      self.write_line_term()
    }
  }
}

///|
async fn StandardImpl::sink_slow_multi_line_only_matching(
  self : StandardImpl,
) -> Unit {
  let line_term = self.searcher.line_terminator().as_byte()
  let spec = self.config().colors.matched()
  let buf = self.sunk.buf
  let base = self.sunk.start
  let matches = self.sunk.matches
  let midx = Ref(0)
  let mut count = 0L
  let stepper = @searcher.LineStep::new(line_term, 0, self.sunk.len())
  while stepper.next(buf, base) is Some(line) {
    let mut line = self.trim_line_terminator(buf, base, line)
    line = self.trim_ascii_prefix(buf, base, line)
    while !line.is_empty() {
      if matches[midx.val].end <= line.start {
        if midx.val + 1 < matches.length() {
          midx.val += 1
          continue
        } else {
          break
        }
      }
      let m = matches[midx.val]
      if line.start < m.start {
        let upto = imin(line.end, m.start)
        line = line.with_start(upto)
      } else {
        let upto = imin(line.end, m.end)
        self.write_prelude(
          self.sunk.absolute_byte_offset + m.start.to_int64(),
          self.sunk.line_number.map(n => n + count),
          Some(m.start.to_int64() + 1),
        )
        let this_line = line.with_end(upto)
        line = line.with_start(upto)
        if self.exceeds_max_columns(this_line.end - this_line.start) {
          self.write_exceeded_line(buf, base, this_line, matches, midx)
        } else {
          self.write_spec(
            spec,
            buf,
            base + this_line.start,
            base + this_line.end,
          )
          self.write_line_term()
        }
      }
    }
    count += 1
  }
}

///|
async fn StandardImpl::sink_slow_multi_per_match(self : StandardImpl) -> Unit {
  let line_term = self.searcher.line_terminator().as_byte()
  let spec = self.config().colors.matched()
  let buf = self.sunk.buf
  let base = self.sunk.start
  for m in self.sunk.matches {
    let mut count = 0L
    let stepper = @searcher.LineStep::new(line_term, 0, self.sunk.len())
    while stepper.next(buf, base) is Some(line) {
      if line.start >= m.end {
        break
      } else if line.end <= m.start {
        count += 1
        continue
      }
      let col = if m.start > line.start { m.start - line.start } else { 0 }
      self.write_prelude(
        self.sunk.absolute_byte_offset + line.start.to_int64(),
        self.sunk.line_number.map(n => n + count),
        Some(col.to_int64() + 1),
      )
      count += 1
      let mut line = self.trim_line_terminator(buf, base, line)
      line = self.trim_ascii_prefix(buf, base, line)
      if self.exceeds_max_columns(line.end - line.start) {
        self.write_exceeded_line(buf, base, line, [m], Ref(0))
        continue
      }
      while !line.is_empty() {
        if m.end <= line.start {
          self.write(buf, base + line.start, base + line.end)
          line = line.with_start(line.end)
        } else if line.start < m.start {
          let upto = imin(line.end, m.start)
          self.write(buf, base + line.start, base + upto)
          line = line.with_start(upto)
        } else {
          let upto = imin(line.end, m.end)
          self.write_spec(spec, buf, base + line.start, base + upto)
          line = line.with_start(upto)
        }
      }
      self.write_line_term()
      // It turns out that vimgrep really only wants one line per match,
      // even when a match spans multiple lines. So when that option is
      // enabled, we just quit after printing the first line.
      if self.config().per_match_one_line {
        break
      }
    }
  }
}

///|
/// Write the beginning part of a matching line. This (may) include things
/// like the file path, line number among others, depending on the
/// configuration and the parameters given.
async fn StandardImpl::write_prelude(
  self : StandardImpl,
  absolute_byte_offset : Int64,
  line_number : Int64?,
  column : Int64?,
) -> Unit {
  if self.path() is None &&
    line_number is None &&
    (!self.config().column || column is None) &&
    !self.config().byte_offset {
    return
  }
  let prelude = PreludeWriter::new(self)
  prelude.start(line_number, column)
  prelude.write_path()
  prelude.write_line_number(line_number)
  prelude.write_column_number(column)
  prelude.write_byte_offset(absolute_byte_offset)
  prelude.end()
}

///|
/// Write the given line (`buf[start:end]`).
async fn StandardImpl::write_line(
  self : StandardImpl,
  buf : FixedArray[Byte],
  start : Int32,
  end : Int32,
) -> Unit {
  let mut start = start
  if self.config().trim_ascii {
    let lineterm = self.searcher.line_terminator()
    let range = trim_ascii_prefix(
      lineterm,
      buf,
      start,
      @matcher.Match::new(0, end - start),
    )
    start = start + range.start
  }
  if self.exceeds_max_columns(end - start) {
    let range = @matcher.Match::new(0, end - start)
    self.write_exceeded_line(buf, start, range, self.sunk.matches, Ref(0))
  } else {
    self.write(buf, start, end)
    if !self.has_line_terminator(buf, start, end) {
      self.write_line_term()
    }
  }
}

///|
async fn StandardImpl::write_colored_line(
  self : StandardImpl,
  matches : Array[@matcher.Match],
  buf : FixedArray[Byte],
  start : Int32,
  end : Int32,
) -> Unit {
  // If we know we aren't going to emit color, then we can go faster.
  let spec = self.config().colors.matched()
  if !self.wtr().supports_color() || spec.is_none() {
    return self.write_line(buf, start, end)
  }
  let line = self.trim_ascii_prefix(
    buf,
    start,
    @matcher.Match::new(0, end - start),
  )
  if self.exceeds_max_columns(end - start) {
    self.write_exceeded_line(buf, start, line, matches, Ref(0))
  } else {
    self.write_colored_matches(buf, start, line, matches, Ref(0))
    self.write_line_term()
  }
}

///|
/// Write the `line` portion of `buf[base:]` with appropriate coloring for
/// each `match`, starting with `match_index`.
///
/// This accounts for trimming any whitespace prefixes and will *never*
/// print a line terminator. If a match exceeds the range specified by
/// `line`, then only the part of the match within `line` (if any) is
/// printed.
async fn StandardImpl::write_colored_matches(
  self : StandardImpl,
  buf : FixedArray[Byte],
  base : Int32,
  line : @matcher.Match,
  matches : Array[@matcher.Match],
  match_index : Ref[Int32],
) -> Unit {
  let mut line = self.trim_line_terminator(buf, base, line)
  if matches.is_empty() {
    self.write(buf, base + line.start, base + line.end)
    return
  }
  self.start_line_highlight()
  while !line.is_empty() {
    if matches[match_index.val].end <= line.start {
      if match_index.val + 1 < matches.length() {
        match_index.val += 1
        continue
      } else {
        self.end_color_match()
        self.write(buf, base + line.start, base + line.end)
        break
      }
    }
    let m = matches[match_index.val]
    if line.start < m.start {
      let upto = imin(line.end, m.start)
      self.end_color_match()
      self.write(buf, base + line.start, base + upto)
      line = line.with_start(upto)
    } else {
      let upto = imin(line.end, m.end)
      self.start_color_match()
      self.write(buf, base + line.start, base + upto)
      line = line.with_start(upto)
    }
  }
  self.end_color_match()
  self.end_line_highlight()
}

///|
async fn StandardImpl::write_exceeded_line(
  self : StandardImpl,
  buf : FixedArray[Byte],
  base : Int32,
  line : @matcher.Match,
  matches : Array[@matcher.Match],
  match_index : Ref[Int32],
) -> Unit {
  if self.config().max_columns_preview {
    let original = line
    let limit = match self.config().max_columns {
      Some(n) => n
      None => 0L
    }
    let end = grapheme_end_after(buf, base + line.start, base + line.end, limit) +
      line.start
    let line = line.with_end(end)
    self.write_colored_matches(buf, base, line, matches, match_index)
    if matches.is_empty() {
      self.write_str(" [... omitted end of long line]")
    } else {
      let remaining = matches
        .iter()
        .filter(m => m.start >= line.end && m.start < original.end)
        .count()
      let tense = if remaining == 1 { "match" } else { "matches" }
      self.write_str(" [... \{remaining} more \{tense}]")
    }
    self.write_line_term()
    return
  }
  if self.sunk.original_matches.is_empty() {
    if self.is_context() {
      self.write_str("[Omitted long context line]")
    } else {
      self.write_str("[Omitted long matching line]")
    }
  } else if self.config().only_matching {
    if self.is_context() {
      self.write_str("[Omitted long context line]")
    } else {
      self.write_str("[Omitted long matching line]")
    }
  } else {
    self.write_str(
      "[Omitted long line with \{self.sunk.original_matches.length()} matches]",
    )
  }
  self.write_line_term()
}

///|
/// If this printer has a file path associated with it, then this will
/// write that path to the underlying writer followed by a line terminator.
/// (If a path terminator is set, then that is used instead of the line
/// terminator.)
async fn StandardImpl::write_path_line(self : StandardImpl) -> Unit {
  if self.path() is Some(path) {
    self.write_path_hyperlink(path)
    if self.config().path_terminator is Some(term) {
      self.write_bytes([term])
    } else {
      self.write_line_term()
    }
  }
}

///|
async fn StandardImpl::write_search_prelude(self : StandardImpl) -> Unit {
  let this_search_written = self.wtr().count() > 0
  if this_search_written {
    return
  }
  if self.config().separator_search is Some(sep) {
    let ever_written = self.wtr().total_count() > 0
    if ever_written {
      self.write_bytes(sep)
      self.write_line_term()
    }
  }
  if self.config().heading {
    self.write_path_line()
  }
}

///|
async fn StandardImpl::write_binary_message(
  self : StandardImpl,
  offset : Int64,
) -> Unit {
  if !self.sink.has_match() {
    return
  }
  let bin = self.searcher.binary_detection()
  if bin.quit_byte() is Some(byte) {
    if self.path() is Some(path) {
      self.write_path_hyperlink(path)
      self.write_str(": ")
    }
    let remainder = "WARNING: stopped searching binary file after match (found \{debug_byte(byte)} byte around offset \{offset})\n"
    self.write_str(remainder)
  } else if bin.convert_byte() is Some(byte) {
    if self.path() is Some(path) {
      self.write_path_hyperlink(path)
      self.write_str(": ")
    }
    let remainder = "binary file matches (found \{debug_byte(byte)} byte around offset \{offset})\n"
    self.write_str(remainder)
  }
}

///|
async fn StandardImpl::write_context_separator(self : StandardImpl) -> Unit {
  if self.config().separator_context is Some(sep) {
    self.write_bytes(sep)
    self.write_line_term()
  }
}

///|
async fn StandardImpl::write_line_term(self : StandardImpl) -> Unit {
  self.write_bytes(self.searcher.line_terminator().as_bytes())
}

///|
async fn StandardImpl::write_spec(
  self : StandardImpl,
  spec : @termcolor.ColorSpec,
  buf : FixedArray[Byte],
  start : Int32,
  end : Int32,
) -> Unit {
  let wtr = self.wtr()
  wtr.set_color(spec)
  wtr.write_slice(buf, start, end)
  wtr.reset()
}

///|
/// Writes `n` in decimal with the given color.
async fn StandardImpl::write_spec_decimal(
  self : StandardImpl,
  spec : @termcolor.ColorSpec,
  n : Int64,
) -> Unit {
  let start = format_decimal(n)
  self.write_spec(spec, decimal_scratch, start, decimal_scratch.length())
}

///|
async fn StandardImpl::write_path(
  self : StandardImpl,
  path : PrinterPath,
) -> Unit {
  let wtr = self.wtr()
  wtr.set_color(self.config().colors.path())
  wtr.write_bytes(path.bytes)
  wtr.reset()
}

///|
async fn StandardImpl::write_path_hyperlink(
  self : StandardImpl,
  path : PrinterPath,
) -> Unit {
  let status = self.start_hyperlink(path, None, None)
  self.write_path(path)
  self.end_hyperlink(status)
}

///|
/// Starts a hyperlink span when applicable.
async fn StandardImpl::start_hyperlink(
  self : StandardImpl,
  path : PrinterPath,
  line_number : Int64?,
  column : Int64?,
) -> Bool {
  // Without a hyperlink format nothing is written (`Interpolator::begin`
  // would return false), so skip computing the hyperlink path and values.
  if self.config().hyperlink.format.is_empty() {
    return false
  }
  guard path.as_hyperlink(self.config().hyperlink.env) is Some(hyperpath) else {
    return false
  }
  let values = { path: hyperpath, line: line_number, column, }
  self.sink.interpolator.begin(values, self.wtr())
}

///|
async fn StandardImpl::end_hyperlink(
  self : StandardImpl,
  status : Bool,
) -> Unit {
  self.sink.interpolator.finish(status, self.wtr())
}

///|
async fn StandardImpl::start_color_match(self : StandardImpl) -> Unit {
  if self.in_color_match {
    return
  }
  self.wtr().set_color(self.config().colors.matched())
  self.in_color_match = true
}

///|
async fn StandardImpl::end_color_match(self : StandardImpl) -> Unit {
  if !self.in_color_match {
    return
  }
  if self.highlight_on() {
    self.wtr().set_color(self.config().colors.highlight())
  } else {
    self.wtr().reset()
  }
  self.in_color_match = false
}

///|
fn StandardImpl::highlight_on(self : StandardImpl) -> Bool {
  !self.config().colors.highlight().is_none() && !self.is_context()
}

///|
async fn StandardImpl::start_line_highlight(self : StandardImpl) -> Unit {
  if self.highlight_on() {
    self.wtr().set_color(self.config().colors.highlight())
  }
}

///|
async fn StandardImpl::end_line_highlight(self : StandardImpl) -> Unit {
  if self.highlight_on() {
    self.wtr().reset()
  }
}

///|
async fn StandardImpl::write(
  self : StandardImpl,
  buf : FixedArray[Byte],
  start : Int32,
  end : Int32,
) -> Unit {
  self.wtr().write_slice(buf, start, end)
}

///|
async fn StandardImpl::write_bytes(self : StandardImpl, bytes : Bytes) -> Unit {
  self.wtr().write_bytes(bytes)
}

///|
async fn StandardImpl::write_str(self : StandardImpl, s : String) -> Unit {
  self.wtr().write_bytes(utf8_bytes(s))
}

///|
fn StandardImpl::trim_line_terminator(
  self : StandardImpl,
  buf : FixedArray[Byte],
  base : Int32,
  line : @matcher.Match,
) -> @matcher.Match {
  let (m, _, _) = trim_line_terminator(self.searcher, buf, base, line)
  m
}

///|
fn StandardImpl::has_line_terminator(
  self : StandardImpl,
  buf : FixedArray[Byte],
  start : Int32,
  end : Int32,
) -> Bool {
  self.searcher.line_terminator().is_suffix(buf, start, end)
}

///|
fn StandardImpl::is_context(self : StandardImpl) -> Bool {
  self.sunk.context_kind is Some(_)
}

///|
fn StandardImpl::config(self : StandardImpl) -> StandardConfig {
  self.sink.standard.config
}

///|
fn StandardImpl::wtr(self : StandardImpl) -> CounterWriter {
  self.sink.standard.wtr
}

///|
fn StandardImpl::path(self : StandardImpl) -> PrinterPath? {
  self.sink.path
}

///|
fn StandardImpl::separator_field(self : StandardImpl) -> Bytes {
  if self.is_context() {
    self.config().separator_field_context
  } else {
    self.config().separator_field_match
  }
}

///|
fn StandardImpl::exceeds_max_columns(self : StandardImpl, len : Int32) -> Bool {
  match self.config().max_columns {
    Some(m) => len.to_int64() > m
    None => false
  }
}

///|
fn StandardImpl::multi_line(self : StandardImpl) -> Bool {
  self.searcher.multi_line_with_matcher(self.sink.matcher)
}

///|
fn StandardImpl::trim_ascii_prefix(
  self : StandardImpl,
  buf : FixedArray[Byte],
  base : Int32,
  range : @matcher.Match,
) -> @matcher.Match {
  if !self.config().trim_ascii {
    return range
  }
  let lineterm = self.searcher.line_terminator()
  trim_ascii_prefix(lineterm, buf, base, range)
}

///|
priv enum PreludeSeparator {
  NoSeparator
  FieldSeparator
  PathTerminator
}

///|
/// A writer for the prelude (the beginning part of a matching line).
priv struct PreludeWriter {
  std : StandardImpl
  mut next_separator : PreludeSeparator
  mut field_separator : Bytes
  mut interp_status : Bool
}

///|
/// Returns the (reused) prelude writer of `std`, reset for a new line.
fn PreludeWriter::new(std : StandardImpl) -> PreludeWriter {
  match std.prelude {
    Some(p) => {
      p.next_separator = NoSeparator
      p.field_separator = std.separator_field()
      p.interp_status = false
      p
    }
    None => {
      let p = {
        std,
        next_separator: NoSeparator,
        field_separator: std.separator_field(),
        interp_status: false,
      }
      std.prelude = Some(p)
      p
    }
  }
}

///|
/// Starts the prelude with a hyperlink when applicable.
async fn PreludeWriter::start(
  self : PreludeWriter,
  line_number : Int64?,
  column : Int64?,
) -> Unit {
  guard self.std.path() is Some(path) else { return }
  if self.config().hyperlink.format.is_empty() {
    return
  }
  if self.config().hyperlink.format.is_line_dependent() ||
    !self.config().heading {
    self.interp_status = self.std.start_hyperlink(path, line_number, column)
  }
}

///|
/// Ends the prelude and writes the remaining output.
async fn PreludeWriter::end(self : PreludeWriter) -> Unit {
  let status = self.interp_status
  self.interp_status = false
  self.std.end_hyperlink(status)
  self.write_separator()
}

///|
async fn PreludeWriter::write_path(self : PreludeWriter) -> Unit {
  // The prelude doesn't handle headings, only what comes before a match on
  // the same line.
  if self.config().heading {
    return
  }
  guard self.std.path() is Some(path) else { return }
  self.write_separator()
  self.std.write_path(path)
  self.next_separator = if self.config().path_terminator is Some(_) {
    PathTerminator
  } else {
    FieldSeparator
  }
}

///|
async fn PreludeWriter::write_line_number(
  self : PreludeWriter,
  line : Int64?,
) -> Unit {
  guard line is Some(line_number) else { return }
  self.write_separator()
  self.std.write_spec_decimal(self.config().colors.line(), line_number)
  self.next_separator = FieldSeparator
}

///|
async fn PreludeWriter::write_column_number(
  self : PreludeWriter,
  column : Int64?,
) -> Unit {
  if !self.config().column {
    return
  }
  guard column is Some(column_number) else { return }
  self.write_separator()
  self.std.write_spec_decimal(self.config().colors.column(), column_number)
  self.next_separator = FieldSeparator
}

///|
async fn PreludeWriter::write_byte_offset(
  self : PreludeWriter,
  offset : Int64,
) -> Unit {
  if !self.config().byte_offset {
    return
  }
  self.write_separator()
  self.std.write_spec_decimal(self.config().colors.column(), offset)
  self.next_separator = FieldSeparator
}

///|
async fn PreludeWriter::write_separator(self : PreludeWriter) -> Unit {
  match self.next_separator {
    NoSeparator => ()
    FieldSeparator => self.std.write_bytes(self.field_separator)
    PathTerminator =>
      if self.config().path_terminator is Some(term) {
        self.std.write_bytes([term])
      }
  }
  self.next_separator = NoSeparator
}

///|
fn PreludeWriter::config(self : PreludeWriter) -> StandardConfig {
  self.std.config()
}

///|
/// Construct an immutable output configuration once, before processing input.
pub fn Standard::new(
  wtr : &@termcolor.WriteColor,
  coalesce_matches~ : Bool = false,
  colors~ : ColorSpecs = ColorSpecs::default(),
  hyperlink~ : HyperlinkConfig = HyperlinkConfig::default(),
  stats~ : Bool = false,
  heading~ : Bool = false,
  path~ : Bool = true,
  only_matching~ : Bool = false,
  per_match~ : Bool = false,
  per_match_one_line~ : Bool = false,
  replacement~ : Bytes? = None,
  max_columns~ : Int64? = None,
  max_columns_preview~ : Bool = false,
  column~ : Bool = false,
  byte_offset~ : Bool = false,
  trim_ascii~ : Bool = false,
  separator_search~ : Bytes? = None,
  separator_context~ : Bytes? = Some(b"--"),
  separator_field_match~ : Bytes = b":",
  separator_field_context~ : Bytes = b"-",
  separator_path~ : Byte? = None,
  path_terminator~ : Byte? = None,
  clock~ : () -> Int64 = zero_clock,
) -> Standard {
  {
    config: {
      coalesce_matches,
      colors,
      hyperlink,
      stats,
      heading,
      path,
      only_matching,
      per_match,
      per_match_one_line,
      replacement,
      max_columns,
      max_columns_preview,
      column,
      byte_offset,
      trim_ascii,
      separator_search,
      separator_context,
      separator_field_match,
      separator_field_context,
      separator_path,
      path_terminator,
      clock,
    },
    wtr: CounterWriter::new(wtr),
    matches: [],
  }
}
