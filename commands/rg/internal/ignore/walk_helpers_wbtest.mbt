///|
fn IgnoreError::is_partial(self : IgnoreError) -> Bool {
  match self {
    Partial(_) => true
    WithLineNumber(err~, ..) | WithPath(err~, ..) | WithDepth(err~, ..) =>
      err.is_partial()
    _ => false
  }
}

///|
fn IgnoreError::depth(self : IgnoreError) -> Int32? {
  match self {
    WithPath(err~, ..) => err.depth()
    WithDepth(depth~, ..) => Some(depth)
    _ => None
  }
}

///|
async fn Gitignore::new(gitignore_path : String) -> (Gitignore, IgnoreError?) {
  let parent = path_parent(gitignore_path).unwrap_or("/")
  let builder = GitignoreBuilder::new(parent)
  let errs = PartialErrorBuilder::new()
  errs.maybe_push_ignore_io(builder.add(gitignore_path))
  match (Ok(builder.build()) catch { e => Err(e) }) {
    Ok(gi) => (gi, errs.into_error_option())
    Err(err) => {
      errs.push(err)
      (Gitignore::empty(), errs.into_error_option())
    }
  }
}

///|
fn GitignoreBuilder::add_str(
  self : GitignoreBuilder,
  from : String?,
  gitignore : String,
) -> GitignoreBuilder raise IgnoreError {
  for line in str_lines(gitignore) {
    self.add_line(from, line) |> ignore
  }
  self
}

///|
fn DirEntry::file_name(self : DirEntry) -> String {
  match self.dent {
    Stdin => "<stdin>"
    Raw(x) => x.file_name()
  }
}

///|
fn WalkBuilder::standard_filters(self : WalkBuilder, yes : Bool) -> WalkBuilder {
  self
  .hidden(yes)
  .parents(yes)
  .ignore(yes)
  .git_ignore(yes)
  .git_global(yes)
  .git_exclude(yes)
}

///|
async fn Walk::iter(self : Walk) -> Array[Result[DirEntry, IgnoreError]] {
  self.collect()
}

///|
fn IgnoreError::io_error(self : IgnoreError) -> @sys.IOError? {
  match self {
    Partial(errs) => if errs.length() == 1 { errs[0].io_error() } else { None }
    WithLineNumber(err~, ..) | WithPath(err~, ..) | WithDepth(err~, ..) =>
      err.io_error()
    Io(err) => Some(err)
    Loop(..) | Glob(..) | UnrecognizedFileType(_) | InvalidDefinition => None
  }
}

///|
fn str_lines(s : String) -> Array[String] {
  let out = []
  let n = s.length()
  let mut start = 0
  for i in 0..<n {
    if s[i] == '\n' {
      let mut end = i
      if end > start && s[end - 1] == '\r' {
        end -= 1
      }
      out.push(s.unsafe_substring(start~, end~))
      start = i + 1
    }
  }
  if start < n {
    let mut end = n
    if s[end - 1] == '\r' {
      end -= 1
    }
    out.push(s.unsafe_substring(start~, end~))
  }
  out
}

///|
async fn Walk::collect(self : Walk) -> Array[Result[DirEntry, IgnoreError]] {
  let entries = []
  while self.next() is Some(entry) {
    entries.push(entry)
  }
  entries
}
