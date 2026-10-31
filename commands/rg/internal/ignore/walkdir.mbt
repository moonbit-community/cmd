// A port of the parts of the `walkdir` crate (v2) used by the sequential
// `Walk` iterator: a depth-first recursive directory iterator with optional
// sorting, symlink following (with loop detection) and depth limits.

///|
/// A raw directory entry. This models both `walkdir::DirEntry` and ignore's
/// `DirEntryRaw` (they are essentially the same thing).
priv struct RawEntry {
  /// The path as reported by `read_dir` (even if it's a symbolic link).
  path : String
  /// The file type. When `follow_link` is set, this is the file type of the
  /// link target.
  ty : @sys.FileType
  /// Is set when this entry was created from a symbolic link and the user
  /// expects the iterator to follow symbolic links.
  follow_link : Bool
  /// The depth at which this entry was generated relative to the root.
  depth : Int32
  /// Whether this entry was produced by the walkdir iterator (affects the
  /// rendering of metadata errors only).
  from_walkdir : Bool
}

///|
fn RawEntry::path_is_symlink(self : RawEntry) -> Bool {
  self.ty is Symlink || self.follow_link
}

///|
fn RawEntry::file_name(self : RawEntry) -> String {
  path_file_name(self.path).unwrap_or(self.path)
}

///|
fn RawEntry::is_dir(self : RawEntry) -> Bool {
  self.ty is Dir
}

///|
async fn RawEntry::metadata(self : RawEntry) -> @sys.Metadata {
  let md = try {
    if self.follow_link {
      @sys.metadata(self.path)
    } else {
      @sys.symlink_metadata(self.path)
    }
  } catch {
    err =>
      if self.from_walkdir {
        let werr = WdError::from_path(self.depth, self.path, err)
        raise IgnoreError::Io(werr.to_io_error())
          .with_depth(self.depth)
          .with_path(self.path)
      } else {
        raise IgnoreError::Io(@sys.from_error(err))
          .with_depth(self.depth)
          .with_path(self.path)
      }
  }
  md
}

///|
/// Builds an entry from a directory listing entry.
async fn RawEntry::from_entry(
  depth : Int32,
  dir : String,
  entry : @sys.DirEntry,
  from_walkdir : Bool,
) -> RawEntry {
  let path = path_join(dir, entry.name)
  let ty = entry.file_type(path)
  { path, ty, follow_link: false, depth, from_walkdir, }
}

///|
/// Builds an entry from a path. When `follow` is true, `metadata` is used
/// (following symlinks), otherwise `symlink_metadata`.
async fn RawEntry::from_path(
  depth : Int32,
  path : String,
  follow : Bool,
  follow_link~ : Bool,
  from_walkdir~ : Bool,
) -> RawEntry {
  let md = if follow {
    @sys.metadata(path)
  } else {
    @sys.symlink_metadata(path)
  }
  { path, ty: md.file_type, follow_link, depth, from_walkdir, }
}

///|
/// Canonical path evidence used only for followed-directory loop detection.
async fn canonical_for_loop(path : String) -> String? {
  // Preserve metadata errors before the optional canonical-path observation.
  ignore(@sys.metadata(path))
  Some(canonicalize(path)) catch {
    _ => None
  }
}

///|
priv enum WdErrorInner {
  Io(path~ : String?, err~ : @sys.IOError)
  Loop(ancestor~ : String, child~ : String)
}

///|
/// An error produced by the walkdir iterator (`walkdir::Error`).
priv struct WdError {
  depth : Int32
  inner : WdErrorInner
}

///|
fn WdError::from_path(depth : Int32, path : String, err : Error) -> WdError {
  { depth, inner: Io(path=Some(path), err=@sys.from_error(err)), }
}

///|
fn WdError::from_io(depth : Int32, err : Error) -> WdError {
  { depth, inner: Io(path=None, err=@sys.from_error(err)), }
}

///|
fn WdError::path(self : WdError) -> String? {
  match self.inner {
    Io(path~, ..) => path
    Loop(child~, ..) => Some(child)
  }
}

///|
fn WdError::loop_ancestor(self : WdError) -> String? {
  match self.inner {
    Loop(ancestor~, ..) => Some(ancestor)
    _ => None
  }
}

///|
/// Renders like `walkdir::Error`'s `Display`.
fn WdError::to_string(self : WdError) -> String {
  match self.inner {
    Io(path=None, err~) => Show::to_string(err)
    Io(path=Some(path), err~) =>
      "IO error for operation on \{path}: \{Show::to_string(err)}"
    Loop(ancestor~, child~) =>
      "File system loop found: \{child} points to an ancestor \{ancestor}"
  }
}

///|
/// Converts to an I/O error like `impl From<walkdir::Error> for io::Error`.
fn WdError::to_io_error(self : WdError) -> @sys.IOError {
  let kind = match self.inner {
    Io(err~, ..) => @sys.from_error(err).kind()
    Loop(..) => Other
  }
  @sys.IOError::other(kind, self.to_string())
}

///|
/// Build an error from a walkdir error (`Error::from_walkdir`).
fn IgnoreError::from_walkdir(err : WdError) -> IgnoreError {
  let depth = err.depth
  if (err.loop_ancestor(), err.path()) is (Some(anc), Some(child)) {
    return WithDepth(depth~, err=Loop(ancestor=anc, child~))
  }
  let path = err.path()
  let mut ig_err = IgnoreError::WithDepth(depth~, err=Io(err.to_io_error()))
  if path is Some(path) {
    ig_err = WithPath(path~, err=ig_err)
  }
  ig_err
}

///|
priv struct WalkDirOptions {
  follow_links : Bool
  max_depth : Int32
  min_depth : Int32
  sorter : ((RawEntry, RawEntry) -> Int32)?
}

///|
/// A list of directory entries that are yet to be yielded.
priv struct DirList {
  entries : Array[Result[RawEntry, WdError]]
  mut pos : Int32
}

///|
fn DirList::next(self : DirList) -> Result[RawEntry, WdError]? {
  if self.pos < self.entries.length() {
    let e = self.entries[self.pos]
    self.pos += 1
    Some(e)
  } else {
    None
  }
}

///|
priv struct Ancestor {
  path : String
  canonical : String?
}

///|
/// The walkdir recursive iterator (`walkdir::IntoIter`).
priv struct WalkDirIter {
  opts : WalkDirOptions
  mut start : String?
  stack_list : Array[DirList]
  stack_path : Array[Ancestor]
  mut depth : Int32
}

///|
fn WalkDirIter::new(root : String, opts : WalkDirOptions) -> WalkDirIter {
  { opts, start: Some(root), stack_list: [], stack_path: [], depth: 0, }
}

///|
async fn WalkDirIter::next(self : WalkDirIter) -> Result[RawEntry, WdError]? {
  if self.start is Some(start) {
    self.start = None
    let dent = RawEntry::from_path(
      0,
      start,
      false,
      follow_link=false,
      from_walkdir=true,
    ) catch {
      e => return Some(Err(WdError::from_path(0, start, e)))
    }
    if self.handle_entry(dent) is Some(result) {
      return Some(result)
    }
  }
  while !self.stack_list.is_empty() {
    self.depth = self.stack_list.length()
    if self.depth > self.opts.max_depth {
      // If we've exceeded the max depth, pop the current dir
      // so that we don't descend.
      self.pop()
      continue
    }
    match self.stack_list[self.stack_list.length() - 1].next() {
      None => self.pop()
      Some(Err(err)) => return Some(Err(err))
      Some(Ok(dent)) =>
        if self.handle_entry(dent) is Some(result) {
          return Some(result)
        }
    }
  }
  None
}

///|
/// Skips the current directory.
///
/// This causes the iterator to stop traversing the contents of the least
/// recently yielded directory.
fn WalkDirIter::skip_current_dir(self : WalkDirIter) -> Unit {
  if !self.stack_list.is_empty() {
    self.pop()
  }
}

///|
async fn WalkDirIter::handle_entry(
  self : WalkDirIter,
  dent : RawEntry,
) -> Result[RawEntry, WdError]? {
  let mut dent = dent
  if self.opts.follow_links && dent.ty is Symlink {
    match self.follow(dent) {
      Ok(d) => dent = d
      Err(e) => return Some(Err(e))
    }
  }
  let is_normal_dir = !(dent.ty is Symlink) && dent.is_dir()
  if is_normal_dir {
    if self.push(dent) is Err(e) {
      return Some(Err(e))
    }
  } else if dent.depth == 0 && dent.ty is Symlink {
    // As a special case, if we are processing a root entry, then we
    // always follow it even if it's a symlink and follow_links is false.
    // We are careful to not let this change the semantics of the
    // DirEntry however. Namely, the DirEntry should still respect the
    // follow_links setting. When it's disabled, it should report itself
    // as a symlink. When it's enabled, it should always report itself as
    // the target.
    let md = @sys.metadata(dent.path) catch {
      e => return Some(Err(WdError::from_path(dent.depth, dent.path, e)))
    }
    if md.file_type is Dir {
      if self.push(dent) is Err(e) {
        return Some(Err(e))
      }
    }
  }
  if self.skippable() {
    None
  } else {
    Some(Ok(dent))
  }
}

///|
async fn WalkDirIter::push(
  self : WalkDirIter,
  dent : RawEntry,
) -> Result[Unit, WdError] {
  let depth = self.depth
  let entries : Array[Result[RawEntry, WdError]] = match
    (Ok(@sys.read_dir(dent.path)) catch { e => Err(e) }) {
    Err(err) => [Err(WdError::from_path(depth, dent.path, err))]
    Ok(list) => {
      let mapped = []
      for ent in list {
        let path = path_join(dent.path, ent.name)
        let entry = match
          (Ok(RawEntry::from_entry(depth + 1, dent.path, ent, true)) catch {
            e => Err(e)
          }) {
          Ok(e) => Ok(e)
          Err(err) => Err(WdError::from_path(depth + 1, path, err))
        }
        mapped.push(entry)
      }
      mapped
    }
  }
  if self.opts.sorter is Some(cmp) {
    stable_sort_by(entries, (a, b) => {
      match (a, b) {
        (Ok(a), Ok(b)) => cmp(a, b)
        (Err(_), Err(_)) => 0
        (Ok(_), Err(_)) => 1
        (Err(_), Ok(_)) => -1
      }
    })
  }
  if self.opts.follow_links {
    let canonical = canonical_for_loop(dent.path) catch {
      err => return Err(WdError::from_io(self.depth, err))
    }
    self.stack_path.push({ path: dent.path, canonical, })
  }
  self.stack_list.push({ entries, pos: 0, })
  Ok(())
}

///|
fn WalkDirIter::pop(self : WalkDirIter) -> Unit {
  self.stack_list.pop() |> ignore
  if self.opts.follow_links {
    self.stack_path.pop() |> ignore
  }
}

///|
async fn WalkDirIter::follow(
  self : WalkDirIter,
  dent : RawEntry,
) -> Result[RawEntry, WdError] {
  let dent = RawEntry::from_path(
    dent.depth,
    dent.path,
    true,
    follow_link=true,
    from_walkdir=true,
  ) catch {
    e => return Err(WdError::from_path(dent.depth, dent.path, e))
  }
  // The only way a symlink can cause a loop is if it points
  // to a directory. Otherwise, it always points to a leaf
  // and we can omit any loop checks.
  if dent.is_dir() {
    if self.check_loop(dent.path) is Err(e) {
      return Err(e)
    }
  }
  Ok(dent)
}

///|
async fn WalkDirIter::check_loop(
  self : WalkDirIter,
  child : String,
) -> Result[Unit, WdError] {
  let canonical = canonical_for_loop(child) catch {
    err => return Err(WdError::from_io(self.depth, err))
  }
  for i = self.stack_path.length() - 1; i >= 0; i = i - 1 {
    let ancestor = self.stack_path[i]
    if (ancestor.canonical, canonical) is (Some(a), Some(b)) && a == b {
      return Err({
        depth: self.depth,
        inner: Loop(ancestor=ancestor.path, child~),
      })
    }
  }
  Ok(())
}

///|
fn WalkDirIter::skippable(self : WalkDirIter) -> Bool {
  self.depth < self.opts.min_depth || self.depth > self.opts.max_depth
}

///|
/// A stable merge sort (like Rust's `slice::sort_by`).
fn[T] stable_sort_by(xs : Array[T], cmp : (T, T) -> Int32) -> Unit {
  let n = xs.length()
  if n < 2 {
    return
  }
  let buf = xs.copy()
  fn merge_sort(lo : Int32, hi : Int32) -> Unit {
    if hi - lo < 2 {
      return
    }
    let mid = lo + (hi - lo) / 2
    merge_sort(lo, mid)
    merge_sort(mid, hi)
    let mut i = lo
    let mut j = mid
    let mut k = lo
    while i < mid && j < hi {
      if cmp(xs[j], xs[i]) < 0 {
        buf[k] = xs[j]
        j += 1
      } else {
        buf[k] = xs[i]
        i += 1
      }
      k += 1
    }
    while i < mid {
      buf[k] = xs[i]
      i += 1
      k += 1
    }
    while j < hi {
      buf[k] = xs[j]
      j += 1
      k += 1
    }
    for t in lo..<hi {
      xs[t] = buf[t]
    }
  }

  merge_sort(0, n)
}
