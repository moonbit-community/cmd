///|
/// The configuration for the summary printer.
priv struct SummaryConfig {
  mut kind : SummaryKind
  mut colors : ColorSpecs
  mut hyperlink : HyperlinkConfig
  mut stats : Bool
  mut path : Bool
  mut exclude_zero : Bool
  mut separator_field : Bytes
  mut separator_path : Byte?
  mut path_terminator : Byte?
  mut clock : () -> Int64
}

///|
/// The type of summary output (if any) to print.
pub(all) enum SummaryKind {
  /// Show only a count of the total number of matches (counting each line
  /// at most once) found.
  Count
  /// Show only a count of the total number of matches (counting possibly
  /// many matches on each line) found.
  CountMatches
  /// Show only the file path if and only if a match was found.
  PathWithMatch
  /// Show only the file path if and only if a match was found.
  PathWithoutMatch
  /// Don't show any output and stop the search once a match is found.
  QuietWithMatch
  /// Don't show any output and stop the search once a non-matching file is
  /// found.
  QuietWithoutMatch
} derive(Eq, Debug)

///|
/// Returns true if and only if this output mode requires a file path.
fn SummaryKind::requires_path(self : SummaryKind) -> Bool {
  match self {
    PathWithMatch | PathWithoutMatch => true
    Count | CountMatches | QuietWithMatch | QuietWithoutMatch => false
  }
}

///|
/// Returns true if and only if this output mode requires computing
/// statistics, regardless of whether they have been enabled or not.
fn SummaryKind::requires_stats(self : SummaryKind) -> Bool {
  match self {
    CountMatches => true
    Count
    | PathWithMatch
    | PathWithoutMatch
    | QuietWithMatch
    | QuietWithoutMatch => false
  }
}

///|
/// Returns true if and only if a printer using this output mode can quit
/// after seeing the first match.
fn SummaryKind::quit_early(self : SummaryKind) -> Bool {
  match self {
    PathWithMatch | QuietWithMatch => true
    Count | CountMatches | PathWithoutMatch | QuietWithoutMatch => false
  }
}

///|
fn SummaryKind::debug_name(self : SummaryKind) -> String {
  match self {
    Count => "Count"
    CountMatches => "CountMatches"
    PathWithMatch => "PathWithMatch"
    PathWithoutMatch => "PathWithoutMatch"
    QuietWithMatch => "QuietWithMatch"
    QuietWithoutMatch => "QuietWithoutMatch"
  }
}

///|
/// A builder for the summary printer.
///
/// The builder permits configuring how the printer behaves. The summary
/// printer has fewer configuration options than the standard printer
/// because it aims to produce aggregate output about a single search
/// (typically just one line) instead of output for each match.
pub struct SummaryBuilder {
  priv config : SummaryConfig
}

///|
/// Return a new builder for configuring the summary printer.
pub fn SummaryBuilder::new() -> SummaryBuilder {
  {
    config: {
      kind: Count,
      colors: ColorSpecs::default(),
      hyperlink: HyperlinkConfig::default(),
      stats: false,
      path: true,
      exclude_zero: true,
      separator_field: b":",
      separator_path: None,
      path_terminator: None,
      clock: zero_clock,
    },
  }
}

///|
/// Build a printer using any implementation of `WriteColor`.
pub fn SummaryBuilder::build(
  self : SummaryBuilder,
  wtr : &@termcolor.WriteColor,
) -> Summary {
  { config: { ..self.config, }, wtr: CounterWriter::new(wtr), }
}

///|
/// Build a printer from any byte sink, wrapped in `NoColor`.
pub fn SummaryBuilder::build_no_color(
  self : SummaryBuilder,
  wtr : &@termcolor.Write,
) -> Summary {
  self.build(@termcolor.NoColor::new(wtr))
}

///|
/// Set the output mode for this printer.
pub fn SummaryBuilder::kind(
  self : SummaryBuilder,
  kind : SummaryKind,
) -> SummaryBuilder {
  self.config.kind = kind
  self
}

///|
/// Set the user color specifications to use for coloring in this printer.
pub fn SummaryBuilder::color_specs(
  self : SummaryBuilder,
  specs : ColorSpecs,
) -> SummaryBuilder {
  self.config.colors = specs
  self
}

///|
/// Set the configuration to use for hyperlinks output by this printer.
pub fn SummaryBuilder::hyperlink(
  self : SummaryBuilder,
  config : HyperlinkConfig,
) -> SummaryBuilder {
  self.config.hyperlink = config
  self
}

///|
/// Enable the gathering of various aggregate statistics.
pub fn SummaryBuilder::stats(
  self : SummaryBuilder,
  yes : Bool,
) -> SummaryBuilder {
  self.config.stats = yes
  self
}

///|
/// When enabled, if a path was given to the printer, then it is shown in
/// the output.
pub fn SummaryBuilder::path(
  self : SummaryBuilder,
  yes : Bool,
) -> SummaryBuilder {
  self.config.path = yes
  self
}

///|
/// Exclude count-related summary results with no matches (enabled by
/// default).
pub fn SummaryBuilder::exclude_zero(
  self : SummaryBuilder,
  yes : Bool,
) -> SummaryBuilder {
  self.config.exclude_zero = yes
  self
}

///|
/// Set the separator used between fields for the `Count` and
/// `CountMatches` modes (`:` by default).
pub fn SummaryBuilder::separator_field(
  self : SummaryBuilder,
  sep : Bytes,
) -> SummaryBuilder {
  self.config.separator_field = sep
  self
}

///|
/// Set the path separator used when printing file paths.
pub fn SummaryBuilder::separator_path(
  self : SummaryBuilder,
  sep : Byte?,
) -> SummaryBuilder {
  self.config.separator_path = sep
  self
}

///|
/// Set the path terminator used.
pub fn SummaryBuilder::path_terminator(
  self : SummaryBuilder,
  terminator : Byte?,
) -> SummaryBuilder {
  self.config.path_terminator = terminator
  self
}

///|
/// Set the clock used for timing statistics (monotonic nanoseconds). By
/// default, a clock that always returns `0` is used.
pub fn SummaryBuilder::clock(
  self : SummaryBuilder,
  clock : () -> Int64,
) -> SummaryBuilder {
  self.config.clock = clock
  self
}

///|
/// The summary printer, which emits aggregate results from a search.
pub struct Summary {
  priv config : SummaryConfig
  priv wtr : CounterWriter
}

///|
/// Return a summary printer with a default configuration.
pub fn Summary::new(wtr : &@termcolor.WriteColor) -> Summary {
  SummaryBuilder::new().build(wtr)
}

///|
/// Return a summary printer with a default configuration that drops all
/// color information.
pub fn Summary::new_no_color(wtr : &@termcolor.Write) -> Summary {
  SummaryBuilder::new().build_no_color(wtr)
}

///|
/// Return an implementation of `Sink` for the summary printer.
pub fn Summary::sink(
  self : Summary,
  matcher : &@matcher.Matcher,
) -> SummarySink {
  let interpolator = Interpolator::new(self.config.hyperlink)
  let stats = if self.config.stats || self.config.kind.requires_stats() {
    Some(Stats::new())
  } else {
    None
  }
  {
    matcher,
    summary: self,
    interpolator,
    path: None,
    start_time: (self.config.clock)(),
    match_count: 0,
    binary_byte_offset: None,
    stats,
  }
}

///|
/// Return an implementation of `Sink` associated with a file path.
pub fn Summary::sink_with_path(
  self : Summary,
  matcher : &@matcher.Matcher,
  path : String,
) -> SummarySink {
  if !self.config.path && !self.config.kind.requires_path() {
    return self.sink(matcher)
  }
  let interpolator = Interpolator::new(self.config.hyperlink)
  let stats = if self.config.stats || self.config.kind.requires_stats() {
    Some(Stats::new())
  } else {
    None
  }
  let ppath = PrinterPath::new(path).with_separator(self.config.separator_path)
  {
    matcher,
    summary: self,
    interpolator,
    path: Some(ppath),
    start_time: (self.config.clock)(),
    match_count: 0,
    binary_byte_offset: None,
    stats,
  }
}

///|
/// Returns true if and only if this printer has written at least one byte
/// to the underlying writer during any of the previous searches.
pub fn Summary::has_written(self : Summary) -> Bool {
  self.wtr.total_count() > 0
}

///|
/// Return the underlying writer.
pub fn Summary::get_mut(self : Summary) -> &@termcolor.WriteColor {
  self.wtr.get_mut()
}

///|
/// An implementation of `Sink` associated with a matcher and an optional
/// file path for the summary printer.
pub struct SummarySink {
  priv matcher : &@matcher.Matcher
  priv summary : Summary
  priv interpolator : Interpolator
  priv path : PrinterPath?
  priv mut start_time : Int64
  priv mut match_count : Int64
  priv mut binary_byte_offset : Int64?
  priv stats : Stats?
}

///|
/// Returns true if and only if this printer received a match in the
/// previous search (or, for the "without match" kinds, no match).
pub fn SummarySink::has_match(self : SummarySink) -> Bool {
  match self.summary.config.kind {
    PathWithoutMatch | QuietWithoutMatch => self.match_count == 0
    _ => self.match_count > 0
  }
}

///|
/// Return the number of matches counted by this sink in the previous
/// search. (In Rust this is a private field that the unit tests inspect.)
pub fn SummarySink::match_count(self : SummarySink) -> Int64 {
  self.match_count
}

///|
/// If binary data was found in the previous search, this returns the
/// offset at which the binary data was first detected.
pub fn SummarySink::binary_byte_offset(self : SummarySink) -> Int64? {
  self.binary_byte_offset
}

///|
/// Return a reference to the stats produced by the printer for all
/// searches executed on this sink (only available when stats are enabled or
/// required by the summary kind).
pub fn SummarySink::stats(self : SummarySink) -> Stats? {
  self.stats
}

///|
fn SummarySink::multi_line(
  self : SummarySink,
  searcher : @searcher.Searcher,
) -> Bool {
  searcher.multi_line_with_matcher(self.matcher)
}

///|
async fn SummarySink::write_path_line(
  self : SummarySink,
  searcher : @searcher.Searcher,
) -> Unit {
  if self.path is Some(_) {
    self.write_path()
    if self.summary.config.path_terminator is Some(term) {
      self.write([term])
    } else {
      self.write_line_term(searcher)
    }
  }
}

///|
async fn SummarySink::write_path_field(self : SummarySink) -> Unit {
  if self.path is Some(_) {
    self.write_path()
    if self.summary.config.path_terminator is Some(term) {
      self.write([term])
    } else {
      self.write(self.summary.config.separator_field)
    }
  }
}

///|
async fn SummarySink::write_path(self : SummarySink) -> Unit {
  if self.path is Some(path) {
    let status = self.start_hyperlink()
    self.write_spec(self.summary.config.colors.path(), path.bytes)
    self.end_hyperlink(status)
  }
}

///|
async fn SummarySink::start_hyperlink(self : SummarySink) -> Bool {
  guard self.path is Some(p) &&
    p.as_hyperlink(self.summary.config.hyperlink.env) is Some(hyperpath) else {
    return false
  }
  let values = Values::new(hyperpath)
  self.interpolator.begin(values, self.summary.wtr)
}

///|
async fn SummarySink::end_hyperlink(self : SummarySink, status : Bool) -> Unit {
  self.interpolator.finish(status, self.summary.wtr)
}

///|
async fn SummarySink::write_line_term(
  self : SummarySink,
  searcher : @searcher.Searcher,
) -> Unit {
  self.write(searcher.line_terminator().as_bytes())
}

///|
async fn SummarySink::write_spec(
  self : SummarySink,
  spec : @termcolor.ColorSpec,
  buf : Bytes,
) -> Unit {
  self.summary.wtr.set_color(spec)
  self.write(buf)
  self.summary.wtr.reset()
}

///|
async fn SummarySink::write(self : SummarySink, buf : Bytes) -> Unit {
  self.summary.wtr.write_bytes(buf)
}

///|
pub impl @searcher.Sink for SummarySink with fn matched(self, searcher, mat) {
  let is_multi_line = self.multi_line(searcher)
  let sink_match_count = if self.stats is None && !is_multi_line {
    1L
  } else {
    // This gives us as many bytes as the searcher can offer. This isn't
    // guaranteed to hold the necessary context to get match detection
    // correct (because of look-around), but it does in practice.
    let mut count = 0L
    find_iter_at_in_context(
      searcher,
      self.matcher,
      mat.buf,
      mat.buf_start,
      mat.buf_start + mat.buf_len,
      mat.start,
      mat.end,
      _ => {
        count += 1
        true
      },
    )
    // Because of `find_iter_at_in_context` being a giant kludge
    // internally, it's possible that it won't find *any* matches even
    // though we clearly know that there is at least one. So make sure we
    // record at least one here.
    if count < 1L {
      1L
    } else {
      count
    }
  }
  if is_multi_line {
    self.match_count += sink_match_count
  } else {
    self.match_count += 1
  }
  if self.stats is Some(stats) {
    stats.add_matches(sink_match_count)
    stats.add_matched_lines(
      count_lines_in(
        mat.buf,
        mat.buf_start + mat.start,
        mat.buf_start + mat.end,
        searcher.line_terminator().as_byte(),
      ),
    )
  } else if self.summary.config.kind.quit_early() {
    return false
  }
  true
}

///|
pub impl @searcher.Sink for SummarySink with fn binary_data(
  _self,
  _searcher,
  _binary_byte_offset,
) {
  true
}

///|
pub impl @searcher.Sink for SummarySink with fn begin(self, _searcher) {
  if self.path is None && self.summary.config.kind.requires_path() {
    raise PrinterError(
      "output kind \{self.summary.config.kind.debug_name()} requires a file path",
    )
  }
  self.summary.wtr.reset_count()
  self.start_time = (self.summary.config.clock)()
  self.match_count = 0
  self.binary_byte_offset = None
  true
}

///|
pub impl @searcher.Sink for SummarySink with fn finish(self, searcher, finish) {
  self.binary_byte_offset = finish.binary_byte_offset
  if self.stats is Some(stats) {
    stats.add_elapsed((self.summary.config.clock)() - self.start_time)
    stats.add_searches(1)
    if self.match_count > 0 {
      stats.add_searches_with_match(1)
    }
    stats.add_bytes_searched(finish.byte_count)
    stats.add_bytes_printed(self.summary.wtr.count())
  }
  // If our binary detection method says to quit after seeing binary data,
  // then we shouldn't print any results at all, even if we've found a match
  // before detecting binary data. The intent here is to keep
  // BinaryDetection::quit as a form of filter.
  if self.binary_byte_offset is Some(_) &&
    searcher.binary_detection().quit_byte() is Some(_) {
    // Squash the match count. The statistics reported will still contain
    // the match count, but the "official" match count should be zero.
    self.match_count = 0
    return
  }
  let show_count = !self.summary.config.exclude_zero || self.match_count > 0
  match self.summary.config.kind {
    Count =>
      if show_count {
        self.write_path_field()
        self.write(utf8_bytes(self.match_count.to_string()))
        self.write_line_term(searcher)
      }
    CountMatches =>
      if show_count {
        self.write_path_field()
        guard self.stats is Some(stats) else {
          abort("CountMatches should enable stats tracking")
        }
        self.write(utf8_bytes(stats.matches().to_string()))
        self.write_line_term(searcher)
      }
    PathWithMatch => if self.match_count > 0 { self.write_path_line(searcher) }
    PathWithoutMatch =>
      if self.match_count == 0 {
        self.write_path_line(searcher)
      }
    QuietWithMatch | QuietWithoutMatch => ()
  }
}

///|
/// An error reported by a printer (the analogue of an `io::Error` created
/// from a message in the Rust implementation).
pub(all) suberror PrinterError {
  PrinterError(String)
} derive(Debug)

///|
pub impl Show for PrinterError with fn output(self, logger) {
  let PrinterError(msg) = self
  logger.write_string(msg)
}
