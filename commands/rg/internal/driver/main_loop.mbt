///|
fn is_broken_pipe(e : Error) -> Bool {
  match e {
    @sys.IOError(kind=BrokenPipe, ..) => true
    _ => false
  }
}

///|
async fn ExecutionPlan::walk_builder(
  self : ExecutionPlan,
) -> @ignore.WalkBuilder {
  let builder = @ignore.WalkBuilder::new(self.input.paths.paths[0])
  for i in 1..<self.input.paths.paths.length() {
    ignore(builder.add(self.input.paths.paths[i]))
  }
  if !self.input.no_ignore_files {
    for path in self.input.ignore_file {
      if builder.add_ignore(path) is Some(err) {
        ignore_message(err.to_string())
      }
    }
  }
  ignore(
    builder
    .max_depth(self.input.max_depth)
    .follow_links(self.input.follow)
    .max_filesize(self.input.max_filesize)
    .same_file_system(self.input.one_file_system)
    .skip_stdout(self.mode is Search(_))
    .overrides(self.input.globs)
    .types(self.input.types)
    .hidden(!self.input.hidden)
    .parents(!self.input.no_ignore_parent)
    .ignore(!self.input.no_ignore_dot)
    .git_global(!self.input.no_ignore_vcs && !self.input.no_ignore_global)
    .git_ignore(!self.input.no_ignore_vcs)
    .git_exclude(!self.input.no_ignore_vcs && !self.input.no_ignore_exclude)
    .require_git(!self.input.no_require_git)
    .ignore_case_insensitive(self.input.ignore_file_case_insensitive)
    .current_dir(self.input.cwd),
  )
  if !self.input.no_ignore_dot {
    ignore(builder.add_custom_ignore_filename(".rgignore"))
  }
  if self.input.sort is Some(sort) && !sort.reverse && sort.kind is Path {
    ignore(builder.sort_by_file_name(@ignore.compare_utf8))
  }
  builder
}

///|
priv enum Haystacks {
  Walking(@ignore.Walk, HaystackBuilder)
  Sorted(Iter[Haystack])
}

///|
async fn Haystacks::next(self : Haystacks) -> Haystack? {
  match self {
    Sorted(iter) => iter.next()
    Walking(walk, builder) => {
      while walk.next() is Some(result) {
        if builder.build_from_result(result) is Some(haystack) {
          return Some(haystack)
        }
      }
      None
    }
  }
}

///|
/// Sorting retains its original full-list path; ordinary traversal stays incremental.
async fn ExecutionPlan::haystacks(self : ExecutionPlan) -> Haystacks {
  let builder = self.haystack_builder()
  let walk = self.walk_builder().build()
  let unsorted = Walking(walk, builder)
  guard self.input.sort is Some(sort) else { return unsorted }
  match sort.kind {
    Path if !sort.reverse => unsorted
    Path => {
      let hs = []
      while unsorted.next() is Some(haystack) {
        hs.push(haystack)
      }
      hs.sort_by((a, b) => compare_paths(b.path(), a.path()))
      Sorted(hs.iter())
    }
    kind => {
      let with_times = []
      while unsorted.next() is Some(h) {
        let t = @sys.file_times(h.path()) catch {
          _ => { modified: None, accessed: None, created: None, }
        }
        let time = match kind {
          LastModified => t.modified
          LastAccessed => t.accessed
          Created => t.created
          Path => None
        }
        with_times.push((h, time))
      }
      with_times.sort_by((x, y) => {
        let ord = match (x.1, y.1) {
          (Some(t1), Some(t2)) => t1.compare(t2)
          (Some(_), None) => -1
          (None, Some(_)) => 1
          (None, None) => 0
        }
        if sort.reverse {
          -ord
        } else {
          ord
        }
      })
      Sorted(with_times.map(x => x.0).iter())
    }
  }
}

///|
/// Compares paths component-wise by bytes, like Rust's `Path::cmp`.
fn compare_paths(a : String, b : String) -> Int32 {
  let ca = path_components(a)
  let cb = path_components(b)
  let n = if ca.length() < cb.length() { ca.length() } else { cb.length() }
  for i in 0..<n {
    let c = compare_bytes_lex(@osstr.encode(ca[i]), @osstr.encode(cb[i]))
    if c != 0 {
      return c
    }
  }
  ca.length() - cb.length()
}

///|
fn path_components(p : String) -> Array[String] {
  let out = []
  let parts = p.split("/").map(s => s.to_owned()).collect()
  for i, part in parts {
    if part.is_empty() {
      if i == 0 {
        out.push("/")
      }
      continue
    }
    if part == "." && i > 0 {
      continue
    }
    out.push(part)
  }
  out
}

///|
fn compare_bytes_lex(a : Bytes, b : Bytes) -> Int32 {
  let n = if a.length() < b.length() { a.length() } else { b.length() }
  for i in 0..<n {
    if a[i] != b[i] {
      return a[i].to_int() - b[i].to_int()
    }
  }
  a.length() - b.length()
}

///|
async fn eprint_nothing_searched() -> Unit {
  err_message(
    "No files were searched, which means ripgrep probably applied a filter you didn't expect.\nRunning with --debug will show why files are being skipped.",
  )
}

///|
async fn run_search(args : ExecutionPlan, mode : SearchMode) -> Bool {
  let started_at = @sys.now_nanos()
  let haystacks = args.haystacks()
  let mut matched = false
  let mut searched = false
  let stats = args.new_stats()
  let stdout = args.stdout()
  let worker = args.search_worker(
    args.matcher(),
    args.searcher(),
    args.printer(mode, stdout),
  )
  while haystacks.next() is Some(haystack) {
    searched = true
    let result = try worker.search(haystack) catch {
      e => {
        if is_broken_pipe(e) {
          break
        }
        err_message("\{haystack.path()}: \{error_message(e)}")
        continue
      }
    } noraise {
      r => r
    }
    matched = matched || result.has_match
    if stats is Some(s) && result.stats is Some(rs) {
      s.add_stats(rs)
    }
    if matched && args.output.quit_after_match {
      break
    }
  }
  if args.input.paths.has_implicit_path && !searched {
    eprint_nothing_searched()
  }
  if stats is Some(s) {
    let wtr = worker.printer.get_mut()
    print_stats(mode, s, started_at, wtr) catch {
      _ => ()
    }
  }
  @termcolor.Write::flush(worker.printer.get_mut()) catch {
    e => if !is_broken_pipe(e) { raise e }
  }
  matched
}

///|
async fn run_files(args : ExecutionPlan) -> Bool {
  let haystacks = args.haystacks()
  let mut matched = false
  let stdout = args.stdout()
  let path_printer = args.path_printer(stdout)
  while haystacks.next() is Some(haystack) {
    matched = true
    if args.output.quit_after_match {
      break
    }
    path_printer.write(haystack.path()) catch {
      e if is_broken_pipe(e) => break
      e => raise e
    }
  }
  @termcolor.Write::flush(stdout) catch {
    e => if !is_broken_pipe(e) { raise e }
  }
  matched
}

///|
async fn run_types(args : ExecutionPlan) -> Int32 {
  let mut count = 0
  let out = StdoutWriter::new(false)
  for def in args.input.types.definitions() {
    count += 1
    let line = StringBuilder()
    line.write_string(def.name())
    line.write_string(": ")
    line.write_string(def.globs().join(", "))
    line.write_string("\n")
    let bytes = @utf8.encode(line.to_string())
    @termcolor.Write::write_bytes(out, bytes[:])
  }
  @termcolor.Write::flush(out)
  if count == 0 {
    1
  } else {
    0
  }
}

///|
async fn print_stats(
  mode : SearchMode,
  stats : @printer.Stats,
  started : Int64,
  wtr : &@termcolor.WriteColor,
) -> Unit {
  let elapsed = @sys.now_nanos() - started
  let text = if mode is JSON {
    let buf = @termcolor.ByteVec::new()
    let w = @printer.JsonWriter::new(buf)
    // serde_json's `json!` uses a sorted map, so keys are sorted.
    w.begin_object()
    w.key("data")
    w.begin_object()
    w.key("elapsed_total")
    @printer.write_duration_json(w, elapsed, sorted_keys=true)
    w.key("stats")
    stats.write_json(w, sorted_keys=true)
    w.end_object()
    w.key("type")
    w.write_escaped_string("summary")
    w.end_object()
    @utf8.decode_lossy(buf.to_bytes()) + "\n"
  } else {
    let f = (ns : Int64) => {
      @printer.format_fixed(@printer.duration_as_secs_f64(ns), 6)
    }
    "\n\{stats.matches()} matches\n\{stats.matched_lines()} matched lines\n\{stats.searches_with_match()} files contained matches\n\{stats.searches()} files searched\n\{stats.bytes_printed()} bytes printed\n\{stats.bytes_searched()} bytes searched\n\{f(stats.elapsed())} seconds spent searching\n\{f(elapsed)} seconds total\n"
  }
  let bytes = @utf8.encode(text)
  @termcolor.Write::write_bytes(wtr, bytes[:])
}
