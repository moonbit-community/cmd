// Port of the "parallel" walker from `ignore/src/walk.rs`.
//
// MoonBit has no threads here, so `WalkParallel` keeps Rust's API but runs
// a single worker that processes a LIFO work stack, exactly like Rust's
// implementation does when it is configured with one thread.

///|
/// WalkState is used in the parallel recursive directory iterator to
/// indicate whether walking should continue as normal, skip descending into
/// a particular directory or quit the walk entirely.
pub(all) enum WalkState {
  /// Continue walking as normal.
  Continue
  /// If the directory entry given is a directory, don't descend into it.
  /// In all other cases, this has no effect.
  Skip
  /// Quit the entire iterator as soon as possible.
  Quit
} derive(Eq, Debug)

///|
fn WalkState::is_continue(self : WalkState) -> Bool {
  self is Continue
}

///|
fn WalkState::is_quit(self : WalkState) -> Bool {
  self is Quit
}

///|
/// Receives files and directories for the current "thread". This is called
/// once for every directory entry visited by traversal.
pub(open) trait ParallelVisitor {
  fn visit(Self, Result[DirEntry, IgnoreError]) -> WalkState
}

///|
/// A builder for constructing a visitor when using `WalkParallel::visit`.
/// The builder will be called for each "thread" started by `WalkParallel`.
/// The visitor returned from each builder is then called for every
/// directory entry.
pub(open) trait ParallelVisitorBuilder {
  fn build(Self) -> &ParallelVisitor
}

///|
priv struct FnVisitor((Result[DirEntry, IgnoreError]) -> WalkState)

///|
impl ParallelVisitor for FnVisitor with fn visit(self, entry) {
  (self.0)(entry)
}

///|
priv struct FnBuilder(() -> (Result[DirEntry, IgnoreError]) -> WalkState)

///|
impl ParallelVisitorBuilder for FnBuilder with fn build(self) {
  FnVisitor((self.0)()) as &ParallelVisitor
}

///|
/// WalkParallel is a "parallel" recursive directory iterator over files
/// paths in one or more directories.
///
/// Only file and directory paths matching the rules are returned. By
/// default, ignore files like `.gitignore` are respected. The precise
/// matching rules and precedence is explained in the documentation for
/// `WalkBuilder`.
///
/// Unlike `Walk`, entries are pushed to a callback. In this port, the
/// traversal is executed on a single thread.
pub struct WalkParallel {
  priv paths : Array[String]
  priv ig_root : Ignore
  priv max_filesize : UInt64?
  priv max_depth : Int32?
  priv min_depth : Int32?
  priv follow_links : Bool
  priv same_file_system : Bool
  priv threads : Int32
  priv skip : Handle?
  priv filter : ((DirEntry) -> Bool)?
}

///|
/// Execute the parallel recursive directory iterator. `mkf` is called
/// for each "thread" used for iteration. The function produced by `mkf`
/// is then in turn called for each visited file path.
pub async fn WalkParallel::run(
  self : WalkParallel,
  mkf : () -> (Result[DirEntry, IgnoreError]) -> WalkState,
) -> Unit {
  self.visit(FnBuilder(mkf) as &ParallelVisitorBuilder)
}

///|
/// Execute the parallel recursive directory iterator using a custom
/// visitor.
///
/// The builder given is used to construct a visitor for every "thread"
/// used by this traversal. The visitor returned from each builder is then
/// called for every directory entry seen by that thread.
pub async fn WalkParallel::visit(
  self : WalkParallel,
  builder : &ParallelVisitorBuilder,
) -> Unit {
  let stack : Array[Work] = []
  {
    let visitor = builder.build()
    // Send the initial set of root paths to the pool of workers. Note
    // that we only send directories. For files, we send to them the
    // callback directly.
    for path in self.paths {
      let (dent, root_device) : (DirEntry, UInt64?) = if path == "-" {
        (DirEntry::new_stdin(), None)
      } else {
        let root_device : UInt64? = if !self.same_file_system {
          None
        } else {
          match (Ok(@sys.metadata(path)) catch { e => Err(e) }) {
            Ok(md) => md.dev
            Err(err) => {
              let err = IgnoreError::Io(@sys.from_error(err)).with_path(path)
              if visitor.visit(Err(err)).is_quit() {
                return
              }
              continue
            }
          }
        }
        match
          (Ok(
            RawEntry::from_path(
              0,
              path,
              true,
              follow_link=false,
              from_walkdir=false,
            ),
          ) catch {
            e => Err(e)
          }) {
          Ok(dent) => (DirEntry::new_raw(dent, None), root_device)
          Err(err) => {
            let err = IgnoreError::Io(@sys.from_error(err))
              .with_depth(0)
              .with_path(path)
            if visitor.visit(Err(err)).is_quit() {
              return
            }
            continue
          }
        }
      }
      stack.push({ dent, ignore: self.ig_root, root_device, })
    }
    // ... but there's no need to start workers if we don't need them.
    if stack.is_empty() {
      return
    }
  }
  // Reverse the order so that the LIFO processing visits the roots in the
  // order they were given.
  stack.rev_in_place()
  // Like Rust, a visitor is built for every configured thread (before any
  // work starts). Since this port is single threaded, all of the work is
  // then executed by the first one.
  let visitors = []
  for _ in 0..<self.threads() {
    visitors.push(builder.build())
  }
  let worker : Worker = {
    visitor: visitors[0],
    stack,
    quit_now: false,
    max_depth: self.max_depth,
    min_depth: self.min_depth,
    max_filesize: self.max_filesize,
    follow_links: self.follow_links,
    skip: self.skip,
    filter: self.filter,
  }
  worker.run()
}

///|
/// Returns the number of "threads" (visitors) used by this walker. A
/// configured value of `0` means "choose automatically", which is always `1`
/// in this port since the traversal itself runs on a single thread.
fn WalkParallel::threads(self : WalkParallel) -> Int32 {
  if self.threads <= 0 {
    1
  } else {
    self.threads
  }
}

///|
/// A unit of work for each worker to process.
///
/// Each unit of work corresponds to a directory that should be descended
/// into (or a file that should be passed to the visitor).
priv struct Work {
  /// The directory entry.
  dent : DirEntry
  /// Any ignore matchers that have been built for this directory's parents.
  mut ignore : Ignore
  /// The root device number. When present, only files with the same device
  /// number should be considered.
  root_device : UInt64?
}

///|
priv struct ReadDirResult {
  entries : Array[@sys.DirEntry]
  errors : Array[IgnoreError]
}

///|
/// Returns true if and only if this work item is a directory.
fn Work::is_dir(self : Work) -> Bool {
  self.dent.is_dir()
}

///|
/// Returns true if and only if this work item is a symlink.
fn Work::is_symlink(self : Work) -> Bool {
  self.dent.file_type() is Some(Symlink)
}

///|
/// Adds ignore rules for parent directories.
///
/// Note that this only applies to entries at depth 0. On all other
/// entries, this is a no-op.
async fn Work::add_parents(self : Work) -> IgnoreError? {
  if self.dent.depth() > 0 {
    return None
  }
  // At depth 0, the path of this entry is a root path, so we can
  // use it directly to add parent ignore rules.
  let (ig, err) = self.ignore.add_parents(self.dent.path())
  self.ignore = ig
  err
}

///|
/// Adds ignore rules for this directory without reading its contents.
async fn Work::add_ignore(self : Work) -> Unit {
  let (ig, err) = self.ignore.add_child(self.dent.path())
  self.ignore = ig
  self.dent.err = err
}

///|
/// Reads the directory contents of this work item and adds ignore
/// rules for this directory.
///
/// If there was a problem with reading the directory contents, then
/// an error is returned. If there was a problem reading the ignore
/// rules for this directory, then the error is attached to this
/// work item's directory entry.
async fn Work::read_dir(self : Work) -> ReadDirResult {
  let entries = @sys.read_dir(self.dent.path()) catch {
    err =>
      raise IgnoreError::Io(@sys.from_error(err))
        .with_path(self.dent.path())
        .with_depth(self.dent.depth())
  }
  let result = { entries, errors: [], }
  let (ig, err) = self.ignore.add_child_with_entries(
    self.dent.path(),
    result.entries,
  )
  self.ignore = ig
  self.dent.err = err
  result
}

///|
/// A worker is responsible for descending into directories, updating the
/// ignore matchers, producing new work and invoking the caller's callback.
priv struct Worker {
  /// The caller's callback.
  visitor : &ParallelVisitor
  /// A stack of work to do (LIFO, i.e., depth first).
  stack : Array[Work]
  /// Whether the worker should terminate at the next opportunity.
  mut quit_now : Bool
  /// The maximum depth of directories to descend. A value of `0` means no
  /// descension at all.
  max_depth : Int32?
  /// The minimum depth of directories to descend.
  min_depth : Int32?
  /// The maximum size a searched file can be (in bytes). If a file exceeds
  /// this size it will be skipped.
  max_filesize : UInt64?
  /// Whether to follow symbolic links or not. When this is enabled, loop
  /// detection is performed.
  follow_links : Bool
  /// A file handle to skip, currently is either `None` or stdout, if it's
  /// a file and it has been requested to skip files identical to stdout.
  skip : Handle?
  /// A predicate applied to dir entries. If true, the entry and all
  /// children will be skipped.
  filter : ((DirEntry) -> Bool)?
}

///|
/// Runs this worker until there is no more work left to do.
async fn Worker::run(self : Worker) -> Unit {
  while !self.quit_now && self.stack.pop() is Some(work) {
    if self.run_one(work) is Quit {
      self.quit_now = true
    }
  }
}

///|
async fn Worker::run_one(self : Worker, work : Work) -> WalkState {
  let should_visit = match self.min_depth {
    Some(min_depth) => work.dent.depth() >= min_depth
    None => true
  }
  // If the work is not a directory, then we can just execute the
  // caller's callback immediately and move on.
  if work.is_symlink() || !work.is_dir() {
    return if should_visit {
      self.visitor.visit(Ok(work.dent))
    } else {
      Continue
    }
  }
  if work.add_parents() is Some(err) {
    let state = self.visitor.visit(Err(from_async_error(err)))
    if state.is_quit() {
      return state
    }
  }
  let descend = match work.root_device {
    Some(root_device) =>
      match
        (Ok(is_same_file_system(root_device, work.dent.path())) catch {
          e => Err(e)
        }) {
        Ok(same) => same
        Err(err) => {
          let state = self.visitor.visit(Err(from_async_error(err)))
          if state.is_quit() {
            return state
          }
          false
        }
      }
    None => true
  }
  // Try to read the directory first before we transfer ownership
  // to the provided closure. Do not unwrap it immediately, though,
  // as we may receive an `Err` value e.g. in the case when we do not
  // have sufficient read permissions to list the directory.
  // In that case we still want to provide the closure with a valid
  // entry before passing the error value.
  let depth = work.dent.depth()
  let readdir = if descend && is_none_or(self.max_depth, m => depth < m) {
    Some(Ok(work.read_dir()) catch { e => Err(e) })
  } else {
    work.add_ignore()
    None
  }
  if should_visit {
    let state = self.visitor.visit(Ok(work.dent))
    if !state.is_continue() {
      return state
    }
  }
  if !descend {
    return Skip
  }
  let readdir = match readdir {
    Some(readdir) => readdir
    None => return Skip
  }
  let readdir = match readdir {
    Ok(readdir) => readdir
    Err(err) => return self.visitor.visit(Err(from_async_error(err)))
  }
  for ent in readdir.entries {
    let state = self.generate_work(
      work.ignore,
      work.dent.path(),
      depth + 1,
      work.root_device,
      ent,
    )
    if state.is_quit() {
      return state
    }
  }
  for err in readdir.errors {
    let state = self.visitor.visit(Err(from_async_error(err)))
    if state.is_quit() {
      return state
    }
  }
  Continue
}

///|
/// Decides whether to submit the given directory entry as a file to
/// search.
///
/// If the entry is a path that should be ignored, then this is a no-op.
/// Otherwise, the entry is pushed on to the stack. (The actual execution
/// of the callback happens in `run_one`.)
///
/// If an error occurs while reading the entry, then it is sent to the
/// caller's callback.
///
/// `ig` is the `Ignore` matcher for the parent directory. `depth` should
/// be the depth of this entry.
async fn Worker::generate_work(
  self : Worker,
  ig : Ignore,
  dir : String,
  depth : Int32,
  root_device : UInt64?,
  fs_dent : @sys.DirEntry,
) -> WalkState {
  let mut dent = match
    (Ok(RawEntry::from_entry(depth, dir, fs_dent, false)) catch { e => Err(e) }) {
    Ok(dent) => DirEntry::new_raw(dent, None)
    Err(err) => {
      let path = path_join(dir, fs_dent.name)
      let err = IgnoreError::Io(@sys.from_error(err))
        .with_depth(depth)
        .with_path(path)
      return self.visitor.visit(Err(err.with_depth(depth)))
    }
  }
  let is_symlink = dent.file_type() is Some(Symlink)
  if self.follow_links && is_symlink {
    let path = dent.path()
    dent = match
      (Ok(
        RawEntry::from_path(
          depth,
          path,
          true,
          follow_link=true,
          from_walkdir=false,
        ),
      ) catch {
        e => Err(e)
      }) {
      Ok(dent) => DirEntry::new_raw(dent, None)
      Err(err) => {
        let err = IgnoreError::Io(@sys.from_error(err))
          .with_depth(depth)
          .with_path(path)
        return self.visitor.visit(Err(from_async_error(err)))
      }
    }
    if dent.is_dir() {
      if (Ok(check_symlink_loop(ig, dent.path(), depth)) catch { e => Err(e) })
        is Err(err) {
        return self.visitor.visit(Err(from_async_error(err)))
      }
    }
  }
  // N.B. See analogous call in the single-threaded implementation about
  // why it's important for this to come before the checks below.
  if should_skip_entry(ig, dent) {
    return Continue
  }
  if self.skip is Some(stdout) {
    let is_stdout = match
      (Ok(path_equals(dent, stdout)) catch { e => Err(e) }) {
      Ok(is_stdout) => is_stdout
      Err(err) => return self.visitor.visit(Err(from_async_error(err)))
    }
    if is_stdout {
      return Continue
    }
  }
  let should_skip_filesize = match self.max_filesize {
    Some(max_filesize) if !dent.is_dir() =>
      skip_filesize(
        max_filesize,
        dent.path(),
        (Ok(dent.metadata()) catch { e => Err(e) }).to_option(),
      )
    _ => false
  }
  let should_skip_filtered = match self.filter {
    Some(predicate) => !predicate(dent)
    None => false
  }
  if !should_skip_filesize && !should_skip_filtered {
    self.stack.push({ dent, ignore: ig, root_device, })
  }
  Continue
}

///|
async fn check_symlink_loop(
  ig_parent : Ignore,
  child_path : String,
  child_depth : Int32,
) -> Unit {
  let hchild = Handle::from_path(child_path) catch {
    err =>
      raise IgnoreError::Io(@sys.from_error(err))
        .with_path(child_path)
        .with_depth(child_depth)
  }
  for ig in ig_parent.parents() {
    if ig.is_absolute_parent {
      break
    }
    let h = Handle::from_path(ig.dir) catch {
      err =>
        raise IgnoreError::Io(@sys.from_error(err))
          .with_path(child_path)
          .with_depth(child_depth)
    }
    if hchild.same(h) {
      raise IgnoreError::Loop(ancestor=ig.dir, child=child_path).with_depth(
        child_depth,
      )
    }
  }
}

///|
/// Returns true if and only if the given path is on the same device as the
/// given root device.
async fn is_same_file_system(root_device : UInt64, path : String) -> Bool {
  let md = @sys.metadata(path) catch {
    err => raise IgnoreError::Io(@sys.from_error(err)).with_path(path)
  }
  Some(root_device) == md.dev
}
