///|
/// Binary detection settings for explicitly given files and for files found
/// while walking directories.
priv struct BinaryDetectionPair {
  explicit : @searcher.BinaryDetection
  implicit : @searcher.BinaryDetection
}

///|
fn BinaryDetectionPair::from_low(low : LowArgs) -> BinaryDetectionPair {
  let none = low.binary is AsText || low.null_data
  let convert = low.binary is SearchAndSuppress
  let explicit : @searcher.BinaryDetection = if none {
    BinaryNone
  } else {
    BinaryConvert(b'\x00')
  }
  let implicit : @searcher.BinaryDetection = if none {
    BinaryNone
  } else if convert {
    BinaryConvert(b'\x00')
  } else {
    BinaryQuit(b'\x00')
  }
  { explicit, implicit, }
}

///|
fn BinaryDetectionPair::is_none(self : BinaryDetectionPair) -> Bool {
  self.explicit is BinaryNone && self.implicit is BinaryNone
}

///|
priv struct State {
  is_terminal_stdout : Bool
  mut stdin_consumed : Bool
  cwd : String
}

///|
priv struct Paths {
  paths : Array[String]
  has_implicit_path : Bool
  is_one_file : Bool
}

///|
fn Paths::is_only_stdin(self : Paths) -> Bool {
  self.paths.length() == 1 && self.paths[0] == "-"
}

///|
/// High level arguments derived from the low level flags.
pub struct HiArgs {
  priv mode : Mode
  priv patterns : Array[String]
  priv paths : Paths
  /// Whether files are searched as a whole, like ripgrep does when it uses
  /// memory maps (which changes binary detection; see `MmapChoice`).
  priv mmap : Bool
  priv binary : BinaryDetectionPair
  priv boundary : BoundaryMode?
  priv buffer : BufferMode
  priv byte_offset : Bool
  priv case : CaseMode
  priv color : ColorChoice
  priv colors : @printer.ColorSpecs
  priv column : Bool
  priv context : ContextMode
  priv context_separator : Bytes?
  priv crlf : Bool
  priv cwd : String
  priv dfa_size_limit : UInt64?
  priv encoding : EncodingMode
  priv engine : EngineChoice
  priv field_context_separator : Bytes
  priv field_match_separator : Bytes
  priv file_separator : Bytes?
  priv fixed_strings : Bool
  priv follow : Bool
  priv globs : @ignore.Override
  priv heading : Bool
  priv hidden : Bool
  priv hyperlink_config : @printer.HyperlinkConfig
  priv ignore_file_case_insensitive : Bool
  priv ignore_file : Array[String]
  priv include_zero : Bool
  priv invert_match : Bool
  priv is_terminal_stdout : Bool
  priv line_number : Bool
  priv max_columns : UInt64?
  priv max_columns_preview : Bool
  priv max_count : UInt64?
  priv max_depth : Int32?
  priv max_filesize : UInt64?
  priv multiline : Bool
  priv multiline_dotall : Bool
  priv no_ignore_dot : Bool
  priv no_ignore_exclude : Bool
  priv no_ignore_files : Bool
  priv no_ignore_global : Bool
  priv no_ignore_parent : Bool
  priv no_ignore_vcs : Bool
  priv no_require_git : Bool
  priv no_unicode : Bool
  priv null_data : Bool
  priv one_file_system : Bool
  priv only_matching : Bool
  priv path_separator : Byte?
  priv path_terminator : Byte?
  priv pre : String?
  priv pre_globs : @ignore.Override
  priv quiet : Bool
  priv quit_after_match : Bool
  priv regex_size_limit : UInt64?
  priv replace : Bytes?
  priv sort : SortMode?
  priv stats : @printer.Stats?
  priv stop_on_nonmatch : Bool
  priv threads : Int32
  priv trim : Bool
  priv types : @ignore.Types
  priv vimgrep : Bool
  priv with_filename : Bool
}

///|
fn current_dir() -> String raise RgError {
  match @sys.current_dir() {
    Some(cwd) => cwd
    None =>
      match @sys.env_var("PWD") {
        Some(cwd) if !cwd.is_empty() => cwd
        _ =>
          raise RgError(
            "failed to get current working directory: unknown error\ndid your CWD get deleted?",
          )
      }
  }
}

///|
async fn patterns_from_low(state : State, low : LowArgs) -> Array[String] {
  if !(low.mode is Search(_)) {
    return []
  }
  if low.patterns.is_empty() {
    if low.positional.is_empty() {
      raise RgError("ripgrep requires at least one pattern to execute a search")
    }
    let pat = low.positional.remove(0)
    if @osstr.has_escapes(pat) {
      raise RgError("pattern given is not valid UTF-8")
    }
    return [pat]
  }
  let seen : Map[String, Unit] = Map([])
  let patterns = []
  let add = (pat : String) => {
    if !seen.contains(pat) {
      seen[pat] = ()
      patterns.push(pat)
    }
  }
  for source in low.patterns {
    match source {
      Regexp(pat) => add(pat)
      File(path) =>
        if path == "-" {
          if state.stdin_consumed {
            raise RgError(
              "error reading -f/--file from stdin: stdin has already been consumed",
            )
          }
          let pats = @cli.patterns_from_stdin() catch {
            e => raise RgError(e.to_string())
          }
          for pat in pats {
            add(pat)
          }
          state.stdin_consumed = true
        } else {
          let pats = @cli.patterns_from_path(path) catch {
            e => raise RgError(e.to_string())
          }
          for pat in pats {
            add(pat)
          }
        }
    }
  }
  low.patterns.clear()
  patterns
}

///|
async fn is_dir_path(path : String) -> Bool {
  @sys.metadata(path).is_dir() catch {
    _ => false
  }
}

///|
async fn is_file_path(path : String) -> Bool {
  @sys.metadata(path).is_file() catch {
    _ => false
  }
}

///|
async fn paths_from_low(state : State, low : LowArgs) -> Paths {
  let paths = []
  for path in low.positional {
    if state.stdin_consumed && path == "-" {
      raise RgError(
        "error: attempted to read patterns from stdin while also searching stdin",
      )
    }
    paths.push(@sys.normalize_path(path))
  }
  low.positional.clear()
  log_debug(
    "rg::flags::hiargs",
    "number of paths given to search: \{paths.length()}",
  )
  if !paths.is_empty() {
    let is_one_file = paths.length() == 1 &&
      (paths[0] == "-" || !is_dir_path(paths[0]))
    return { paths, has_implicit_path: false, is_one_file, }
  }
  let is_readable_stdin = if state.stdin_consumed || !(low.mode is Search(_)) {
    false
  } else {
    match @cli.is_readable_stdin() {
      Available(readable) => readable
      Unavailable(reason) => raise RgError(reason)
    }
  }
  let use_cwd = !is_readable_stdin ||
    state.stdin_consumed ||
    !(low.mode is Search(_))
  if use_cwd {
    { paths: ["./"], has_implicit_path: true, is_one_file: false, }
  } else {
    { paths: ["-"], has_implicit_path: true, is_one_file: true, }
  }
}

///|
fn types_from_low(low : LowArgs) -> @ignore.Types raise RgError {
  let builder = @ignore.TypesBuilder::new()
  ignore(builder.add_defaults())
  for change in low.type_changes {
    match change {
      Clear(name) => ignore(builder.clear(name))
      Add(def) =>
        builder.add_def(def) catch {
          e => raise RgError(e.to_string())
        }
      Select(name) => ignore(builder.select(name))
      Negate(name) => ignore(builder.negate(name))
    }
  }
  builder.build() catch {
    e => raise RgError(e.to_string())
  }
}

///|
fn globs_from_low(
  state : State,
  low : LowArgs,
) -> @ignore.Override raise RgError {
  if low.globs.is_empty() && low.iglobs.is_empty() {
    return @ignore.Override::empty()
  }
  let builder = @ignore.OverrideBuilder::new(state.cwd)
  if low.glob_case_insensitive {
    ignore(builder.case_insensitive(true))
  }
  for glob in low.globs {
    ignore(builder.add(glob) catch { e => raise RgError(e.to_string()) })
  }
  ignore(builder.case_insensitive(true))
  for glob in low.iglobs {
    ignore(builder.add(glob) catch { e => raise RgError(e.to_string()) })
  }
  builder.build() catch {
    e => raise RgError(e.to_string())
  }
}

///|
fn preprocessor_globs_from_low(
  state : State,
  low : LowArgs,
) -> @ignore.Override raise RgError {
  if low.pre_glob.is_empty() {
    return @ignore.Override::empty()
  }
  let builder = @ignore.OverrideBuilder::new(state.cwd)
  for glob in low.pre_glob {
    ignore(builder.add(glob) catch { e => raise RgError(e.to_string()) })
  }
  builder.build() catch {
    e => raise RgError(e.to_string())
  }
}

///|
fn stats_from_low(low : LowArgs) -> @printer.Stats? {
  if !(low.mode is Search(_)) {
    return None
  }
  if low.stats || low.mode is Search(JSON) {
    return Some(@printer.Stats::new())
  }
  None
}

///|
fn color_specs_from_low(low : LowArgs) -> @printer.ColorSpecs raise RgError {
  let specs = @printer.default_color_specs()
  for spec in low.colors {
    specs.push(
      @printer.UserColorSpec::parse(spec) catch {
        e => raise RgError(e.to_string())
      },
    )
  }
  @printer.ColorSpecs::new(specs)
}

///|
async fn hyperlink_config_from_low(low : LowArgs) -> @printer.HyperlinkConfig {
  // Like ripgrep, hyperlinks use canonical (absolute) paths.
  let mut env = @printer.HyperlinkEnvironment::new().canonicalize(
    Some(path => Some(@sys.canonicalize(path)) catch { _ => None }),
  )
  if hostname(low.hostname_bin) is Some(host) {
    log_debug(
      "rg::flags::hiargs",
      "found hostname for hyperlink configuration: \{host}",
    )
    env = env.host(Some(host))
  }
  if wsl_prefix() is Some(prefix) {
    env = env.wsl_prefix(Some(prefix))
  }
  let fmt = if low.hyperlink_format.is_empty() {
    @printer.HyperlinkFormat::empty()
  } else {
    @printer.HyperlinkFormat::parse(low.hyperlink_format) catch {
      e => raise RgError("invalid hyperlink format: \{e}")
    }
  }
  @printer.HyperlinkConfig::new(env, fmt)
}

///|
async fn hostname(bin : String?) -> String? {
  guard bin is Some(bin) else { return @cli.hostname() }
  let rdr = @cli.CommandReader::new(bin, []) catch {
    _ => return @cli.hostname()
  }
  let out = rdr.read_to_end() catch { _ => return @cli.hostname() }
  // Like `std::io::read_to_string`, output that isn't valid UTF-8 is an
  // error (falling back to the platform hostname).
  let out = @osstr.decode(out)
  if @osstr.has_escapes(out) {
    return @cli.hostname()
  }
  let host = @osstr.trim_white_space(out)
  if host.is_empty() {
    return @cli.hostname()
  }
  Some(host)
}

///|
fn wsl_prefix() -> String? {
  match @sys.env_var("WSL_DISTRO_NAME") {
    Some(distro) => Some("wsl$/\{distro}")
    None => None
  }
}

///|
async fn sort_supported(sort : SortMode) -> Unit {
  let what = match sort.kind {
    Path => return
    LastModified => "last modified"
    LastAccessed => "last accessed"
    Created => "creation time"
  }
  let times = @sys.file_times(".") catch {
    e => raise RgError("sorting by \{what} isn't supported: \{e}")
  }
  let available = match sort.kind {
    LastModified => times.modified is Some(_)
    LastAccessed => times.accessed is Some(_)
    Created => times.created is Some(_)
    Path => true
  }
  if !available {
    raise RgError(
      "sorting by \{what} isn't supported: creation time is not available on this platform currently",
    )
  }
}

///|
/// Converts low level arguments into high level arguments.
pub async fn HiArgs::from_low_args(low : LowArgs) -> HiArgs {
  if low.search_zip {
    raise RgError("compressed search (-z/--search-zip) is deferred in cli/rg")
  }
  if low.one_file_system {
    raise RgError(
      "--one-file-system requires released public device/inode metadata APIs",
    )
  }
  if low.sort is Some(sort) {
    sort_supported(sort)
  }
  if low.index > 0 || low.mode is Index(_) {
    if low.indexing_unsupported_flag() is Some(flag) {
      raise RgError("flag --\{flag} does not support indexing")
    }
  }
  match low.mode {
    Search(CountMatches) if low.invert_match => low.mode = Search(Count)
    Search(Count) if low.only_matching => low.mode = Search(CountMatches)
    _ => ()
  }
  let state : State = {
    is_terminal_stdout: @sys.is_tty(1) is Available(true),
    stdin_consumed: false,
    cwd: current_dir(),
  }
  let patterns = patterns_from_low(state, low)
  let paths = paths_from_low(state, low)
  let binary = BinaryDetectionPair::from_low(low)
  let mmap = if @sys.mmap_supported() {
    match low.mmap {
      // If we're only searching a few paths and all of them are files, then
      // memory maps are probably faster.
      Auto => {
        let mut all_files = paths.paths.length() <= 10
        for path in paths.paths {
          if !all_files {
            break
          }
          all_files = is_file_path(path)
        }
        all_files
      }
      AlwaysTryMmap => true
      Never => false
    }
  } else {
    false
  }
  let colors = color_specs_from_low(low)
  let hyperlink_config = hyperlink_config_from_low(low)
  let stats = stats_from_low(low)
  let types = types_from_low(low)
  let globs = globs_from_low(state, low)
  let pre_globs = preprocessor_globs_from_low(state, low)
  let color = match low.color {
    Auto if !state.is_terminal_stdout => ColorChoice::Never
    c => c
  }
  let column = low.column.unwrap_or(low.vimgrep)
  let heading = match low.heading {
    None => !low.vimgrep && state.is_terminal_stdout
    Some(false) => false
    Some(true) => !low.vimgrep
  }
  let path_terminator = if low.null { Some(b'\x00') } else { None }
  let quit_after_match = stats is None && low.quiet
  let threads = if low.sort is Some(_) || paths.is_one_file {
    1
  } else {
    match low.threads {
      Some(t) => t
      None => 1
    }
  }
  let with_filename = match low.with_filename {
    Some(b) => b
    None => low.vimgrep || !paths.is_one_file
  }
  let file_separator = match low.mode {
    Search(Standard) =>
      if heading {
        Some(b"")
      } else {
        match low.context {
          Limited(limited) => {
            let (before, after) = limited.get()
            if before > 0 || after > 0 {
              low.context_separator
            } else {
              None
            }
          }
          Passthru => None
        }
      }
    _ => None
  }
  let line_number = match low.line_number {
    Some(b) => b
    None =>
      if low.quiet {
        false
      } else {
        match low.mode {
          Search(FilesWithMatches)
          | Search(FilesWithoutMatch)
          | Search(Count)
          | Search(CountMatches) => false
          Search(JSON) => true
          Search(Standard) =>
            (state.is_terminal_stdout && !paths.is_only_stdin()) ||
            column ||
            low.vimgrep
          _ => false
        }
      }
  }
  {
    mode: low.mode,
    patterns,
    paths,
    mmap,
    binary,
    boundary: low.boundary,
    buffer: low.buffer,
    byte_offset: low.byte_offset,
    case: low.case,
    color,
    colors,
    column,
    context: low.context,
    context_separator: low.context_separator,
    crlf: low.crlf,
    cwd: state.cwd,
    dfa_size_limit: low.dfa_size_limit,
    encoding: low.encoding,
    engine: low.engine,
    field_context_separator: low.field_context_separator,
    field_match_separator: low.field_match_separator,
    file_separator,
    fixed_strings: low.fixed_strings,
    follow: low.follow,
    globs,
    heading,
    hidden: low.hidden,
    hyperlink_config,
    ignore_file_case_insensitive: low.ignore_file_case_insensitive,
    ignore_file: low.ignore_file,
    include_zero: low.include_zero,
    invert_match: low.invert_match,
    is_terminal_stdout: state.is_terminal_stdout,
    line_number,
    max_columns: low.max_columns,
    max_columns_preview: low.max_columns_preview,
    max_count: low.max_count,
    max_depth: low.max_depth,
    max_filesize: low.max_filesize,
    multiline: low.multiline,
    multiline_dotall: low.multiline_dotall,
    no_ignore_dot: low.no_ignore_dot,
    no_ignore_exclude: low.no_ignore_exclude,
    no_ignore_files: low.no_ignore_files,
    no_ignore_global: low.no_ignore_global,
    no_ignore_parent: low.no_ignore_parent,
    no_ignore_vcs: low.no_ignore_vcs,
    no_require_git: low.no_require_git,
    no_unicode: low.no_unicode,
    null_data: low.null_data,
    one_file_system: low.one_file_system,
    only_matching: low.only_matching,
    path_separator: low.path_separator,
    path_terminator,
    pre: low.pre,
    pre_globs,
    quiet: low.quiet,
    quit_after_match,
    regex_size_limit: low.regex_size_limit,
    replace: low.replace,
    sort: low.sort,
    stats,
    stop_on_nonmatch: low.stop_on_nonmatch,
    threads,
    trim: low.trim,
    types,
    vimgrep: low.vimgrep,
    with_filename,
  }
}

///|
fn suggest_multiline(msg : String) -> String {
  if msg.contains("the literal") && msg.contains("not allowed") {
    "\{msg}\n\nConsider enabling multiline mode with the --multiline flag (or -U for short).\nWhen multiline mode is enabled, new line characters can be matched."
  } else {
    msg
  }
}

///|
fn suggest_text(msg : String) -> String {
  if msg.contains("pattern contains \"\\0\"") {
    "\{msg}\n\nConsider enabling text mode with the --text flag (or -a for short). Otherwise,\nbinary detection is enabled and matching a NUL byte is impossible."
  } else {
    msg
  }
}

///|
fn clamp_size(n : UInt64) -> Int32 {
  if n > 0x7FFFFFFFUL {
    0x7FFFFFFF
  } else {
    n.to_int()
  }
}

///|
fn HiArgs::matcher_rust(
  self : HiArgs,
) -> @grep_regex.RegexMatcher raise RgError {
  let builder = @grep_regex.RegexMatcherBuilder::new()
    .multi_line(true)
    .unicode(!self.no_unicode)
    .octal(false)
    .fixed_strings(self.fixed_strings)
  match self.case {
    Sensitive => ignore(builder.case_insensitive(false))
    Insensitive => ignore(builder.case_insensitive(true))
    Smart => ignore(builder.case_smart(true))
  }
  match self.boundary {
    Some(Line) => ignore(builder.whole_line(true))
    Some(Word) => ignore(builder.word(true))
    None => ()
  }
  if self.multiline {
    ignore(builder.dot_matches_new_line(self.multiline_dotall))
    if self.crlf {
      ignore(builder.crlf(true).line_terminator(None))
    }
  } else {
    ignore(builder.line_terminator(Some(b'\n')).dot_matches_new_line(false))
    if self.crlf {
      ignore(builder.crlf(true))
    }
    if self.null_data {
      ignore(builder.line_terminator(Some(b'\x00')))
    }
  }
  if self.regex_size_limit is Some(limit) {
    ignore(builder.size_limit(clamp_size(limit)))
  }
  if self.dfa_size_limit is Some(limit) {
    ignore(builder.dfa_size_limit(clamp_size(limit)))
  }
  if !self.binary.is_none() {
    ignore(builder.ban_byte(Some(b'\x00')))
  }
  builder.build_many(self.patterns) catch {
    e => raise RgError(suggest_text(suggest_multiline(e.to_string())))
  }
}

///|
/// Builds the matcher for the configured regex engine.
pub fn HiArgs::matcher(self : HiArgs) -> @grep_regex.RegexMatcher raise RgError {
  match self.engine {
    Default => self.matcher_rust()
    PCRE2 => raise RgError("PCRE2 is not available in this build of ripgrep")
    Auto => {
      let rust_err = try self.matcher_rust() catch {
        RgError(msg) => msg
      } noraise {
        m => return m
      }
      let pcre_err = "PCRE2 is not available in this build of ripgrep"
      let divider = "~".repeat(79)
      raise RgError(
        "regex could not be compiled with either the default regex engine or with PCRE2.\n\ndefault regex engine error:\n\{divider}\n\{rust_err}\n\{divider}\n\nPCRE2 regex engine error:\n\{pcre_err}",
      )
    }
  }
}

///|
pub fn HiArgs::matches_possible(self : HiArgs) -> Bool {
  if self.patterns.is_empty() && !self.invert_match {
    return false
  }
  if self.max_count == Some(0) {
    return false
  }
  true
}

///|
pub fn HiArgs::mode(self : HiArgs) -> Mode {
  self.mode
}

///|
pub fn HiArgs::quiet(self : HiArgs) -> Bool {
  self.quiet
}

///|
pub fn HiArgs::quit_after_match(self : HiArgs) -> Bool {
  self.quit_after_match
}

///|
pub fn HiArgs::has_implicit_path(self : HiArgs) -> Bool {
  self.paths.has_implicit_path
}

///|
pub fn HiArgs::threads(self : HiArgs) -> Int32 {
  self.threads
}

///|
pub fn HiArgs::stats(self : HiArgs) -> @printer.Stats? {
  match self.stats {
    Some(s) => Some(s.clone())
    None => None
  }
}

///|
pub fn HiArgs::types(self : HiArgs) -> @ignore.Types {
  self.types
}

///|
pub fn HiArgs::searcher(self : HiArgs) -> @searcher.Searcher {
  let line_term = if self.crlf {
    @matcher.LineTerminator::crlf()
  } else if self.null_data {
    @matcher.LineTerminator::byte(b'\x00')
  } else {
    @matcher.LineTerminator::byte(b'\n')
  }
  let builder = @searcher.SearcherBuilder::new()
    .max_matches(self.max_count.map(saturate_i64))
    .line_terminator(line_term)
    .invert_match(self.invert_match)
    .line_number(self.line_number)
    .multi_line(self.multiline)
    .stop_on_nonmatch(self.stop_on_nonmatch)
  match self.context {
    Passthru => ignore(builder.passthru(true))
    Limited(limited) => {
      let (before, after) = limited.get()
      ignore(builder.before_context(before).after_context(after))
    }
  }
  match self.encoding {
    Auto => ()
    Specific(enc) => ignore(builder.encoding(Some(enc)))
    Disabled => ignore(builder.bom_sniffing(false))
  }
  builder.build()
}

///|
/// Converts a `u64` limit to `Int64`, saturating: no count or length can
/// exceed `Int64::MAX`, so this preserves ripgrep's unsigned comparisons.
fn saturate_i64(x : UInt64) -> Int64 {
  if x > 0x7FFFFFFFFFFFFFFFUL {
    0x7FFFFFFFFFFFFFFFL
  } else {
    x.reinterpret_as_int64()
  }
}
