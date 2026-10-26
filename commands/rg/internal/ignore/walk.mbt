// Port of `ignore/src/walk.rs` (sequential parts).

///|
/// A directory entry with a possible error attached.
///
/// The error typically refers to a problem parsing ignore files in a
/// particular directory.
pub struct DirEntry {
  priv dent : DirEntryInner
  priv mut err : IgnoreError?
}

///|
/// DirEntryInner is the implementation of DirEntry.
priv enum DirEntryInner {
  Stdin
  Raw(RawEntry)
}

///|
pub impl Debug for DirEntry with fn to_repr(self) {
  @debug.Repr::record({
    "path": Debug::to_repr(self.path()),
    "depth": Debug::to_repr(self.depth()),
    "file_type": Debug::to_repr(self.file_type()),
    "err": Debug::to_repr(self.err),
  })
}

///|
/// The full path that this entry represents.
pub fn DirEntry::path(self : DirEntry) -> String {
  match self.dent {
    Stdin => "<stdin>"
    Raw(x) => x.path
  }
}

///|
/// The full path that this entry represents (same as `path`).
pub fn DirEntry::into_path(self : DirEntry) -> String {
  self.path()
}

///|
/// Whether this entry corresponds to a symbolic link or not.
pub fn DirEntry::path_is_symlink(self : DirEntry) -> Bool {
  match self.dent {
    Stdin => false
    Raw(x) => x.path_is_symlink()
  }
}

///|
/// Returns true if and only if this entry corresponds to stdin.
///
/// i.e., The entry has depth 0 and its file name is `-`.
pub fn DirEntry::is_stdin(self : DirEntry) -> Bool {
  self.dent is Stdin
}

///|
/// Return the metadata for the file that this entry points to.
pub async fn DirEntry::metadata(self : DirEntry) -> @sys.Metadata {
  match self.dent {
    Stdin =>
      raise IgnoreError::Io(
        @sys.IOError::other(Other, "<stdin> has no metadata"),
      ).with_path("<stdin>")
    Raw(x) => x.metadata()
  }
}

///|
/// Return the file type for the file that this entry points to.
///
/// This entry doesn't have a file type if it corresponds to stdin.
pub fn DirEntry::file_type(self : DirEntry) -> @sys.FileType? {
  match self.dent {
    Stdin => None
    Raw(x) => Some(x.ty)
  }
}

///|
/// Return the file name of this entry.
///
/// If this entry has no file name (e.g., `/`), then the full path is
/// returned.
pub fn DirEntry::file_name(self : DirEntry) -> String {
  match self.dent {
    Stdin => "<stdin>"
    Raw(x) => x.file_name()
  }
}

///|
/// Returns the depth at which this entry was created relative to the root.
pub fn DirEntry::depth(self : DirEntry) -> Int32 {
  match self.dent {
    Stdin => 0
    Raw(x) => x.depth
  }
}

///|
/// Returns the underlying inode number if one exists.
///
/// If this entry doesn't have an inode number, then `None` is returned.
pub async fn DirEntry::ino(self : DirEntry) -> UInt64? {
  match self.dent {
    Stdin => None
    Raw(x) => x.ino()
  }
}

///|
/// Returns an error, if one exists, associated with processing this entry.
///
/// An example of an error is one that occurred while parsing an ignore
/// file. Errors related to traversing a directory tree itself are reported
/// as part of yielding the directory entry, and not with this method.
pub fn DirEntry::error(self : DirEntry) -> IgnoreError? {
  self.err
}

///|
/// Returns true if and only if this entry points to a directory.
fn DirEntry::is_dir(self : DirEntry) -> Bool {
  match self.dent {
    Stdin => false
    Raw(x) => x.is_dir()
  }
}

///|
fn DirEntry::new_stdin() -> DirEntry {
  { dent: Stdin, err: None, }
}

///|
fn DirEntry::new_raw(dent : RawEntry, err : IgnoreError?) -> DirEntry {
  { dent: Raw(dent), err, }
}

///|
priv enum Sorter {
  ByName((String, String) -> Int32)
  ByPath((String, String) -> Int32)
}

///|
priv enum CwdState {
  Unset
  Known(String)
  Failed
}

///|
/// WalkBuilder builds a recursive directory iterator.
///
/// The builder supports a large number of configurable options. This
/// includes specific glob overrides, file type matching, toggling whether
/// hidden files are ignored or not, and of course, support for respecting
/// gitignore files.
///
/// By default, all ignore files found are respected. This includes
/// `.ignore`, `.gitignore`, `.git/info/exclude` and even your global
/// gitignore globs, usually found in `$XDG_CONFIG_HOME/git/ignore`.
///
/// Some standard recursive directory options are also supported, such as
/// limiting the recursive depth or whether to follow symbolic links
/// (disabled by default).
///
/// # Ignore rules
///
/// There are many rules that influence whether a particular file or
/// directory is skipped by this iterator. Those rules are documented here.
/// Note that the rules assume a default configuration.
///
/// * First, glob overrides are checked. If a path matches a glob override,
///   then matching stops. The path is then only skipped if the glob that
///   matched the path is an ignore glob. (An override glob is a whitelist
///   glob unless it starts with a `!`, in which case it is an ignore glob.)
/// * Second, ignore files are checked. Ignore files currently only come from
///   git ignore files (`.gitignore`, `.git/info/exclude` and the configured
///   global gitignore file), plain `.ignore` files, which have the same
///   format as gitignore files, or explicitly added ignore files. The
///   precedence order is: `.ignore`, `.gitignore`, `.git/info/exclude`,
///   global gitignore and finally explicitly added ignore files. Note that
///   precedence between different types of ignore files is not impacted by
///   the directory hierarchy; any `.ignore` file overrides all `.gitignore`
///   files. Within each precedence level, more nested ignore files have a
///   higher precedence than less nested ignore files.
/// * Third, if the previous step yields an ignore match, then all matching
///   is stopped and the path is skipped. If it yields a whitelist match,
///   then matching continues. A whitelist match can be overridden by a later
///   matcher.
/// * Fourth, unless the path is a directory, the file type matcher is run on
///   the path. As above, if it yields an ignore match, then all matching is
///   stopped and the path is skipped. If it yields a whitelist match, then
///   matching continues.
/// * Fifth, if the path hasn't been whitelisted and it is hidden, then the
///   path is skipped.
/// * Sixth, unless the path is a directory, the size of the file is
///   compared against the max filesize limit. If it exceeds the limit, it is
///   skipped.
/// * Seventh, if the path has made it this far then it is yielded in the
///   iterator.
pub struct WalkBuilder {
  priv paths : Array[String]
  priv ig_builder : IgnoreBuilder
  priv mut max_depth : Int32?
  priv mut min_depth : Int32?
  priv mut max_filesize : UInt64?
  priv mut follow_links : Bool
  priv mut same_file_system : Bool
  priv mut sorter : Sorter?
  priv mut threads : Int32
  priv mut skip : Handle?
  priv mut filter : ((DirEntry) -> Bool)?
  /// The directory that gitignores should be interpreted relative to.
  priv mut global_gitignores_relative_to : CwdState
}

///|
/// Create a new builder for a recursive directory iterator for the
/// directory given.
///
/// Note that if you want to traverse multiple different directories, it
/// is better to call `add` on this builder than to create multiple
/// `Walk` values.
pub fn WalkBuilder::new(path : String) -> WalkBuilder {
  WalkBuilder::from_iter([path])
}

///|
/// Create an empty builder to which paths can be added.
///
/// Note that if you call `build` on this instance before calling `add`
/// on it, it will return exactly zero items during iteration.
pub fn WalkBuilder::empty() -> WalkBuilder {
  {
    paths: [],
    ig_builder: IgnoreBuilder::new(),
    max_depth: None,
    min_depth: None,
    max_filesize: None,
    follow_links: false,
    same_file_system: false,
    sorter: None,
    threads: 0,
    skip: None,
    filter: None,
    global_gitignores_relative_to: Unset,
  }
}

///|
/// Create a new builder for a recursive directory iterator from the
/// sequence of paths.
///
/// Note that if the sequence is empty, this is the same as
/// `WalkBuilder::empty`.
pub fn WalkBuilder::from_iter(paths : ArrayView[String]) -> WalkBuilder {
  let builder = WalkBuilder::empty()
  for path in paths {
    builder.add(path) |> ignore
  }
  builder
}

///|
/// Build a new `Walk` iterator.
pub async fn WalkBuilder::build(self : WalkBuilder) -> Walk {
  let follow_links = self.follow_links
  let max_depth = self.max_depth
  let min_depth = self.min_depth
  let sorter = self.sorter
  let its : Array[(String, WalkEventIter?)] = []
  for p in self.paths {
    its.push(
      if p == "-" {
        (p, Option::None)
      } else {
        let cmp : ((RawEntry, RawEntry) -> Int32)? = match sorter {
          None => None
          Some(ByName(cmp)) => Some((a, b) => cmp(a.file_name(), b.file_name()))
          Some(ByPath(cmp)) => Some((a, b) => cmp(a.path, b.path))
        }
        let opts : WalkDirOptions = {
          follow_links: follow_links || is_file(p),
          max_depth: max_depth.unwrap_or(2147483647),
          min_depth: min_depth.unwrap_or(0),
          same_file_system: self.same_file_system,
          sorter: cmp,
        }
        (p, Some(WalkEventIter::new(WalkDirIter::new(p, opts))))
      },
    )
  }
  let ig_root = self.build_ignore()
  {
    its,
    its_pos: 0,
    it: None,
    ig_root,
    ig: ig_root,
    max_depth: self.max_depth,
    max_filesize: self.max_filesize,
    skip: self.skip,
    filter: self.filter,
  }
}

///|
/// Build a new `WalkParallel` iterator.
///
/// Note that this *doesn't* return something that implements an iterator.
/// Instead, the returned value must be run with a closure. e.g.,
/// `builder.build_parallel().run(() => path => { ...; Continue })`.
pub async fn WalkBuilder::build_parallel(self : WalkBuilder) -> WalkParallel {
  let ig_root = self.build_ignore()
  {
    paths: self.paths.copy(),
    ig_root,
    max_depth: self.max_depth,
    min_depth: self.min_depth,
    max_filesize: self.max_filesize,
    follow_links: self.follow_links,
    same_file_system: self.same_file_system,
    threads: self.threads,
    skip: self.skip,
    filter: self.filter,
  }
}

///|
/// Add a file path to the iterator.
///
/// Each additional file path added is traversed recursively. This should
/// be preferred over building multiple `Walk` iterators since this
/// enables reusing resources across iteration.
pub fn WalkBuilder::add(self : WalkBuilder, path : String) -> WalkBuilder {
  self.paths.push(path)
  self
}

///|
/// The maximum depth to recurse.
///
/// The default, `None`, imposes no depth restriction.
pub fn WalkBuilder::max_depth(
  self : WalkBuilder,
  depth : Int32?,
) -> WalkBuilder {
  self.max_depth = depth
  if (self.min_depth, self.max_depth) is (Some(min), Some(max)) && max < min {
    self.max_depth = self.min_depth
  }
  self
}

///|
/// The minimum depth to recurse.
///
/// The default, `None`, imposes no minimum depth restriction.
pub fn WalkBuilder::min_depth(
  self : WalkBuilder,
  depth : Int32?,
) -> WalkBuilder {
  self.min_depth = depth
  if (self.max_depth, self.min_depth) is (Some(max), Some(min)) && min > max {
    self.min_depth = self.max_depth
  }
  self
}

///|
/// Whether to follow symbolic links or not.
pub fn WalkBuilder::follow_links(self : WalkBuilder, yes : Bool) -> WalkBuilder {
  self.follow_links = yes
  self
}

///|
/// Whether to ignore files above the specified limit.
pub fn WalkBuilder::max_filesize(
  self : WalkBuilder,
  filesize : UInt64?,
) -> WalkBuilder {
  self.max_filesize = filesize
  self
}

///|
/// The number of threads to use for traversal.
///
/// Note that this only has an effect when using `build_parallel`. (In this
/// port, the parallel walker always executes on a single thread.)
///
/// The default setting is `0`, which chooses the number of threads
/// automatically using heuristics.
pub fn WalkBuilder::threads(self : WalkBuilder, n : Int32) -> WalkBuilder {
  self.threads = n
  self
}

///|
/// Add a global ignore file to the matcher.
///
/// This has lower precedence than all other sources of ignore rules.
///
/// # Errors
///
/// If there was a problem adding the ignore file, then an error is
/// returned. Note that the error may indicate *partial* failure. For
/// example, if an ignore file contains an invalid glob, all other globs
/// are still applied.
///
/// An error will also occur if this walker could not get the current
/// working directory (and `WalkBuilder::current_dir` isn't set).
pub async fn WalkBuilder::add_ignore(
  self : WalkBuilder,
  path : String,
) -> IgnoreError? {
  guard self.get_or_set_current_dir() is Some(cwd) else {
    return Some(
      Io(
        @sys.IOError::other(
          Other,
          "CWD is not known, ignoring global gitignore \{path}",
        ),
      ),
    )
  }
  let builder = GitignoreBuilder::new(cwd)
  let errs = PartialErrorBuilder::new()
  errs.maybe_push(builder.add(path))
  match (Ok(builder.build()) catch { e => Err(e) }) {
    Ok(gi) => self.ig_builder.add_ignore(gi) |> ignore
    Err(err) => errs.push(err)
  }
  errs.into_error_option()
}

///|
/// Add a custom ignore file name
///
/// These ignore files have higher precedence than all other ignore files.
///
/// When specifying multiple names, earlier names have lower precedence than
/// later names.
pub fn WalkBuilder::add_custom_ignore_filename(
  self : WalkBuilder,
  file_name : String,
) -> WalkBuilder {
  self.ig_builder.add_custom_ignore_filename(file_name) |> ignore
  self
}

///|
/// Add an override matcher.
///
/// By default, no override matcher is used.
///
/// This overrides any previous setting.
pub fn WalkBuilder::overrides(
  self : WalkBuilder,
  overrides : Override,
) -> WalkBuilder {
  self.ig_builder.overrides(overrides) |> ignore
  self
}

///|
/// Add a file type matcher.
///
/// By default, no file type matcher is used.
///
/// This overrides any previous setting.
pub fn WalkBuilder::types(self : WalkBuilder, types : Types) -> WalkBuilder {
  self.ig_builder.types(types) |> ignore
  self
}

///|
/// Enables all the standard ignore filters.
///
/// This toggles, as a group, all the filters that are enabled by default:
/// `hidden`, `parents`, `ignore`, `git_ignore`, `git_global` and
/// `git_exclude`.
///
/// They may still be toggled individually after calling this function.
///
/// This is (by definition) enabled by default.
pub fn WalkBuilder::standard_filters(
  self : WalkBuilder,
  yes : Bool,
) -> WalkBuilder {
  self
  .hidden(yes)
  .parents(yes)
  .ignore(yes)
  .git_ignore(yes)
  .git_global(yes)
  .git_exclude(yes)
}

///|
/// Enables ignoring hidden files.
///
/// This is enabled by default.
pub fn WalkBuilder::hidden(self : WalkBuilder, yes : Bool) -> WalkBuilder {
  self.ig_builder.hidden(yes) |> ignore
  self
}

///|
/// Enables reading ignore files from parent directories.
///
/// If this is enabled, then .gitignore files in parent directories of each
/// file path given are respected. Otherwise, they are ignored.
///
/// This is enabled by default.
pub fn WalkBuilder::parents(self : WalkBuilder, yes : Bool) -> WalkBuilder {
  self.ig_builder.parents(yes) |> ignore
  self
}

///|
/// Enables reading `.ignore` files.
///
/// `.ignore` files have the same semantics as `gitignore` files and are
/// supported by search tools such as ripgrep and The Silver Searcher.
///
/// This is enabled by default.
pub fn WalkBuilder::ignore(self : WalkBuilder, yes : Bool) -> WalkBuilder {
  self.ig_builder.ignore(yes) |> ignore
  self
}

///|
/// Enables reading a global gitignore file, whose path is specified in
/// git's `core.excludesFile` config option.
///
/// Git's config file location is `$HOME/.gitconfig`. If `$HOME/.gitconfig`
/// does not exist or does not specify `core.excludesFile`, then
/// `$XDG_CONFIG_HOME/git/ignore` is read. If `$XDG_CONFIG_HOME` is not
/// set or is empty, then `$HOME/.config/git/ignore` is used instead.
///
/// This is enabled by default.
pub fn WalkBuilder::git_global(self : WalkBuilder, yes : Bool) -> WalkBuilder {
  self.ig_builder.git_global(yes) |> ignore
  self
}

///|
/// Enables reading `.gitignore` files.
///
/// `.gitignore` files have match semantics as described in the `gitignore`
/// man page.
///
/// This is enabled by default.
pub fn WalkBuilder::git_ignore(self : WalkBuilder, yes : Bool) -> WalkBuilder {
  self.ig_builder.git_ignore(yes) |> ignore
  self
}

///|
/// Enables reading `.git/info/exclude` files.
///
/// `.git/info/exclude` files have match semantics as described in the
/// `gitignore` man page.
///
/// This is enabled by default.
pub fn WalkBuilder::git_exclude(self : WalkBuilder, yes : Bool) -> WalkBuilder {
  self.ig_builder.git_exclude(yes) |> ignore
  self
}

///|
/// Whether a git repository is required to apply git-related ignore
/// rules (global rules, .gitignore and local exclude rules).
///
/// When disabled, git-related ignore rules are applied even when searching
/// outside a git repository.
///
/// In particular, if this is `false` then `.gitignore` files will be read
/// from parent directories above the git root directory containing `.git`,
/// which is different from the git behavior.
pub fn WalkBuilder::require_git(self : WalkBuilder, yes : Bool) -> WalkBuilder {
  self.ig_builder.require_git(yes) |> ignore
  self
}

///|
/// Process ignore files case insensitively
///
/// This is disabled by default.
pub fn WalkBuilder::ignore_case_insensitive(
  self : WalkBuilder,
  yes : Bool,
) -> WalkBuilder {
  self.ig_builder.ignore_case_insensitive(yes) |> ignore
  self
}

///|
/// Set a function for sorting directory entries by their path.
///
/// If a compare function is set, the resulting iterator will return all
/// paths in sorted order. The compare function will be called to compare
/// entries from the same directory. It must return a negative number, zero
/// or a positive number (like Rust's `Ordering::{Less, Equal, Greater}`).
///
/// This is like `sort_by_file_name`, except the comparator accepts
/// the full path instead of the base file name, which permits it to sort by
/// more criteria.
///
/// This method will override any previous sorter set by this method or
/// by `sort_by_file_name`.
///
/// Note that this is not used in the parallel iterator.
pub fn WalkBuilder::sort_by_file_path(
  self : WalkBuilder,
  cmp : (String, String) -> Int32,
) -> WalkBuilder {
  self.sorter = Some(ByPath(cmp))
  self
}

///|
/// Set a function for sorting directory entries by file name.
///
/// If a compare function is set, the resulting iterator will return all
/// paths in sorted order. The compare function will be called to compare
/// names from entries from the same directory using only the name of the
/// entry. Use `compare_utf8` for Rust's `OsStr` (byte-wise) ordering.
///
/// This method will override any previous sorter set by this method or
/// by `sort_by_file_path`.
///
/// Note that this is not used in the parallel iterator.
pub fn WalkBuilder::sort_by_file_name(
  self : WalkBuilder,
  cmp : (String, String) -> Int32,
) -> WalkBuilder {
  self.sorter = Some(ByName(cmp))
  self
}

///|
/// Do not cross file system boundaries.
///
/// When this option is enabled, directory traversal will not descend into
/// directories that are on a different file system from the root path.
///
/// On backends that cannot report device numbers (wasm), all paths are
/// considered to be on the same file system.
pub fn WalkBuilder::same_file_system(
  self : WalkBuilder,
  yes : Bool,
) -> WalkBuilder {
  self.same_file_system = yes
  self
}

///|
/// Do not yield directory entries that are believed to correspond to
/// stdout.
///
/// This is useful when a command is invoked via shell redirection to a
/// file that is also being read. For example, `grep -r foo ./ > results`
/// might end up trying to search `results` even though it is also writing
/// to it, which could cause an unbounded feedback loop. Setting this
/// option prevents this from happening by skipping over the `results`
/// file.
///
/// This is disabled by default.
pub async fn WalkBuilder::skip_stdout(
  self : WalkBuilder,
  yes : Bool,
) -> WalkBuilder {
  if yes {
    self.skip = stdout_handle()
  } else {
    self.skip = None
  }
  self
}

///|
/// Yields only entries which satisfy the given predicate and skips
/// descending into directories that do not satisfy the given predicate.
///
/// The predicate is applied to all entries. If the predicate is
/// true, iteration carries on as normal. If the predicate is false, the
/// entry is ignored and if it is a directory, it is not descended into.
///
/// Note that the errors for reading entries that may not satisfy the
/// predicate will still be yielded.
///
/// Note also that only one filter predicate can be applied to a
/// `WalkBuilder`. Calling this subsequent times overrides previous filter
/// predicates.
pub fn WalkBuilder::filter_entry(
  self : WalkBuilder,
  filter : (DirEntry) -> Bool,
) -> WalkBuilder {
  self.filter = Some(filter)
  self
}

///|
/// Set the current working directory used for matching global gitignores.
///
/// If this is not set, then this walker will attempt to discover the
/// correct path from the environment's current working directory. If
/// that fails, then global gitignore files will be ignored.
///
/// Global gitignore files come from things like a user's git configuration
/// or from gitignore files added via `WalkBuilder::add_ignore`.
pub fn WalkBuilder::current_dir(
  self : WalkBuilder,
  cwd : String,
) -> WalkBuilder {
  self.ig_builder.current_dir(cwd) |> ignore
  self.global_gitignores_relative_to = Known(cwd)
  self
}

///|
/// Gets the currently configured CWD on this walk builder.
///
/// This is "lazy." That is, we only ask for the CWD from the environment
/// if `WalkBuilder::current_dir` hasn't been called yet. And we ensure
/// that we only do it once.
fn WalkBuilder::get_or_set_current_dir(self : WalkBuilder) -> String? {
  match self.global_gitignores_relative_to {
    Known(cwd) => Some(cwd)
    Failed => None
    Unset =>
      match @sys.current_dir() {
        Some(cwd) => {
          self.global_gitignores_relative_to = Known(cwd)
          Some(cwd)
        }
        None => {
          self.global_gitignores_relative_to = Failed
          None
        }
      }
  }
}

///|
/// Build the root ignore matcher shared by all consumers of this builder.
async fn WalkBuilder::build_ignore(self : WalkBuilder) -> Ignore {
  match self.get_or_set_current_dir() {
    Some(cwd) => self.ig_builder.build_with_cwd(Some(cwd))
    None => self.ig_builder.build()
  }
}

///|
/// Walk is a recursive directory iterator over file paths in one or more
/// directories.
///
/// Only file and directory paths matching the rules are returned. By
/// default, ignore files like `.gitignore` are respected. The precise
/// matching rules and precedence is explained in the documentation for
/// `WalkBuilder`.
pub struct Walk {
  priv its : Array[(String, WalkEventIter?)]
  priv mut its_pos : Int32
  priv mut it : WalkEventIter?
  priv ig_root : Ignore
  priv mut ig : Ignore
  priv max_depth : Int32?
  priv max_filesize : UInt64?
  priv skip : Handle?
  priv filter : ((DirEntry) -> Bool)?
}

///|
/// Creates a new recursive directory iterator for the file path given.
///
/// Note that this uses default settings, which include respecting
/// `.gitignore` files. To configure the iterator, use `WalkBuilder`
/// instead.
pub async fn Walk::new(path : String) -> Walk {
  WalkBuilder::new(path).build()
}

///|
/// Create a new recursive directory iterator from the sequence of paths
/// given.
///
/// Note that if the provided sequence is empty, then `Walk` is guaranteed
/// to yield zero entries.
pub async fn Walk::from_iter(paths : ArrayView[String]) -> Walk {
  WalkBuilder::from_iter(paths).build()
}

///|
async fn Walk::skip_entry(self : Walk, ent : DirEntry) -> Bool {
  if ent.depth() == 0 {
    return false
  }
  // We ensure that trivial skipping is done before any other potentially
  // expensive operations (stat, filesystem other) are done.
  if should_skip_entry(self.ig, ent) {
    return true
  }
  if self.skip is Some(stdout) {
    if path_equals(ent, stdout) {
      return true
    }
  }
  if self.max_filesize is Some(max_filesize) && !ent.is_dir() {
    return skip_filesize(
      max_filesize,
      ent.path(),
      (Ok(ent.metadata()) catch { e => Err(e) }).to_option(),
    )
  }
  if self.filter is Some(filter) {
    if !filter(ent) {
      return true
    }
  }
  false
}

///|
/// Advances the iterator, returning the next entry or error, or `None` when
/// the walk is complete.
pub async fn Walk::next(self : Walk) -> Result[DirEntry, IgnoreError]? {
  for ;; {
    let ev = match self.it {
      Some(it) => it.next()
      None => None
    }
    let ev = match ev {
      Some(ev) => ev
      None => {
        if self.its_pos >= self.its.length() {
          return None
        }
        let (path, it) = self.its[self.its_pos]
        self.its_pos += 1
        match it {
          None => return Some(Ok(DirEntry::new_stdin()))
          Some(it) => {
            self.it = Some(it)
            if is_dir(path) {
              let (ig, err) = self.ig_root.add_parents(path)
              self.ig = ig
              if err is Some(err) {
                return Some(Err(err))
              }
            } else {
              self.ig = self.ig_root
            }
          }
        }
        continue
      }
    }
    match ev {
      Err(err) => return Some(Err(IgnoreError::from_walkdir(err)))
      Ok(Exit) =>
        self.ig = match self.ig.parent() {
          Some(p) => p
          None => abort("BUG: walk exited a directory without a parent")
        }
      Ok(Dir(ent)) => {
        let ent = DirEntry::new_raw(ent, None)
        let should_skip = self.skip_entry(ent) catch {
          err => return Some(Err(from_async_error(err)))
        }
        if should_skip {
          match self.it {
            Some(it) => it.it.skip_current_dir()
            None => ()
          }
          // Still need to push this on the stack because
          // we'll get a WalkEvent::Exit event for this dir.
          // Its ignore files cannot apply to any visited entry.
          let (igtmp, _) = self.ig.add_child_with_entries(ent.path(), [])
          self.ig = igtmp
          continue
        }
        let (igtmp, err) = if self.max_depth == Some(ent.depth()) {
          self.ig.add_child_with_entries(ent.path(), [])
        } else {
          self.ig.add_child(ent.path())
        }
        self.ig = igtmp
        ent.err = err
        return Some(Ok(ent))
      }
      Ok(File(ent)) => {
        let ent = DirEntry::new_raw(ent, None)
        let should_skip = self.skip_entry(ent) catch {
          err => return Some(Err(from_async_error(err)))
        }
        if should_skip {
          continue
        }
        return Some(Ok(ent))
      }
    }
  }
}

///|
/// Returns an iterator over the remaining results of this walk.
pub async fn Walk::iter(self : Walk) -> Array[Result[DirEntry, IgnoreError]] {
  self.collect()
}

///|
pub async fn Walk::collect(self : Walk) -> Array[Result[DirEntry, IgnoreError]] {
  let entries = []
  while self.next() is Some(entry) {
    entries.push(entry)
  }
  entries
}

///|
priv enum WalkEvent {
  Dir(RawEntry)
  File(RawEntry)
  Exit
}

///|
/// WalkEventIter transforms a WalkDir iterator into an iterator that more
/// accurately describes the directory tree. Namely, it emits events that are
/// one of three types: directory, file or "exit." An "exit" event means that
/// the entire contents of a directory have been enumerated.
priv struct WalkEventIter {
  mut depth : Int32
  it : WalkDirIter
  mut next : Result[RawEntry, WdError]?
}

///|
fn WalkEventIter::new(it : WalkDirIter) -> WalkEventIter {
  { depth: 0, it, next: None, }
}

///|
async fn WalkEventIter::next(
  self : WalkEventIter,
) -> Result[WalkEvent, WdError]? {
  let dent = match self.next {
    Some(d) => {
      self.next = None
      Some(d)
    }
    None => self.it.next()
  }
  let depth = match dent {
    None => 0
    Some(Ok(dent)) => dent.depth
    Some(Err(err)) => err.depth
  }
  if depth < self.depth {
    self.depth -= 1
    self.next = dent
    return Some(Ok(Exit))
  }
  self.depth = depth
  match dent {
    None => None
    Some(Err(err)) => Some(Err(err))
    Some(Ok(dent)) =>
      if walkdir_is_dir(dent) {
        self.depth += 1
        Some(Ok(Dir(dent)))
      } else {
        Some(Ok(File(dent)))
      }
  }
}

///|
/// Returns true if the given walkdir entry corresponds to a directory.
///
/// This is normally just `dent.file_type().is_dir()`, but when we aren't
/// following symlinks, the root directory entry may be a symlink to a
/// directory that we *do* follow---by virtue of it being specified by the
/// user explicitly. In that case, we need to follow the symlink and query
/// whether it's a directory or not. But we only do this for root entries to
/// avoid an additional stat check in most cases.
async fn walkdir_is_dir(dent : RawEntry) -> Bool {
  if dent.ty is Dir {
    return true
  }
  if !(dent.ty is Symlink) || dent.depth > 0 {
    return false
  }
  is_dir(dent.path)
}

///|
// Before calling this function, make sure that you ensure that is really
// necessary as the arguments imply a file stat.
async fn skip_filesize(
  max_filesize : UInt64,
  path : String,
  ent : @sys.Metadata?,
) -> Bool {
  match ent {
    Some(md) => {
      // The length may be unknown (on wasm); compute it only when needed.
      let len = if md.len >= 0L {
        md.len
      } else {
        @sys.file_len(path) catch {
          _ => return false
        }
      }
      len.reinterpret_as_uint64() > max_filesize
    }
    None => false
  }
}

///|
fn should_skip_entry(ig : Ignore, dent : DirEntry) -> Bool {
  let m = ig.matched_dir_entry(dent)
  if m.is_ignore() {
    true
  } else {
    false
  }
}

///|
/// Returns a handle to stdout for filtering search.
///
/// A handle is returned if and only if stdout is being redirected to a file.
/// The handle returned corresponds to that file.
///
/// This port determines the stdout file by querying the metadata of
/// `/dev/stdout`, which on Linux and macOS resolves to the file open on
/// file descriptor 1.
async fn stdout_handle() -> Handle? {
  if @sys.is_tty(1) is Available(true) {
    return None
  }
  let md = @sys.metadata("/dev/stdout") catch { _ => return None }
  if !(md.file_type is File) {
    return None
  }
  if md.dev is None || md.ino is None {
    // Can't identify the file.
    return None
  }
  // On macOS, `/dev/stdout` resolves through the `fdesc` file system: the
  // inode number is the one of the open file, but the device number is the
  // one of `/dev`. In that case only the inode number can be compared.
  let dev_known = try @sys.metadata("/dev").dev != md.dev catch {
    _ => true
  }
  Some({ dev: md.dev, ino: md.ino, dev_known, canonical: None, })
}

///|
/// Returns true if and only if the given directory entry is believed to be
/// equivalent to the given handle. If there was a problem querying the path
/// for information to determine equality, then that error is returned.
async fn path_equals(dent : DirEntry, handle : Handle) -> Bool {
  // If we know for sure that these two things aren't equal, then avoid
  // the costly extra stat call to determine equality.
  if dent.is_stdin() || dent.ino() != handle.ino {
    return false
  }
  let h = Handle::from_path(dent.path()) catch {
    err =>
      raise IgnoreError::Io(@sys.from_error(err))
        .with_depth(dent.depth())
        .with_path(dent.path())
  }
  h.same(handle)
}
