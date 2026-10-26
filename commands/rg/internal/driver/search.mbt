///|
/// Something to search: a directory entry plus application level filtering.
pub struct Haystack {
  priv dent : @ignore.DirEntry
  priv strip_dot_prefix : Bool
}

///|
pub fn Haystack::path(self : Haystack) -> String {
  let p = self.dent.path()
  if self.strip_dot_prefix && p.has_prefix("./") {
    let rest = p.view(start_offset=2).to_owned()
    // Path::strip_prefix also removes any redundant separators.
    let mut r = rest
    while r.has_prefix("/") {
      r = r.view(start_offset=1).to_owned()
    }
    r
  } else {
    p
  }
}

///|
pub fn Haystack::is_stdin(self : Haystack) -> Bool {
  self.dent.is_stdin()
}

///|
pub async fn Haystack::is_explicit(self : Haystack) -> Bool {
  self.is_stdin() || (self.dent.depth() == 0 && !self.is_dir())
}

///|
async fn Haystack::is_dir(self : Haystack) -> Bool {
  guard self.dent.file_type() is Some(ft) else { return false }
  if ft is Dir {
    return true
  }
  self.dent.path_is_symlink() && is_dir_path(self.dent.path())
}

///|
fn Haystack::is_file(self : Haystack) -> Bool {
  self.dent.file_type() is Some(File)
}

///|
priv struct HaystackBuilder {
  strip_dot_prefix : Bool
}

///|
async fn HaystackBuilder::build_from_result(
  self : HaystackBuilder,
  result : Result[@ignore.DirEntry, @ignore.IgnoreError],
) -> Haystack? {
  match result {
    Ok(dent) => self.build(dent)
    Err(err) => {
      err_message(err.to_string())
      None
    }
  }
}

///|
async fn HaystackBuilder::build(
  self : HaystackBuilder,
  dent : @ignore.DirEntry,
) -> Haystack? {
  let hay = { dent, strip_dot_prefix: self.strip_dot_prefix, }
  if dent.error() is Some(err) {
    ignore_message(err.to_string())
  }
  if hay.is_explicit() {
    return Some(hay)
  }
  if hay.is_file() {
    return Some(hay)
  }
  if !hay.is_dir() {
    log_debug(
      "rg::haystack",
      "ignoring \{dent.path()}: failed to pass haystack filter",
    )
  }
  None
}

///|
fn HiArgs::haystack_builder(self : HiArgs) -> HaystackBuilder {
  { strip_dot_prefix: self.paths.has_implicit_path, }
}

///|
/// A reader over a `sys.File`.
priv struct FileReader {
  file : @sys.File
}

///|
impl @searcher.Reader for FileReader with fn read(self, buf, start, len) {
  self.file.read(buf, start, len)
}

///|
/// A reader over stdin.
priv struct StdinReader {}

///|
impl @searcher.Reader for StdinReader with fn read(_self, buf, start, len) {
  @sys.read_fd(0, buf, start, len)
}

///|
/// A reader over a command's output.
priv struct CommandOutputReader {
  rdr : @cli.CommandReader
}

///|
impl @searcher.Reader for CommandOutputReader with fn read(
  self,
  buf,
  start,
  len,
) {
  self.rdr.read(buf, start, len)
}

///|
/// The result of searching a single haystack.
priv struct SearchResult {
  has_match : Bool
  stats : @printer.Stats?
}

///|
/// Manages the interaction between the matcher, searcher and printer for a
/// single haystack, including user-specified preprocessors.
priv struct SearchWorker {
  preprocessor : String?
  preprocessor_globs : @ignore.Override
  binary_implicit : @searcher.BinaryDetection
  binary_explicit : @searcher.BinaryDetection
  matcher : @grep_regex.RegexMatcher
  searcher : @searcher.Searcher
  printer : Printer
  mmap : Bool
}

///|
fn HiArgs::search_worker(
  self : HiArgs,
  matcher : @grep_regex.RegexMatcher,
  searcher : @searcher.Searcher,
  printer : Printer,
) -> SearchWorker {
  {
    preprocessor: self.pre,
    preprocessor_globs: self.pre_globs,
    binary_implicit: self.binary.implicit,
    binary_explicit: self.binary.explicit,
    matcher,
    searcher,
    printer,
    mmap: self.mmap,
  }
}

///|
async fn SearchWorker::search(
  self : SearchWorker,
  haystack : Haystack,
) -> SearchResult {
  let bin = if haystack.is_explicit() {
    self.binary_explicit
  } else {
    self.binary_implicit
  }
  let path = haystack.path()
  self.searcher.set_binary_detection(bin)
  if haystack.is_stdin() {
    self.search_reader(path, StdinReader::{ })
  } else if self.should_preprocess(path) {
    self.search_preprocessor(path)
  } else {
    self.search_path(path)
  }
}

///|
fn SearchWorker::should_preprocess(self : SearchWorker, path : String) -> Bool {
  if self.preprocessor is None {
    return false
  }
  if self.preprocessor_globs.is_empty() {
    return true
  }
  !self.preprocessor_globs.matched(path, false).is_ignore()
}

///|
async fn SearchWorker::search_preprocessor(
  self : SearchWorker,
  path : String,
) -> SearchResult {
  let bin = self.preprocessor.unwrap()
  // Make sure the file can be opened (like Rust's File::open).
  let f = @sys.File::open(path)
  f.close()
  let cmd_desc = "\"\{bin}\" \"\{path}\""
  let rdr = @cli.CommandReader::new(bin, [path], stdin_path=path) catch {
    e =>
      raise RgError("preprocessor command could not start: '\{cmd_desc}': \{e}")
  }
  defer (rdr.close() catch { _ => () })
  let result = try
    self.search_reader(path, CommandOutputReader::{ rdr, })
  catch {
    e =>
      raise RgError(
        "preprocessor command failed: '\{cmd_desc}': \{error_message(e)}",
      )
  } noraise {
    r => r
  }
  rdr.close() catch {
    e => raise RgError(e.to_string())
  }
  result
}

///|
/// What a search reads from.
priv enum Input {
  Reader(&@searcher.Reader)
  /// A whole file (`buf[0:len]`), searched like ripgrep searches a memory map.
  Slice(FixedArray[Byte], Int32)
}

///|
async fn SearchWorker::search_path(
  self : SearchWorker,
  path : String,
) -> SearchResult {
  let file = @sys.File::open(path)
  defer file.close()
  // Where ripgrep would use a memory map (only possible for regular
  // files), search the whole file as a slice: this matters because slices
  // are searched differently (e.g. binary data isn't converted).
  // (Files too big for an array are read incrementally instead.)
  if self.mmap &&
    (@sys.metadata(path).is_file() catch { _ => false }) &&
    (@sys.file_len(path) catch { _ => -1L }) is (0L..<0x40000000L) {
    let (buf, len) = read_all(file, path)
    self.search_input(path, Slice(buf, len))
  } else {
    self.search_input(path, Reader(FileReader::{ file, }))
  }
}

///|
/// Reads all of `file` into a buffer, returning it and the number of bytes.
async fn read_all(file : @sys.File, path : String) -> (FixedArray[Byte], Int32) {
  let hint = @sys.file_len(path) catch { _ => 0L }
  let mut buf : FixedArray[Byte] = FixedArray::make(
    hint.to_int().max(0) + 1,
    b'\x00',
  )
  let mut len = 0
  while true {
    if len == buf.length() {
      let bigger = FixedArray::make(buf.length() * 2, b'\x00')
      buf.blit_to(bigger, len~)
      buf = bigger
    }
    let n = file.read(buf, len, buf.length() - len)
    if n == 0 {
      break
    }
    len += n
  }
  (buf, len)
}

///|
async fn SearchWorker::search_reader(
  self : SearchWorker,
  path : String,
  rdr : &@searcher.Reader,
) -> SearchResult {
  self.search_input(path, Reader(rdr))
}

///|
async fn SearchWorker::search_input(
  self : SearchWorker,
  path : String,
  input : Input,
) -> SearchResult {
  let run = (sink : &@searcher.Sink) => {
    match input {
      Reader(rdr) => self.searcher.search_reader(self.matcher, rdr, sink)
      Slice(buf, len) =>
        self.searcher.search_slice(self.matcher, buf, len, sink)
    }
  }
  match self.printer {
    Standard(p) => {
      let sink = p.sink_with_path(self.matcher, path)
      run(sink)
      { has_match: sink.has_match(), stats: sink.stats(), }
    }
    Summary(p) => {
      let sink = p.sink_with_path(self.matcher, path)
      run(sink)
      { has_match: sink.has_match(), stats: sink.stats(), }
    }
    JSON(p) => {
      let sink = p.sink_with_path(self.matcher, path)
      run(sink)
      { has_match: sink.has_match(), stats: Some(sink.stats()), }
    }
  }
}

///|
/// Renders any error raised while searching.
fn error_message(e : Error) -> String {
  match e {
    RgError(msg) => msg
    @sys.IOError(..) as e => e.to_string()
    @searcher.ConfigError(_) as e => e.to_string()
    @searcher.SearchIOError(_) as e => e.to_string()
    @cli.CommandIo(_) as e => e.to_string()
    @cli.CommandStderr(_) as e => e.to_string()
    @printer.PrinterError(msg) => msg
    _ => "\{e}"
  }
}
