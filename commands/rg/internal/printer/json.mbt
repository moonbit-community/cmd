///|
/// The configuration for the JSON printer.
priv struct JSONConfig {
  mut pretty : Bool
  mut always_begin_end : Bool
  mut replacement : Bytes?
  mut clock : () -> Int64
}

///|
/// A builder for a JSON lines printer.
///
/// The builder permits configuring how the printer behaves. The JSON
/// printer has fewer configuration options than the standard printer
/// because it is a structured format, and the printer always attempts to
/// find the most information possible.
pub struct JSONBuilder {
  priv config : JSONConfig
}

///|
/// Return a new builder for configuring the JSON printer.
pub fn JSONBuilder::new() -> JSONBuilder {
  {
    config: {
      pretty: false,
      always_begin_end: false,
      replacement: None,
      clock: zero_clock,
    },
  }
}

///|
/// Create a JSON printer that writes results to the given writer.
pub fn JSONBuilder::build(self : JSONBuilder, wtr : &@termcolor.Write) -> JSON {
  {
    config: { ..self.config, },
    wtr: CounterWriter::new(@termcolor.NoColor::new(wtr)),
    matches: [],
    msg: @termcolor.ByteVec::new(),
  }
}

///|
/// Print JSON in a pretty printed format. This is not valid JSON lines
/// output, so it should only be used for debugging.
pub fn JSONBuilder::pretty(self : JSONBuilder, yes : Bool) -> JSONBuilder {
  self.config.pretty = yes
  self
}

///|
/// When enabled, the `begin` and `end` messages are always emitted, even
/// when no match is found.
pub fn JSONBuilder::always_begin_end(
  self : JSONBuilder,
  yes : Bool,
) -> JSONBuilder {
  self.config.always_begin_end = yes
  self
}

///|
/// Set the bytes that will be used to replace each occurrence of a match
/// found. The replacement is emitted in a `replacement` field of each
/// submatch.
pub fn JSONBuilder::replacement(
  self : JSONBuilder,
  replacement : Bytes?,
) -> JSONBuilder {
  self.config.replacement = replacement
  self
}

///|
/// Set the clock used for timing statistics (monotonic nanoseconds). By
/// default, a clock that always returns `0` is used.
pub fn JSONBuilder::clock(
  self : JSONBuilder,
  clock : () -> Int64,
) -> JSONBuilder {
  self.config.clock = clock
  self
}

///|
/// The JSON printer, which emits results in a JSON lines format.
///
/// The message types are `begin`, `end`, `match` and `context`, in the
/// exact format emitted by ripgrep's `--json` flag.
pub struct JSON {
  priv config : JSONConfig
  priv wtr : CounterWriter
  priv matches : Array[@matcher.Match]
  priv msg : @termcolor.ByteVec
}

///|
/// Return a JSON lines printer with a default configuration.
pub fn JSON::new(wtr : &@termcolor.Write) -> JSON {
  JSONBuilder::new().build(wtr)
}

///|
/// Return an implementation of `Sink` for the JSON printer.
pub fn JSON::sink(self : JSON, matcher : &@matcher.Matcher) -> JSONSink {
  {
    matcher,
    replacer: Replacer::new(),
    json: self,
    path: None,
    start_time: (self.config.clock)(),
    match_count: 0,
    binary_byte_offset: None,
    begin_printed: false,
    stats: Stats::new(),
  }
}

///|
/// Return an implementation of `Sink` associated with a file path.
pub fn JSON::sink_with_path(
  self : JSON,
  matcher : &@matcher.Matcher,
  path : String,
) -> JSONSink {
  {
    matcher,
    replacer: Replacer::new(),
    json: self,
    path: Some(path),
    start_time: (self.config.clock)(),
    match_count: 0,
    binary_byte_offset: None,
    begin_printed: false,
    stats: Stats::new(),
  }
}

///|
/// Write the given message followed by a new line.
async fn JSON::write_message(self : JSON, message : Message) -> Unit {
  self.msg.clear()
  let w = JsonWriter::new(self.msg, pretty=self.config.pretty)
  message.write_json(w)
  self.wtr.write_slice(self.msg.storage(), 0, self.msg.length())
  self.wtr.write_bytes(b"\n")
}

///|
/// Returns true if and only if this printer has written at least one byte
/// to the underlying writer during any of the previous searches.
pub fn JSON::has_written(self : JSON) -> Bool {
  self.wtr.total_count() > 0
}

///|
/// Return the underlying writer (wrapped in `NoColor`).
pub fn JSON::get_mut(self : JSON) -> &@termcolor.WriteColor {
  self.wtr.get_mut()
}

///|
/// An implementation of `Sink` associated with a matcher and an optional
/// file path for the JSON printer.
pub struct JSONSink {
  priv matcher : &@matcher.Matcher
  priv replacer : Replacer
  priv json : JSON
  priv path : String?
  priv mut start_time : Int64
  priv mut match_count : Int64
  priv mut binary_byte_offset : Int64?
  priv mut begin_printed : Bool
  priv stats : Stats
}

///|
/// Returns true if and only if this printer received a match in the
/// previous search.
pub fn JSONSink::has_match(self : JSONSink) -> Bool {
  self.match_count > 0
}

///|
/// Return the total number of matches reported to this sink.
pub fn JSONSink::match_count(self : JSONSink) -> Int64 {
  self.match_count
}

///|
/// If binary data was found in the previous search, this returns the
/// offset at which the binary data was first detected.
pub fn JSONSink::binary_byte_offset(self : JSONSink) -> Int64? {
  self.binary_byte_offset
}

///|
/// Return a reference to the stats produced by the printer for all
/// searches executed on this sink.
pub fn JSONSink::stats(self : JSONSink) -> Stats {
  self.stats
}

///|
/// Execute the matcher over the given bytes and record the match locations
/// if the current configuration demands match granularity.
fn JSONSink::record_matches(
  self : JSONSink,
  searcher : @searcher.Searcher,
  hay : FixedArray[Byte],
  hs : Int32,
  he : Int32,
  range_start : Int32,
  range_end : Int32,
) -> Unit {
  let matches = self.json.matches
  matches.clear()
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
  if matches.last() is Some(last) && last.is_empty() && last.start >= he - hs {
    matches.pop() |> ignore
  }
}

///|
/// If the configuration specifies a replacement, then this executes the
/// replacement, lazily allocating memory if necessary.
fn JSONSink::replace(
  self : JSONSink,
  searcher : @searcher.Searcher,
  hay : FixedArray[Byte],
  hs : Int32,
  he : Int32,
  range_start : Int32,
  range_end : Int32,
) -> Unit {
  self.replacer.clear()
  if self.json.config.replacement is Some(replacement) {
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
/// Write the "begin" message.
async fn JSONSink::write_begin_message(self : JSONSink) -> Unit {
  if self.begin_printed {
    return
  }
  self.json.write_message(Begin(path=self.path))
  self.begin_printed = true
}

///|
pub impl @searcher.Sink for JSONSink with fn matched(self, searcher, mat) {
  self.match_count += 1
  self.write_begin_message()
  let hs = mat.buf_start
  let he = mat.buf_start + mat.buf_len
  self.record_matches(searcher, mat.buf, hs, he, mat.start, mat.end)
  self.replace(searcher, mat.buf, hs, he, mat.start, mat.end)
  self.stats.add_matches(self.json.matches.length().to_int64())
  self.stats.add_matched_lines(
    count_lines_in(
      mat.buf,
      hs + mat.start,
      hs + mat.end,
      searcher.line_terminator().as_byte(),
    ),
  )
  let submatches = make_submatches(
    mat.buf,
    hs + mat.start,
    mat.end - mat.start,
    self.json.matches,
    self.replacer.replacement(),
  )
  let msg = Message::Match(
    path=self.path,
    buf=mat.buf,
    start=hs + mat.start,
    end=hs + mat.end,
    line_number=mat.line_number,
    absolute_offset=mat.absolute_byte_offset,
    submatches~,
  )
  self.json.write_message(msg)
  true
}

///|
pub impl @searcher.Sink for JSONSink with fn context(self, searcher, ctx) {
  self.write_begin_message()
  self.json.matches.clear()
  let submatches = if searcher.invert_match() {
    let len = ctx.end - ctx.start
    self.record_matches(searcher, ctx.buf, ctx.start, ctx.end, 0, len)
    self.replace(searcher, ctx.buf, ctx.start, ctx.end, 0, len)
    make_submatches(
      ctx.buf,
      ctx.start,
      len,
      self.json.matches,
      self.replacer.replacement(),
    )
  } else {
    []
  }
  let msg = Message::Context(
    path=self.path,
    buf=ctx.buf,
    start=ctx.start,
    end=ctx.end,
    line_number=ctx.line_number,
    absolute_offset=ctx.absolute_byte_offset,
    submatches~,
  )
  self.json.write_message(msg)
  true
}

///|
pub impl @searcher.Sink for JSONSink with fn binary_data(
  _self,
  _searcher,
  _binary_byte_offset,
) {
  true
}

///|
pub impl @searcher.Sink for JSONSink with fn begin(self, _searcher) {
  self.json.wtr.reset_count()
  self.start_time = (self.json.config.clock)()
  self.match_count = 0
  self.binary_byte_offset = None
  if !self.json.config.always_begin_end {
    return true
  }
  self.write_begin_message()
  true
}

///|
pub impl @searcher.Sink for JSONSink with fn finish(self, _searcher, finish) {
  self.binary_byte_offset = finish.binary_byte_offset
  self.stats.add_elapsed((self.json.config.clock)() - self.start_time)
  self.stats.add_searches(1)
  if self.match_count > 0 {
    self.stats.add_searches_with_match(1)
  }
  self.stats.add_bytes_searched(finish.byte_count)
  self.stats.add_bytes_printed(self.json.wtr.count())
  if !self.begin_printed {
    return
  }
  let msg = Message::End(
    path=self.path,
    binary_offset=finish.binary_byte_offset,
    stats=self.stats.clone(),
  )
  self.json.write_message(msg)
}

///|
/// Builds the submatches for a match or context message. `base` is the
/// start of the reported bytes in `buf`; match offsets are relative to it.
fn make_submatches(
  buf : FixedArray[Byte],
  base : Int32,
  len : Int32,
  matches : Array[@matcher.Match],
  replacement : (@termcolor.ByteVec, Array[@matcher.Match])?,
) -> Array[SubMatch] {
  let out = []
  for i, mat in matches {
    // Matches are found in the whole buffer, but only those within the
    // reported lines (`len` bytes from `base`) are reported. Matches can
    // extend past them in multi-line mode when the match count limit
    // truncates the lines (ripgrep 15.2.0 panics there); like the standard
    // printer, clip them to the lines and skip those beyond.
    if mat.end > len && mat.start >= len {
      continue
    }
    let mat : @matcher.Match = if mat.end > len {
      { start: mat.start, end: len, }
    } else {
      mat
    }
    let repl = match replacement {
      Some((rbuf, rmatches)) => {
        let rm = rmatches[i]
        Some(rbuf.slice_to_bytes(rm.start, rm.end))
      }
      None => None
    }
    out.push({
      buf,
      m_start: base + mat.start,
      m_end: base + mat.end,
      replacement: repl,
      start: mat.start,
      end: mat.end,
    })
  }
  out
}
