// Port of `ignore/src/dir.rs`.
//
// This module provides a data structure, `Ignore`, that connects "directory
// traversal" with "ignore matchers." Specifically, it knows about gitignore
// semantics and precedence, and is organized based on directory hierarchy.
// Namely, every matcher logically corresponds to ignore rules from a single
// directory, and points to the matcher for its corresponding parent
// directory. In this sense, `Ignore` is a *persistent* data structure.

///|
/// IgnoreMatch represents information about where a match came from when
/// using the `Ignore` matcher.
#warnings("-unused_constructor")
priv enum IgnoreMatch {
  Override(OverrideGlob)
  Gitignore(GitignoreGlob)
  Types(TypesGlob)
  Hidden
}

///|
/// Options for the ignore matcher, shared between the matcher itself and the
/// builder.
priv struct IgnoreOptions {
  /// Whether to ignore hidden file paths or not.
  mut hidden : Bool
  /// Whether to read .ignore files.
  mut ignore : Bool
  /// Whether to respect any ignore files in parent directories.
  mut parents : Bool
  /// Whether to read git's global gitignore file.
  mut git_global : Bool
  /// Whether to read .gitignore files.
  mut git_ignore : Bool
  /// Whether to read .git/info/exclude files.
  mut git_exclude : Bool
  /// Whether to ignore files case insensitively
  mut ignore_case_insensitive : Bool
  /// Whether a git repository must be present in order to apply any
  /// git-related ignore rules.
  mut require_git : Bool
}

///|
fn IgnoreOptions::copy(self : IgnoreOptions) -> IgnoreOptions {
  { ..self, }
}

///|
/// Ignore is a matcher useful for recursively walking one or more
/// directories.
priv struct Ignore {
  inner : IgnoreInner
  // Parent matchers are cached independently of the path being walked, but
  // matching them still needs the canonicalized path originally passed to
  // `add_parents`.
  absolute_base : String?
}

///|
priv struct IgnoreInner {
  /// A map of all existing directories that have already been
  /// compiled into matchers.
  ///
  /// Note that this is never used during matching, only when adding new
  /// parent directory matchers. This avoids needing to rebuild glob sets for
  /// parent directories if many paths are being searched.
  compiled : Map[String, IgnoreInner]
  /// The path to the directory that this matcher was built from.
  dir : String
  /// An override matcher (default is empty).
  overrides : Override
  /// A file type matcher.
  types : Types
  /// The parent directory to match next.
  ///
  /// If this is the root directory or there are otherwise no more
  /// directories to match, then `parent` is `None`.
  parent : IgnoreInner?
  /// Whether this is an absolute parent matcher, as added by add_parent.
  mut is_absolute_parent : Bool
  /// The directory that gitignores should be interpreted relative to.
  global_gitignores_relative_to : String?
  /// Explicit global ignore matchers specified by the caller.
  explicit_ignores : Array[Gitignore]
  /// Ignore files used in addition to `.ignore`
  custom_ignore_filenames : Array[String]
  /// The matcher for custom ignore files
  custom_ignore_matcher : Gitignore
  /// The matcher for .ignore files.
  ignore_matcher : Gitignore
  /// A global gitignore matcher, usually from $XDG_CONFIG_HOME/git/ignore.
  git_global_matcher : Gitignore
  /// The matcher for .gitignore files.
  git_ignore_matcher : Gitignore
  /// Special matcher for `.git/info/exclude` files.
  git_exclude_matcher : Gitignore
  /// Whether this directory contains a .git sub-directory.
  mut has_git : Bool
  /// Ignore config.
  opts : IgnoreOptions
}

///|
/// Return the directory path of this matcher. (Only used by tests.)
#warnings("-unused_value")
fn Ignore::path(self : Ignore) -> String {
  self.inner.dir
}

///|
/// Return true if this matcher has no parent.
fn Ignore::is_root(self : Ignore) -> Bool {
  self.inner.parent is None
}

///|
/// Return this matcher's parent, if one exists.
fn Ignore::parent(self : Ignore) -> Ignore? {
  self.inner.parent.map(parent => {
    inner: parent,
    absolute_base: self.absolute_base,
  })
}

///|
/// Create a new `Ignore` matcher with the parent directories of `dir`.
///
/// Note that this can only be called on an `Ignore` matcher with no
/// parents (i.e., `is_root` returns `true`). This will panic otherwise.
async fn Ignore::add_parents(
  self : Ignore,
  path : String,
) -> (Ignore, IgnoreError?) {
  if !self.inner.opts.parents &&
    !self.inner.opts.git_ignore &&
    !self.inner.opts.git_exclude &&
    !self.inner.opts.git_global {
    // If we never need info from parent directories, then don't do
    // anything.
    return (self, None)
  }
  if !self.is_root() {
    abort("Ignore::add_parents called on non-root matcher")
  }
  let absolute_base = canonicalize(path) catch {
    // There's not much we can do here, so just return our existing
    // matcher. We drop the error to be consistent with our general
    // pattern of ignoring I/O errors when processing ignore files.
    _ => return (self, None)
  }
  // List of parents, from child to root.
  let parents = []
  let mut path = absolute_base
  while path_parent(path) is Some(parent) {
    parents.push(parent)
    path = parent
  }
  let errs = PartialErrorBuilder::new()
  let mut ig = self
  let compiled = self.inner.compiled
  for i = parents.length() - 1; i >= 0; i = i - 1 {
    let parent = parents[i]
    if compiled.get(parent) is Some(prebuilt) {
      ig = { inner: prebuilt, absolute_base: Some(absolute_base), }
      continue
    }
    let (igtmp, err) = ig.add_child_path(parent)
    errs.maybe_push(err)
    igtmp.is_absolute_parent = true
    igtmp.has_git = if self.inner.opts.require_git && self.inner.opts.git_ignore {
      path_exists(path_join(parent, ".git")) ||
      path_exists(path_join(parent, ".jj"))
    } else {
      false
    }
    ig = { inner: igtmp, absolute_base: Some(absolute_base), }
    compiled[parent] = igtmp
  }
  (ig, errs.into_error_option())
}

///|
/// Create a new `Ignore` matcher for the given child directory.
///
/// Since building the matcher may require reading from multiple
/// files, it's possible that this method partially succeeds. Therefore,
/// a matcher is always returned (which may match nothing) and an error is
/// returned if it exists.
///
/// Note that all I/O errors are completely ignored.
async fn Ignore::add_child(
  self : Ignore,
  dir : String,
) -> (Ignore, IgnoreError?) {
  let (ig, err) = self.add_child_path(dir)
  ({ inner: ig, absolute_base: self.absolute_base, }, err)
}

///|
/// Like add_child, but uses successful read_dir entries to reduce
/// probing when discovering ignore files.
async fn Ignore::add_child_with_entries(
  self : Ignore,
  dir : String,
  entries : ArrayView[@sys.DirEntry],
) -> (Ignore, IgnoreError?) {
  let files = self.collect_ignore_files(entries)
  let (ig, err) = self.add_child_path_with_found_ignore_files(dir, Some(files))
  ({ inner: ig, absolute_base: self.absolute_base, }, err)
}

///|
/// Like add_child, but takes a full path and returns an IgnoreInner.
async fn Ignore::add_child_path(
  self : Ignore,
  dir : String,
) -> (IgnoreInner, IgnoreError?) {
  self.add_child_path_with_found_ignore_files(dir, None)
}

///|
/// State for tracking what kinds of files are present in a directory.
priv struct IgnoreFilesFound {
  mut has_ignore : Bool
  mut has_git_ignore : Bool
  mut has_git_dir : Bool
  mut has_jj_dir : Bool
  custom_ignore_files : Array[Bool]
}

///|
fn Ignore::collect_ignore_files(
  self : Ignore,
  entries : ArrayView[@sys.DirEntry],
) -> IgnoreFilesFound {
  let custom_ignore_filenames = self.inner.custom_ignore_filenames
  let files = {
    has_ignore: false,
    has_git_ignore: false,
    has_git_dir: false,
    has_jj_dir: false,
    custom_ignore_files: Array::make(custom_ignore_filenames.length(), false),
  }
  for entry in entries {
    let file_name = entry.name
    if file_name == ".ignore" {
      files.has_ignore = true
    } else if file_name == ".gitignore" {
      files.has_git_ignore = true
    } else if file_name == ".git" {
      files.has_git_dir = true
    } else if file_name == ".jj" {
      files.has_jj_dir = true
    }
    for i, name in custom_ignore_filenames {
      if file_name == name {
        files.custom_ignore_files[i] = true
      }
    }
  }
  files
}

///|
async fn Ignore::add_child_path_with_found_ignore_files(
  self : Ignore,
  dir : String,
  ignore_files_list : IgnoreFilesFound?,
) -> (IgnoreInner, IgnoreError?) {
  let opts = self.inner.opts
  let check_vcs_dir = opts.require_git && (opts.git_ignore || opts.git_exclude)
  let git_type = if check_vcs_dir &&
    is_none_or(ignore_files_list, i => i.has_git_dir) {
    (Ok(@sys.metadata(path_join(dir, ".git"))) catch { e => Err(e) })
    .to_option()
    .map(md => md.file_type)
  } else {
    None
  }
  let has_jj = check_vcs_dir &&
    is_none_or(ignore_files_list, i => i.has_jj_dir) &&
    path_exists(path_join(dir, ".jj"))
  let has_git = check_vcs_dir && (git_type is Some(_) || has_jj)
  let errs = PartialErrorBuilder::new()
  let custom_ig_matcher = if self.inner.custom_ignore_filenames.is_empty() {
    Gitignore::empty()
  } else {
    let custom_ignore_names = match ignore_files_list {
      None => self.inner.custom_ignore_filenames.copy()
      Some(m) => {
        let names = []
        for i, name in self.inner.custom_ignore_filenames {
          if m.custom_ignore_files[i] {
            names.push(name)
          }
        }
        names
      }
    }
    if custom_ignore_names.is_empty() {
      Gitignore::empty()
    } else {
      let (m, err) = create_gitignore(
        dir,
        dir,
        custom_ignore_names,
        opts.ignore_case_insensitive,
      )
      errs.maybe_push(err)
      m
    }
  }
  let ig_matcher = if !opts.ignore ||
    !is_none_or(ignore_files_list, i => i.has_ignore) {
    Gitignore::empty()
  } else {
    let (m, err) = create_gitignore(
      dir,
      dir,
      [".ignore"],
      opts.ignore_case_insensitive,
    )
    errs.maybe_push(err)
    m
  }
  let gi_matcher = if !opts.git_ignore ||
    !is_none_or(ignore_files_list, i => i.has_git_ignore) {
    Gitignore::empty()
  } else {
    let (m, err) = create_gitignore(
      dir,
      dir,
      [".gitignore"],
      opts.ignore_case_insensitive,
    )
    errs.maybe_push(err)
    m
  }
  let gi_exclude_matcher = if !opts.git_exclude ||
    !is_none_or(ignore_files_list, i => i.has_git_dir) {
    Gitignore::empty()
  } else {
    match resolve_git_commondir(dir, git_type) {
      Ok(git_dir) => {
        let (m, err) = create_gitignore(
          dir,
          git_dir,
          ["info/exclude"],
          opts.ignore_case_insensitive,
        )
        errs.maybe_push(err)
        m
      }
      Err(err) => {
        errs.maybe_push(err)
        Gitignore::empty()
      }
    }
  }
  let ig = {
    compiled: self.inner.compiled,
    dir,
    overrides: self.inner.overrides,
    types: self.inner.types,
    parent: Some(self.inner),
    is_absolute_parent: false,
    global_gitignores_relative_to: self.inner.global_gitignores_relative_to,
    explicit_ignores: self.inner.explicit_ignores,
    custom_ignore_filenames: self.inner.custom_ignore_filenames,
    custom_ignore_matcher: custom_ig_matcher,
    ignore_matcher: ig_matcher,
    git_global_matcher: self.inner.git_global_matcher,
    git_ignore_matcher: gi_matcher,
    git_exclude_matcher: gi_exclude_matcher,
    has_git,
    opts,
  }
  (ig, errs.into_error_option())
}

///|
fn[T] is_none_or(x : T?, f : (T) -> Bool) -> Bool {
  match x {
    None => true
    Some(v) => f(v)
  }
}

///|
/// Returns true if at least one type of ignore rule should be matched.
fn Ignore::has_any_ignore_rules(self : Ignore) -> Bool {
  let opts = self.inner.opts
  let has_custom_ignore_files = !self.inner.custom_ignore_filenames.is_empty()
  let has_explicit_ignores = !self.inner.explicit_ignores.is_empty()
  opts.ignore ||
  opts.git_global ||
  opts.git_ignore ||
  opts.git_exclude ||
  has_custom_ignore_files ||
  has_explicit_ignores
}

///|
/// Like `matched`, but works with a directory entry instead.
fn Ignore::matched_dir_entry(
  self : Ignore,
  dent : DirEntry,
) -> Match[IgnoreMatch] {
  let m = self.matched(dent.path(), dent.is_dir())
  if m.is_none() && self.inner.opts.hidden && is_hidden_entry(dent) {
    return Ignore(Hidden)
  }
  m
}

///|
/// Returns a match indicating whether the given file path should be
/// ignored or not.
///
/// The match contains information about its origin.
fn Ignore::matched(
  self : Ignore,
  path : String,
  is_dir : Bool,
) -> Match[IgnoreMatch] {
  // We need to be careful with our path. If it has a leading ./, then
  // strip it because it causes nothing but trouble.
  let mut path = path
  if strip_prefix("./", path) is Some(p) {
    path = p
  }
  // Match against the override patterns. If an override matches
  // regardless of whether it's whitelist/ignore, then we quit and
  // return that result immediately. Overrides have the highest
  // precedence.
  if !self.inner.overrides.is_empty() {
    let mat = self.inner.overrides
      .matched(path, is_dir)
      .map(x => IgnoreMatch::Override(x))
    if !mat.is_none() {
      return mat
    }
  }
  let mut whitelisted : Match[IgnoreMatch] = None
  if self.has_any_ignore_rules() {
    let mat = self.matched_ignore(path, is_dir)
    if mat.is_ignore() {
      return mat
    } else if mat.is_whitelist() {
      whitelisted = mat
    }
  }
  if !self.inner.types.is_empty() {
    let mat = self.inner.types
      .matched(path, is_dir)
      .map(x => IgnoreMatch::Types(x))
    if mat.is_ignore() {
      return mat
    } else if mat.is_whitelist() {
      whitelisted = mat
    }
  }
  whitelisted
}

///|
fn gi_match(gi : Gitignore, path : String, is_dir : Bool) -> Match[IgnoreMatch] {
  gi.matched(path, is_dir).map(x => IgnoreMatch::Gitignore(x))
}

///|
/// Performs matching only on the ignore files for this directory and
/// all parent directories.
fn Ignore::matched_ignore(
  self : Ignore,
  path : String,
  is_dir : Bool,
) -> Match[IgnoreMatch] {
  let mut m_custom_ignore : Match[IgnoreMatch] = None
  let mut m_ignore : Match[IgnoreMatch] = None
  let mut m_gi : Match[IgnoreMatch] = None
  let mut m_gi_exclude : Match[IgnoreMatch] = None
  let mut m_explicit : Match[IgnoreMatch] = None
  // N.B. The chain of matchers is walked directly (instead of collecting
  // `parents()`) since this is called for every directory entry.
  let any_git = !self.inner.opts.require_git ||
    ({
      let mut cur = Some(self.inner)
      let mut found = false
      while cur is Some(ig) {
        if ig.has_git {
          found = true
          break
        }
        cur = ig.parent
      }
      found
    })
  let mut saw_git = false
  // Matchers for the directories being walked (up to the first absolute
  // parent).
  let mut cur = Some(self.inner)
  let mut last_child : IgnoreInner? = None
  while cur is Some(ig) && !ig.is_absolute_parent {
    if m_custom_ignore.is_none() {
      m_custom_ignore = gi_match(ig.custom_ignore_matcher, path, is_dir)
    }
    if m_ignore.is_none() {
      m_ignore = gi_match(ig.ignore_matcher, path, is_dir)
    }
    if any_git && !saw_git && m_gi.is_none() {
      m_gi = gi_match(ig.git_ignore_matcher, path, is_dir)
    }
    if any_git && !saw_git && m_gi_exclude.is_none() {
      m_gi_exclude = gi_match(ig.git_exclude_matcher, path, is_dir)
    }
    saw_git = saw_git || ig.has_git
    last_child = Some(ig)
    cur = ig.parent
  }
  if self.inner.opts.parents {
    if self.absolute_base is Some(abs_parent_path) {
      // What we want to do here is take the absolute base path of
      // this directory and join it with the path we're searching.
      // The main issue we want to avoid is accidentally duplicating
      // directory components, so we try to strip any common prefix
      // off of `path`.
      let rel = match last_child {
        None => path
        Some(ig) =>
          // This is a weird special case when ripgrep users search with
          // just a `.`, as some tools do automatically (like consult). In
          // this case, if we don't bail out now, the code below will strip
          // a leading `.` from `path`, which might mangle a hidden file
          // name!
          if path_eq(ig.dir, ".") {
            path
          } else {
            let without_dot_slash = strip_if_is_prefix("./", ig.dir)
            let relative_base = strip_if_is_prefix(without_dot_slash, path)
            strip_if_is_prefix("/", relative_base)
          }
      }
      let path = path_join(abs_parent_path, rel)
      // Matchers for the absolute parents.
      while cur is Some(ig) {
        if m_custom_ignore.is_none() {
          m_custom_ignore = gi_match(ig.custom_ignore_matcher, path, is_dir)
        }
        if m_ignore.is_none() {
          m_ignore = gi_match(ig.ignore_matcher, path, is_dir)
        }
        if any_git && !saw_git && m_gi.is_none() {
          m_gi = gi_match(ig.git_ignore_matcher, path, is_dir)
        }
        if any_git && !saw_git && m_gi_exclude.is_none() {
          m_gi_exclude = gi_match(ig.git_exclude_matcher, path, is_dir)
        }
        saw_git = saw_git || ig.has_git
        cur = ig.parent
      }
    }
  }
  for i = self.inner.explicit_ignores.length() - 1; i >= 0; i = i - 1 {
    if !m_explicit.is_none() {
      break
    }
    m_explicit = gi_match(self.inner.explicit_ignores[i], path, is_dir)
  }
  let m_global = if any_git {
    gi_match(self.inner.git_global_matcher, path, is_dir)
  } else {
    None
  }
  m_custom_ignore
  .or(m_ignore)
  .or(m_gi)
  .or(m_gi_exclude)
  .or(m_global)
  .or(m_explicit)
}

///|
/// Returns all parent ignore matchers, including this one (from this one
/// up to the root).
fn Ignore::parents(self : Ignore) -> Array[IgnoreInner] {
  let out = []
  let mut cur = Some(self.inner)
  while cur is Some(ig) {
    out.push(ig)
    cur = ig.parent
  }
  out
}

///|
/// A builder for creating an Ignore matcher.
priv struct IgnoreBuilder {
  /// The root directory path for this ignore matcher.
  dir : String
  /// An override matcher (default is empty).
  mut overrides : Override
  /// A type matcher (default is empty).
  mut types : Types
  /// Explicit global ignore matchers.
  explicit_ignores : Array[Gitignore]
  /// Ignore files in addition to .ignore.
  custom_ignore_filenames : Array[String]
  /// The directory that gitignores should be interpreted relative to.
  ///
  /// When `None`, global gitignores are ignored.
  mut global_gitignores_relative_to : String?
  /// Ignore config.
  opts : IgnoreOptions
}

///|
/// Create a new builder for an `Ignore` matcher.
fn IgnoreBuilder::new() -> IgnoreBuilder {
  {
    dir: "",
    overrides: Override::empty(),
    types: Types::empty(),
    explicit_ignores: [],
    custom_ignore_filenames: [],
    global_gitignores_relative_to: None,
    opts: {
      hidden: true,
      ignore: true,
      parents: true,
      git_global: true,
      git_ignore: true,
      git_exclude: true,
      ignore_case_insensitive: false,
      require_git: true,
    },
  }
}

///|
/// Builds a new `Ignore` matcher.
///
/// The matcher returned won't match anything until ignore rules from
/// directories are added to it.
async fn IgnoreBuilder::build(self : IgnoreBuilder) -> Ignore {
  self.build_with_cwd(None)
}

///|
/// Builds a new `Ignore` matcher using the given CWD directory.
async fn IgnoreBuilder::build_with_cwd(
  self : IgnoreBuilder,
  cwd : String?,
) -> Ignore {
  let global_gitignores_relative_to = match cwd {
    Some(_) => cwd
    None => self.global_gitignores_relative_to
  }
  let git_global_matcher = if !self.opts.git_global {
    Gitignore::empty()
  } else if global_gitignores_relative_to is Some(cwd) {
    let builder = GitignoreBuilder::new(cwd)
    builder.case_insensitive(self.opts.ignore_case_insensitive) |> ignore
    let (gi, _err) = builder.build_global()
    gi
  } else {
    Gitignore::empty()
  }
  {
    inner: {
      compiled: {},
      dir: self.dir,
      overrides: self.overrides,
      types: self.types,
      parent: None,
      is_absolute_parent: true,
      global_gitignores_relative_to,
      explicit_ignores: self.explicit_ignores.copy(),
      custom_ignore_filenames: self.custom_ignore_filenames.copy(),
      custom_ignore_matcher: Gitignore::empty(),
      ignore_matcher: Gitignore::empty(),
      git_global_matcher,
      git_ignore_matcher: Gitignore::empty(),
      git_exclude_matcher: Gitignore::empty(),
      has_git: false,
      opts: self.opts.copy(),
    },
    absolute_base: None,
  }
}

///|
/// Set the current directory used for matching global gitignores.
fn IgnoreBuilder::current_dir(
  self : IgnoreBuilder,
  cwd : String,
) -> IgnoreBuilder {
  self.global_gitignores_relative_to = Some(cwd)
  self
}

///|
/// Add an override matcher.
fn IgnoreBuilder::overrides(
  self : IgnoreBuilder,
  overrides : Override,
) -> IgnoreBuilder {
  self.overrides = overrides
  self
}

///|
/// Add a file type matcher.
fn IgnoreBuilder::types(self : IgnoreBuilder, types : Types) -> IgnoreBuilder {
  self.types = types
  self
}

///|
/// Adds a new global ignore matcher from the ignore file path given.
fn IgnoreBuilder::add_ignore(
  self : IgnoreBuilder,
  ig : Gitignore,
) -> IgnoreBuilder {
  self.explicit_ignores.push(ig)
  self
}

///|
/// Add a custom ignore file name.
///
/// These ignore files have higher precedence than all other ignore files.
///
/// When specifying multiple names, earlier names have lower precedence than
/// later names.
fn IgnoreBuilder::add_custom_ignore_filename(
  self : IgnoreBuilder,
  file_name : String,
) -> IgnoreBuilder {
  self.custom_ignore_filenames.push(file_name)
  self
}

///|
fn IgnoreBuilder::hidden(self : IgnoreBuilder, yes : Bool) -> IgnoreBuilder {
  self.opts.hidden = yes
  self
}

///|
fn IgnoreBuilder::ignore(self : IgnoreBuilder, yes : Bool) -> IgnoreBuilder {
  self.opts.ignore = yes
  self
}

///|
fn IgnoreBuilder::parents(self : IgnoreBuilder, yes : Bool) -> IgnoreBuilder {
  self.opts.parents = yes
  self
}

///|
fn IgnoreBuilder::git_global(self : IgnoreBuilder, yes : Bool) -> IgnoreBuilder {
  self.opts.git_global = yes
  self
}

///|
fn IgnoreBuilder::git_ignore(self : IgnoreBuilder, yes : Bool) -> IgnoreBuilder {
  self.opts.git_ignore = yes
  self
}

///|
fn IgnoreBuilder::git_exclude(
  self : IgnoreBuilder,
  yes : Bool,
) -> IgnoreBuilder {
  self.opts.git_exclude = yes
  self
}

///|
fn IgnoreBuilder::require_git(
  self : IgnoreBuilder,
  yes : Bool,
) -> IgnoreBuilder {
  self.opts.require_git = yes
  self
}

///|
fn IgnoreBuilder::ignore_case_insensitive(
  self : IgnoreBuilder,
  yes : Bool,
) -> IgnoreBuilder {
  self.opts.ignore_case_insensitive = yes
  self
}

///|
/// Creates a new gitignore matcher for the directory given.
///
/// The matcher is meant to match files below `dir`.
/// Ignore globs are extracted from each of the file names relative to
/// `dir_for_ignorefile` in the order given (earlier names have lower
/// precedence than later names).
///
/// I/O errors are ignored.
async fn create_gitignore(
  dir : String,
  dir_for_ignorefile : String,
  names : Array[String],
  case_insensitive : Bool,
) -> (Gitignore, IgnoreError?) {
  let builder = GitignoreBuilder::new(dir)
  let errs = PartialErrorBuilder::new()
  builder.case_insensitive(case_insensitive) |> ignore
  for name in names {
    let gipath = path_join(dir_for_ignorefile, name)
    // This check is not necessary, but is added for performance. Namely,
    // a simple stat call checking for existence can often be just a bit
    // quicker than actually trying to open a file.
    if path_exists(gipath) {
      errs.maybe_push_ignore_io(builder.add(gipath))
    }
  }
  let gi = builder.build() catch {
    err => {
      errs.push(err)
      GitignoreBuilder::new(dir).build() catch {
        _ => Gitignore::empty()
      }
    }
  }
  (gi, errs.into_error_option())
}

///|
/// Like Rust's `Path::exists`: true if `metadata` (following symlinks)
/// succeeds.
async fn path_exists(path : String) -> Bool {
  (Ok(@sys.metadata(path)) catch { e => Err(e) }) is Ok(_)
}

///|
/// Reads the first line of a file (like `BufRead::lines().next()`).
///
/// Returns `Ok(None)` for an empty file.
async fn read_first_line(path : String) -> String? {
  let data = @sys.read_file(path)
  let lines = split_lines_bytes(data)
  if lines.is_empty() {
    return None
  }
  let line = @utf8.decode(lines[0]) catch {
    _ => raise @sys.IOError::other(Other, "stream did not contain valid UTF-8")
  }
  Some(line)
}

///|
/// Find the GIT_COMMON_DIR for the given git worktree.
///
/// This is the directory that may contain a private ignore file
/// "info/exclude". Unlike git, this function does *not* read environment
/// variables GIT_DIR and GIT_COMMON_DIR, because it is not clear how to use
/// them when multiple repositories are searched.
///
/// Some I/O errors are ignored.
async fn resolve_git_commondir(
  dir : String,
  git_type : @sys.FileType?,
) -> Result[String, IgnoreError?] {
  let git_dir = path_join(dir, ".git")
  if !(git_type is Some(File)) {
    return Ok(git_dir)
  }
  let dot_git_line = match
    (Ok(read_first_line(git_dir)) catch { e => Err(e) }) {
    Ok(Some(line)) => line
    Ok(None) => return Err(None)
    Err(err) =>
      return Err(Some(IgnoreError::Io(@sys.from_error(err)).with_path(git_dir)))
  }
  if !dot_git_line.has_prefix("gitdir: ") {
    return Err(None)
  }
  let real_git_dir = dot_git_line.unsafe_substring(
    start="gitdir: ".length(),
    end=dot_git_line.length(),
  )
  let git_commondir_file = path_join(real_git_dir, "commondir")
  let commondir_line = match
    (Ok(read_first_line(git_commondir_file)) catch { e => Err(e) }) {
    Ok(Some(line)) => line
    Ok(None) => return Err(None)
    Err(err) =>
      // Rust distinguishes failing to open the file (squashed) from
      // failing to read it (reported). Reading a directory is the only
      // read failure we can observe here.
      if @sys.from_error(err).kind() is IsADirectory {
        return Err(
          Some(
            IgnoreError::Io(@sys.from_error(err)).with_path(git_commondir_file),
          ),
        )
      } else {
        return Err(None)
      }
  }
  let commondir_abs = if commondir_line.has_prefix(".") {
    path_join(real_git_dir, commondir_line) // relative commondir
  } else {
    commondir_line
  }
  Ok(commondir_abs)
}

///|
/// Strips `prefix` from `path` if it's a prefix, otherwise returns `path`
/// unchanged.
fn strip_if_is_prefix(prefix : String, path : String) -> String {
  strip_prefix(prefix, path).unwrap_or(path)
}
