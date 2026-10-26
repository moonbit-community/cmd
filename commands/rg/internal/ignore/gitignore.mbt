// Port of `ignore/src/gitignore.rs`.
//
// The gitignore module provides a way to match globs from a gitignore file
// against file paths.
//
// Note that this module implements the specification as described in the
// `gitignore` man page from scratch. That is, this module does *not* shell
// out to the `git` command line tool.

///|
/// A single glob in a gitignore file (Rust's `ignore::gitignore::Glob`).
///
/// This is used to report information about the highest precedent glob that
/// matched in one or more gitignore files.
pub struct GitignoreGlob {
  priv from : String?
  priv original : String
  priv mut actual : String
  priv mut is_whitelist : Bool
  priv mut is_only_dir : Bool
} derive(Debug, Eq)

///|
/// Returns the file path that defined this glob.
pub fn GitignoreGlob::from(self : GitignoreGlob) -> String? {
  self.from
}

///|
/// The original glob as it was defined in a gitignore file.
pub fn GitignoreGlob::original(self : GitignoreGlob) -> String {
  self.original
}

///|
/// The actual glob that was compiled to respect gitignore semantics.
pub fn GitignoreGlob::actual(self : GitignoreGlob) -> String {
  self.actual
}

///|
/// Whether this was a whitelisted glob or not.
pub fn GitignoreGlob::is_whitelist(self : GitignoreGlob) -> Bool {
  self.is_whitelist
}

///|
/// Whether this glob must match a directory or not.
pub fn GitignoreGlob::is_only_dir(self : GitignoreGlob) -> Bool {
  self.is_only_dir
}

///|
/// Returns true if and only if this glob has a `**/` prefix.
fn GitignoreGlob::has_doublestar_prefix(self : GitignoreGlob) -> Bool {
  self.actual.has_prefix("**/") || self.actual == "**"
}

///|
/// Gitignore is a matcher for the globs in one or more gitignore files
/// in the same directory.
pub struct Gitignore {
  priv set : @globset.GlobSet
  priv root : String
  priv globs : Array[GitignoreGlob]
  priv num_ignores : Int32
  priv num_whitelists : Int32
  /// Scratch space for glob set matches.
  priv matches : Array[Int32]
}

///|
pub impl Debug for Gitignore with fn to_repr(self) {
  @debug.Repr::record({
    "root": Debug::to_repr(self.root),
    "globs": Debug::to_repr(self.globs),
    "num_ignores": Debug::to_repr(self.num_ignores),
    "num_whitelists": Debug::to_repr(self.num_whitelists),
  })
}

///|
/// Creates a new gitignore matcher from the gitignore file path given.
///
/// If it's desirable to include multiple gitignore files in a single
/// matcher, or read gitignore globs from a different source, then
/// use `GitignoreBuilder`.
///
/// This always returns a valid matcher, even if it's empty. In particular,
/// a Gitignore file can be partially valid, e.g., when one glob is invalid
/// but the rest aren't.
///
/// Note that I/O errors are ignored. For more granular control over
/// errors, use `GitignoreBuilder`.
pub async fn Gitignore::new(
  gitignore_path : String,
) -> (Gitignore, IgnoreError?) {
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
/// Creates a new gitignore matcher from the global ignore file, if one
/// exists.
///
/// The global config file path is specified by git's `core.excludesFile`
/// config option.
///
/// Git's config file location is `$HOME/.gitconfig`. If `$HOME/.gitconfig`
/// does not exist or does not specify `core.excludesFile`, then
/// `$XDG_CONFIG_HOME/git/ignore` is read. If `$XDG_CONFIG_HOME` is not
/// set or is empty, then `$HOME/.config/git/ignore` is used instead.
pub async fn Gitignore::global() -> (Gitignore, IgnoreError?) {
  match @sys.current_dir() {
    Some(cwd) => GitignoreBuilder::new(cwd).build_global()
    None => (Gitignore::empty(), Some(Io(@sys.IOError::from_errno(2))))
  }
}

///|
/// Creates a new empty gitignore matcher that never matches anything.
///
/// Its path is empty.
pub fn Gitignore::empty() -> Gitignore {
  {
    set: @globset.GlobSet::empty(),
    root: "",
    globs: [],
    num_ignores: 0,
    num_whitelists: 0,
    matches: [],
  }
}

///|
/// Returns the directory containing this gitignore matcher.
///
/// All matches are done relative to this path.
pub fn Gitignore::path(self : Gitignore) -> String {
  self.root
}

///|
/// Returns true if and only if this gitignore has zero globs, and
/// therefore never matches any file path.
pub fn Gitignore::is_empty(self : Gitignore) -> Bool {
  self.set.is_empty()
}

///|
/// Returns the total number of globs, which should be equivalent to
/// `num_ignores + num_whitelists`.
pub fn Gitignore::len(self : Gitignore) -> Int32 {
  self.set.len()
}

///|
/// Returns the total number of ignore globs.
pub fn Gitignore::num_ignores(self : Gitignore) -> Int32 {
  self.num_ignores
}

///|
/// Returns the total number of whitelisted globs.
pub fn Gitignore::num_whitelists(self : Gitignore) -> Int32 {
  self.num_whitelists
}

///|
/// Returns whether the given path (file or directory) matched a pattern in
/// this gitignore matcher.
///
/// `is_dir` should be true if the path refers to a directory and false
/// otherwise.
///
/// The given path is matched relative to the path given when building
/// the matcher. Specifically, before matching `path`, its prefix (as
/// determined by a common suffix of the directory containing this
/// gitignore) is stripped. If there is no common suffix/prefix overlap,
/// then `path` is assumed to be relative to this matcher.
pub fn Gitignore::matched(
  self : Gitignore,
  path : String,
  is_dir : Bool,
) -> Match[GitignoreGlob] {
  if self.is_empty() {
    return None
  }
  self.matched_stripped(self.strip(path), is_dir)
}

///|
/// Returns whether the given path (file or directory, and expected to be
/// under the root) or any of its parent directories (up to the root)
/// matched a pattern in this gitignore matcher.
///
/// NOTE: This method is more expensive than walking the directory hierarchy
/// top-to-bottom and matching the entries. But, is easier to use in cases
/// when a list of paths are available without a hierarchy.
///
/// # Panics
///
/// This method panics if the given file path is not under the root path
/// of this matcher.
pub fn Gitignore::matched_path_or_any_parents(
  self : Gitignore,
  path : String,
  is_dir : Bool,
) -> Match[GitignoreGlob] {
  if self.is_empty() {
    return None
  }
  let mut path = self.strip(path)
  if path_has_root(path) {
    abort("path is expected to be under the root")
  }
  match self.matched_stripped(path, is_dir) {
    None => () // walk up
    a_match => return a_match
  }
  while path_parent(path) is Some(parent) {
    match self.matched_stripped(parent, true) {
      None => path = parent // walk up
      a_match => return a_match
    }
  }
  None
}

///|
/// Like matched, but takes a path that has already been stripped.
fn Gitignore::matched_stripped(
  self : Gitignore,
  path : String,
  is_dir : Bool,
) -> Match[GitignoreGlob] {
  if self.is_empty() {
    return None
  }
  let matches = self.matches
  self.set.matches_candidate_into(@globset.Candidate::new(path), matches)
  for i = matches.length() - 1; i >= 0; i = i - 1 {
    let glob = self.globs[matches[i]]
    if !glob.is_only_dir || is_dir {
      return if glob.is_whitelist { Whitelist(glob) } else { Ignore(glob) }
    }
  }
  None
}

///|
/// Strips the given path such that it's suitable for matching with this
/// gitignore matcher.
fn Gitignore::strip(self : Gitignore, path : String) -> String {
  let mut path = path
  // A leading ./ is completely superfluous. We also strip it from
  // our gitignore root path, so we need to strip it from our candidate
  // path too.
  if strip_prefix("./", path) is Some(p) {
    path = p
  }
  // Strip any common prefix between the candidate path and the root
  // of the gitignore, to make sure we get relative matching right.
  // BUT, a file name might not have any directory components to it,
  // in which case, we don't want to accidentally strip any part of the
  // file name.
  //
  // As an additional special case, if the root is just `.`, then we
  // shouldn't try to strip anything, e.g., when path begins with a `.`.
  if !path_eq(self.root, ".") && !is_file_name(path) {
    if strip_prefix(self.root, path) is Some(p) {
      path = p
      // If we're left with a leading slash, get rid of it.
      if strip_prefix("/", path) is Some(p) {
        path = p
      }
    }
  }
  path
}

///|
/// Compares two paths component-wise, like Rust's `Path` equality.
fn path_eq(a : String, b : String) -> Bool {
  let ac = path_components(a)
  let bc = path_components(b)
  if ac.length() != bc.length() {
    return false
  }
  for i in 0..<ac.length() {
    if ac[i].0 != bc[i].0 {
      return false
    }
  }
  true
}

///|
/// Builds a matcher for a single set of globs from a .gitignore file.
pub struct GitignoreBuilder {
  priv builder : @globset.GlobSetBuilder
  priv root : String
  priv globs : Array[GitignoreGlob]
  priv mut case_insensitive : Bool
  priv mut allow_unclosed_class : Bool
}

///|
/// Create a new builder for a gitignore file.
///
/// The path given should be the path at which the globs for this gitignore
/// file should be matched. Note that paths are always matched relative
/// to the root path given here. Generally, the root path should correspond
/// to the *directory* containing a `.gitignore` file.
pub fn GitignoreBuilder::new(root : String) -> GitignoreBuilder {
  {
    builder: @globset.GlobSetBuilder::new(),
    root: strip_prefix("./", root).unwrap_or(root),
    globs: [],
    case_insensitive: false,
    allow_unclosed_class: true,
  }
}

///|
/// Builds a new matcher from the globs added so far.
///
/// Once a matcher is built, no new globs can be added to it.
pub fn GitignoreBuilder::build(
  self : GitignoreBuilder,
) -> Gitignore raise IgnoreError {
  let mut nignore = 0
  let mut nwhite = 0
  for g in self.globs {
    if g.is_whitelist {
      nwhite += 1
    } else {
      nignore += 1
    }
  }
  let set = self.builder.build() catch {
    err => raise Glob(glob=None, err=err.to_string())
  }
  {
    set,
    root: self.root,
    globs: self.globs.copy(),
    num_ignores: nignore,
    num_whitelists: nwhite,
    matches: [],
  }
}

///|
/// Build a global gitignore matcher using the configuration in this
/// builder.
///
/// Note that this ignores the path given to this builder's constructor
/// and instead derives the path automatically from git's global
/// configuration.
pub async fn GitignoreBuilder::build_global(
  self : GitignoreBuilder,
) -> (Gitignore, IgnoreError?) {
  match gitconfig_excludes_path() {
    None => (Gitignore::empty(), None)
    Some(path) =>
      if !is_file(path) {
        (Gitignore::empty(), None)
      } else {
        let errs = PartialErrorBuilder::new()
        errs.maybe_push_ignore_io(self.add(path))
        match (Ok(self.build()) catch { e => Err(e) }) {
          Ok(gi) => (gi, errs.into_error_option())
          Err(err) => {
            errs.push(err)
            (Gitignore::empty(), errs.into_error_option())
          }
        }
      }
  }
}

///|
/// Add each glob from the file path given.
///
/// The file given should be formatted as a `gitignore` file.
///
/// Note that partial errors can be returned. For example, if there was
/// a problem adding one glob, an error for that will be returned, but
/// all other valid globs will still be added.
pub async fn GitignoreBuilder::add(
  self : GitignoreBuilder,
  path : String,
) -> IgnoreError? {
  let data = @sys.read_file(path) catch {
    err =>
      // Opening a directory succeeds in Rust; the failure surfaces when
      // reading the first line.
      return if @sys.from_error(err).kind() is IsADirectory {
        Some(IgnoreError::Io(@sys.from_error(err)).tagged(path, 1))
      } else {
        Some(IgnoreError::Io(@sys.from_error(err)).with_path(path))
      }
  }
  let errs = PartialErrorBuilder::new()
  let lines = split_lines_bytes(data)
  for i, raw in lines {
    let lineno = i + 1
    let line = @utf8.decode(raw) catch {
      _ => {
        errs.push(
          IgnoreError::Io(
            @sys.IOError::other(Other, "stream did not contain valid UTF-8"),
          ).tagged(path, lineno),
        )
        break
      }
    }
    // Match Git's handling of .gitignore files that begin with the Unicode
    // BOM.
    let line = if i == 0 { trim_start_bom(line) } else { line }
    (self.add_line(Some(path), line) |> ignore) catch {
      err => errs.push(err.tagged(path, lineno))
    }
  }
  errs.into_error_option()
}

///|
/// Splits bytes into lines like Rust's `BufRead::lines`: lines are
/// terminated by `\n` (with an optional preceding `\r` removed) and a
/// trailing line without a terminator is included if non-empty.
fn split_lines_bytes(data : Bytes) -> Array[BytesView] {
  let out = []
  let n = data.length()
  let mut start = 0
  for i in 0..<n {
    if data[i] == b'\n' {
      let mut end = i
      if end > start && data[end - 1] == b'\r' {
        end -= 1
      }
      out.push(data[start:end])
      start = i + 1
    }
  }
  if start < n {
    let mut end = n
    if data[end - 1] == b'\r' {
      end -= 1
    }
    out.push(data[start:end])
  }
  out
}

///|
fn trim_start_bom(line : String) -> String {
  let mut i = 0
  while i < line.length() && line[i] == 0xFEFF {
    i += 1
  }
  if i == 0 {
    line
  } else {
    line.unsafe_substring(start=i, end=line.length())
  }
}

///|
/// Splits a string into lines like Rust's `str::lines`.
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
/// Add each glob line from the string given.
///
/// If this string came from a particular `gitignore` file, then its path
/// should be provided here.
///
/// The string given should be formatted as a `gitignore` file.
pub fn GitignoreBuilder::add_str(
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
/// Add a line from a gitignore file to this builder.
///
/// If this line came from a particular `gitignore` file, then its path
/// should be provided here.
///
/// If the line could not be parsed as a glob, then an error is returned.
pub fn GitignoreBuilder::add_line(
  self : GitignoreBuilder,
  from : String?,
  line : String,
) -> GitignoreBuilder raise IgnoreError {
  if line.has_prefix("#") {
    return self
  }
  let mut line = line
  if !line.has_suffix("\\ ") {
    line = trim_end_whitespace(line)
  }
  if line == "" {
    return self
  }
  let glob = {
    from,
    original: line,
    actual: "",
    is_whitelist: false,
    is_only_dir: false,
  }
  let mut is_absolute = false
  if line.has_prefix("\\!") || line.has_prefix("\\#") {
    line = line.unsafe_substring(start=1, end=line.length())
    is_absolute = line.has_prefix("/")
  } else {
    if line.has_prefix("!") {
      glob.is_whitelist = true
      line = line.unsafe_substring(start=1, end=line.length())
    }
    if line.has_prefix("/") {
      // `man gitignore` says that if a glob starts with a slash,
      // then the glob can only match the beginning of a path
      // (relative to the location of gitignore). We achieve this by
      // simply banning wildcards from matching /.
      line = line.unsafe_substring(start=1, end=line.length())
      is_absolute = true
    }
  }
  // If it ends with a slash, then this should only match directories,
  // but the slash should otherwise not be used while globbing.
  if line.has_suffix("/") {
    glob.is_only_dir = true
    line = line.unsafe_substring(start=0, end=line.length() - 1)
    // If the slash was escaped, then remove the escape.
    // See: https://github.com/BurntSushi/ripgrep/issues/2236
    if line.has_suffix("\\") {
      line = line.unsafe_substring(start=0, end=line.length() - 1)
    }
  }
  glob.actual = line
  // If there is a literal slash, then this is a glob that must match the
  // entire path name. Otherwise, we should let it match anywhere, so use
  // a **/ prefix.
  if !is_absolute && !line.contains("/") {
    // ... but only if we don't already have a **/ prefix.
    if !glob.has_doublestar_prefix() {
      glob.actual = "**/" + glob.actual
    }
  }
  // If the glob ends with `/**`, then we should only match everything
  // inside a directory, but not the directory itself. Standard globs
  // will match the directory. So we add `/*` to force the issue.
  if glob.actual.has_suffix("/**") {
    glob.actual = glob.actual + "/*"
  }
  let parsed = @globset.GlobBuilder::new(glob.actual)
    .literal_separator(true)
    .case_insensitive(self.case_insensitive)
    .backslash_escape(true)
    .allow_unclosed_class(self.allow_unclosed_class)
    .build() catch {
      err => raise Glob(glob=Some(glob.original), err=err.kind().to_string())
    }
  self.builder.add(parsed) |> ignore
  self.globs.push(glob)
  self
}

///|
/// Toggle whether the globs should be matched case insensitively or not.
///
/// When this option is changed, only globs added after the change will be
/// affected.
///
/// This is disabled by default.
pub fn GitignoreBuilder::case_insensitive(
  self : GitignoreBuilder,
  yes : Bool,
) -> GitignoreBuilder {
  self.case_insensitive = yes
  self
}

///|
/// Toggle whether unclosed character classes are allowed. When allowed,
/// a `[` without a matching `]` is treated literally instead of resulting
/// in a parse error.
///
/// For example, if this is set then the glob `[abc` will be treated as the
/// literal string `[abc` instead of returning an error.
///
/// By default, this is true in order to match established `gitignore`
/// semantics.
pub fn GitignoreBuilder::allow_unclosed_class(
  self : GitignoreBuilder,
  yes : Bool,
) -> GitignoreBuilder {
  self.allow_unclosed_class = yes
  self
}

///|
/// Trims trailing Unicode `White_Space` characters (like Rust's
/// `str::trim_end`).
fn trim_end_whitespace(s : String) -> String {
  let mut end = s.length()
  while end > 0 && is_unicode_whitespace(s[end - 1].to_int()) {
    end -= 1
  }
  if end == s.length() {
    s
  } else {
    s.unsafe_substring(start=0, end~)
  }
}

///|
fn is_unicode_whitespace(c : Int32) -> Bool {
  match c {
    0x09..<=0x0D | 0x20 | 0x85 | 0xA0 | 0x1680 => true
    0x2000..<=0x200A | 0x2028 | 0x2029 | 0x202F | 0x205F | 0x3000 => true
    _ => false
  }
}

///|
/// Returns true if `path` exists and is a regular file (following
/// symlinks).
async fn is_file(path : String) -> Bool {
  (Ok(@sys.metadata(path)) catch { e => Err(e) }) is Ok(md) &&
  md.file_type is File
}

///|
/// Returns true if `path` exists and is a directory (following symlinks).
async fn is_dir(path : String) -> Bool {
  (Ok(@sys.metadata(path)) catch { e => Err(e) }) is Ok(md) &&
  md.file_type is Dir
}
