// The slice of the `notify` crate (8.0.0, with `notify-types` 2.0.0) that
// `typst_kit::watcher` uses, on top of `moonbitlang/async`'s `@fs.Watcher`:
// the event kinds, `RecommendedWatcher` (`watch`, `unwatch`) and the
// channel it sends its events to.
//
// The two watchers differ, and this file is the bridge:
//
// - notify watches the paths it is given, each one on its own
//   (`RecursiveMode::NonRecursive`). `@fs.Watcher` watches one directory
//   recursively and tells which entries it follows through `ignored_paths`.
//   A path is therefore watched through a watcher of its parent directory
//   that ignores every other entry (and with them everything below the
//   directory's subdirectories); one watcher serves all the paths of a
//   directory. `ignored_paths` is consulted when a directory is scanned,
//   so a running watcher cannot take another path: a new one is started
//   for all the paths of the directory, and the old one runs on for a
//   moment (`LINGER`) to report what it already knows. Hence `watch` only
//   records the path, and `commit` starts the watchers.
// - notify follows a symbolic link to the file. Here a link is watched
//   where it is and, on the targets that can tell a link, where its file
//   is (`sites`).
// - `@fs.Watcher` follows names: when an entry is removed and created
//   again (or replaced by a rename, as editors that write a temporary file
//   do), it follows the new file. notify's inotify backend follows the
//   inode and drops the watch, which `Watcher::wait` works around by
//   unwatching the path and watching it again after the next compilation.
//   The bridge keeps that protocol, because something above the entry may
//   be what was replaced (`rm -r figures; mkdir figures; ..`, the file of a
//   link), and then only a new watcher sees the new file: a removal is
//   reported as `Remove(File)` and a rename away as `Modify(Name(From))`.
//   What the bridge adds is that a path stays reported between `unwatch`
//   and the `commit` that follows: events that arrive while the
//   compilation runs are not lost, as they are with notify until the path
//   is watched again.
// - `@fs.Watcher` reports the net change of a directory since the last
//   `wait` (`Modify`, `Create`, `Remove`, `Rename`), not single operations:
//   access, metadata and the kinds of a data change are not told apart. Its
//   own debouncing is turned off, the batching is `Watcher::wait`'s.
// - Watching a file needs its directory to be readable (notify's inotify
//   and kqueue backends only need the file).
// - Not watched: the entries of a watched directory (a dependency that is a
//   directory only reports its own removal and creation), and a watched
//   directory that is renamed while its files stay (notify's FSEvents
//   backend follows paths and reports it; its inotify backend does not
//   either). On Linux also a link that is made to point elsewhere (removed
//   and created again under its name): `@fs.Watcher`'s inotify backend
//   reports no change for it, and notify's watches the file the link
//   pointed to, which does not change. The link's new file is followed
//   once the path is watched again.

///|
/// An event describing open or close operations on files
/// (`notify_types::event::AccessMode`).
// Only matched, never reported by `@fs.Watcher`.
#warnings("-unused_constructor")
priv enum AccessMode {
  /// The catch-all case, to be used when the specific kind of event is
  /// unknown.
  Any
  /// The file was executed, or the folder opened.
  Execute
  /// The file was opened for reading.
  Read
  /// The file was opened for writing.
  Write
  /// An event which specific kind is known but cannot be represented
  /// otherwise.
  Other
}

///|
/// An event describing non-mutating access operations on files
/// (`notify_types::event::AccessKind`).
#warnings("-unused_constructor")
priv enum AccessKind {
  /// The catch-all case, to be used when the specific kind of event is
  /// unknown.
  Any
  /// An event emitted when the file is read.
  Read
  /// An event emitted when the file, or a handle to the file, is opened.
  Open(AccessMode)
  /// An event emitted when the file, or a handle to the file, is closed.
  Close(AccessMode)
  /// An event which specific kind is known but cannot be represented
  /// otherwise.
  Other
}

///|
/// An event describing creation operations on files
/// (`notify_types::event::CreateKind`).
#warnings("-unused_constructor")
priv enum CreateKind {
  /// The catch-all case, to be used when the specific kind of event is
  /// unknown.
  Any
  /// An event which results in the creation of a file.
  File
  /// An event which results in the creation of a folder.
  Folder
  /// An event which specific kind is known but cannot be represented
  /// otherwise.
  Other
}

///|
/// An event emitted when the data content of a file is changed
/// (`notify_types::event::DataChange`).
#warnings("-unused_constructor")
priv enum DataChange {
  /// The catch-all case, to be used when the specific kind of event is
  /// unknown.
  Any
  /// An event emitted when the size of the data is changed.
  Size
  /// An event emitted when the content of the data is changed.
  Content
  /// An event which specific kind is known but cannot be represented
  /// otherwise.
  Other
}

///|
/// An event emitted when the metadata of a file or folder is changed
/// (`notify_types::event::MetadataKind`).
#warnings("-unused_constructor")
priv enum MetadataKind {
  /// The catch-all case, to be used when the specific kind of event is
  /// unknown.
  Any
  /// An event emitted when the access time of the file or folder is changed.
  AccessTime
  /// An event emitted when the write or modify time of the file or folder is
  /// changed.
  WriteTime
  /// An event emitted when the permissions of the file or folder are
  /// changed.
  Permissions
  /// An event emitted when the ownership of the file or folder is changed.
  Ownership
  /// An event emitted when an extended attribute of the file or folder is
  /// changed.
  Extended
  /// An event which specific kind is known but cannot be represented
  /// otherwise.
  Other
}

///|
/// An event emitted when the name of a file or folder is changed
/// (`notify_types::event::RenameMode`).
#warnings("-unused_constructor")
priv enum RenameMode {
  /// The catch-all case, to be used when the specific kind of event is
  /// unknown.
  Any
  /// An event emitted on the file or folder resulting from a rename.
  To
  /// An event emitted on the file or folder that was renamed.
  From
  /// A single event emitted with both the `From` and `To` paths.
  Both
  /// An event which specific kind is known but cannot be represented
  /// otherwise.
  Other
}

///|
/// An event describing mutation of content, name, or metadata
/// (`notify_types::event::ModifyKind`).
#warnings("-unused_constructor-unused_field")
priv enum ModifyKind {
  /// The catch-all case, to be used when the specific kind of event is
  /// unknown.
  Any
  /// An event emitted when the data content of a file is changed.
  Data(DataChange)
  /// An event emitted when the metadata of a file or folder is changed.
  Metadata(MetadataKind)
  /// An event emitted when the name of a file or folder is changed.
  Name(RenameMode)
  /// An event which specific kind is known but cannot be represented
  /// otherwise.
  Other
}

///|
/// An event describing removal operations on files
/// (`notify_types::event::RemoveKind`).
#warnings("-unused_constructor")
priv enum RemoveKind {
  /// The catch-all case, to be used when the specific kind of event is
  /// unknown.
  Any
  /// An event emitted when a file is removed.
  File
  /// An event emitted when a folder is removed.
  Folder
  /// An event which specific kind is known but cannot be represented
  /// otherwise.
  Other
}

///|
/// Top-level event kind (`notify_types::event::EventKind`).
#warnings("-unused_constructor-unused_field")
priv enum EventKind {
  /// The catch-all event kind, for unsupported/unknown events.
  Any
  /// An event describing non-mutating access operations on files.
  Access(AccessKind)
  /// An event describing creation operations on files.
  Create(CreateKind)
  /// An event describing mutation of content, name, or metadata.
  Modify(ModifyKind)
  /// An event describing removal operations on files.
  Remove(RemoveKind)
  /// An event not fitting in any of the above four categories.
  Other
}

///|
/// Notify event (`notify_types::event::Event`; its attributes are not read
/// by typst-kit).
priv struct Event {
  /// Kind or type of the event.
  kind : EventKind
  /// Paths the event is about, if known.
  paths : Array[String]
}

///|
/// An error of the watcher (`notify::Error`: the `Display` of its kind, and
/// the path it is about).
priv suberror NotifyError {
  NotifyError(String, path~ : String?)
}

///|
impl Show for NotifyError with fn output(self, logger) {
  let NotifyError(error, path~) = self
  match path {
    None => logger.write_string(error)
    Some(path) =>
      logger.write_string("\{error} about [\{@unicode.rust_debug_str(path)}]")
  }
}

///|
/// An error of `@fs.Watcher` for a path as notify reports it: an
/// `io::Error`, but an exhausted inotify as `ErrorKind::MaxFilesWatch`
/// (notify-8.0.0/src/inotify.rs:448).
fn NotifyError::io(err : Error, path : String?) -> NotifyError {
  let error = match err {
    @os_error.OSError(28, ..) if @platform.os() == Linux =>
      "OS file watch limit reached."
    @os_error.OSError(errno, ..) => @platform.os_error(errno).to_string()
    err => err.to_string()
  }
  NotifyError(error, path~)
}

///|
/// The receiving half of the channel of events
/// (`std::sync::mpsc::Receiver<notify::Result<Event>>`).
priv struct Receiver(@aqueue.Queue[Result[Event, NotifyError]])

///|
/// Waits for a value for at most `timeout` milliseconds (`None`: upstream's
/// `Duration::MAX`).
async fn Receiver::recv_timeout(
  self : Receiver,
  timeout : Int32?,
) -> Result[Event, NotifyError]? noraise {
  // An error is a channel without a sender, which upstream treats like a
  // timeout (`Result::into_iter`, `.ok()`).
  match timeout {
    None => Some(self.0.get()) catch { _ => None }
    Some(timeout) =>
      @async.with_timeout_opt(timeout, () => self.0.get()) catch {
        _ => None
      }
  }
}

///|
/// A `@fs.Watcher` of one directory.
priv struct DirWatcher {
  /// The directory.
  dir : String
  /// The entries of the directory that `ignored_paths` lets through, with
  /// the paths they are watched for.
  names : Map[String, Array[String]]
  /// The task that forwards its events.
  mut task : @async.Task[Unit]?
}

///|
/// How a path is watched.
priv enum Watch {
  /// Recorded by `watch`; watched from the next `commit` on.
  Pending
  /// Watched in these directories under these names (see [`sites`]).
  Watched(Array[(String, String)])
}

///|
/// The watcher (`notify::RecommendedWatcher`).
priv struct RecommendedWatcher {
  /// The sending half of the channel of events.
  tx : @aqueue.Queue[Result[Event, NotifyError]]
  /// The tasks that forward the events of the directories' watchers belong
  /// to this group (notify has a thread of its own).
  group : @async.TaskGroup[Unit]
  /// The watched paths.
  paths : Map[String, Watch]
  /// The paths that were unwatched since the last `commit`. Their events
  /// are still reported.
  retired : Map[String, Unit]
  /// The running watcher of every directory with watched paths.
  dirs : Map[String, DirWatcher]
  /// The watchers that were replaced or are no longer needed, to be stopped
  /// a moment after the next `commit`.
  idle : Array[DirWatcher]
}

///|
/// How long a watcher that was replaced or is no longer needed keeps
/// running after a `commit`, in milliseconds: long enough to report what
/// happened to its files before the `commit` (events the operating system
/// queued while a compilation was running, which a new watcher never
/// sees).
const LINGER : Int32 = 1000

///|
/// Creates the watcher and the channel it sends its events to
/// (`std::sync::mpsc::channel` and `RecommendedWatcher::new`).
fn RecommendedWatcher::new(
  group : @async.TaskGroup[Unit],
) -> (RecommendedWatcher, Receiver) {
  let tx = @aqueue.Queue(kind=Unbounded)
  let watcher = {
    tx,
    group,
    paths: Map([]),
    retired: Map([]),
    dirs: Map([]),
    idle: [],
  }
  (watcher, Receiver(tx))
}

///|
/// Begins watching a new path (`Watcher::watch` with
/// `RecursiveMode::NonRecursive`). The path is watched from the next
/// [`commit`](Self::commit) on.
fn RecommendedWatcher::watch(self : RecommendedWatcher, path : String) -> Unit {
  if !self.paths.contains(path) {
    self.paths[path] = Pending
  }
}

///|
/// Stops watching a path (`Watcher::unwatch`; upstream ignores its error
/// for a path that is not watched).
fn RecommendedWatcher::unwatch(
  self : RecommendedWatcher,
  path : String,
) -> Unit {
  match self.paths.get(path) {
    None => ()
    Some(Pending) => self.paths.remove(path)
    Some(Watched(_)) => {
      self.paths.remove(path)
      self.retired[path] = ()
    }
  }
}

///|
/// The directory to watch for a path, and the path's name in it.
fn split_path(path : String) -> (String, String)? {
  guard @platform.file_name(path) is Some(name) else { return None }
  let dir = match @platform.parent(path) {
    Some("") | None => "."
    Some(dir) => dir
  }
  Some((dir, name))
}

///|
/// Where a path is watched: the directories to watch for it and its name
/// in each.
///
/// A symbolic link is watched in two places: where it is (it can be
/// removed, or made to point elsewhere) and where its file is (which can
/// be replaced; notify watches the file a link points to). The wasm
/// targets cannot tell a link and only watch it where it is.
fn sites(path : String) -> Array[(String, String)] {
  guard split_path(path) is Some(site) else { return [] }
  let sites = [site]
  let is_link = (@platform.lstat_kind(path) catch { _ => File }) is Symlink
  if is_link {
    let target = @platform.canonicalize(path) catch { _ => path }
    if split_path(target) is Some(target) && target != site {
      sites.push(target)
    }
  }
  sites
}

///|
/// The key under which a name is looked for among the entries of a
/// directory if it is not one of them.
///
/// A file system that ignores case or normalizes names (APFS, HFS+, NTFS)
/// opens a file under a name that differs from the entry `@fs.Watcher`
/// reads from the directory.
fn name_key(name : StringView) -> String {
  @unicode.to_lowercase(@unicode.nfd(name))
}

///|
/// The entries of a directory under which `@fs.Watcher` reports the given
/// names (see [`resolve_names_in`]).
fn resolve_names(
  dir : String,
  wanted : Map[String, Array[String]],
) -> Map[String, Array[String]] {
  let entries = @platform.read_dir(dir) catch {
    // The watcher will fail for the same reason, and say so.
    _ => return wanted
  }
  resolve_names_in(entries, wanted)
}

///|
/// The entries among `entries` under which the given names are found: the
/// name itself if it is an entry, else the one entry with its key, else
/// (no such entry, or several) the name. A file whose entry is found
/// neither way (a file system that folds names in yet another way) is not
/// watched.
fn resolve_names_in(
  entries : Array[String],
  wanted : Map[String, Array[String]],
) -> Map[String, Array[String]] {
  let exact : Map[String, Unit] = Map([])
  let folded : Map[String, Array[String]] = Map([])
  for entry in entries {
    exact[entry] = ()
    let key = name_key(entry)
    match folded.get(key) {
      Some(same) => same.push(entry)
      None => folded[key] = [entry]
    }
  }
  let names : Map[String, Array[String]] = Map([])
  for name, paths in wanted {
    let entry = if exact.contains(name) {
      name
    } else {
      match folded.get(name_key(name)) {
        Some([entry]) => entry
        _ => name
      }
    }
    match names.get(entry) {
      Some(known) => known.append(paths)
      None => names[entry] = paths
    }
  }
  names
}

///|
/// Starts watching the paths recorded by [`watch`](Self::watch) and stops
/// the watchers that are no longer needed.
async fn RecommendedWatcher::commit(
  self : RecommendedWatcher,
) -> Unit raise NotifyError {
  // The directories of the new paths get a new watcher. That is also what
  // watches a path again that was unwatched because its file was removed:
  // the new watcher looks at what is there now.
  let renew : Map[String, String] = Map([])
  for path, watch in self.paths.copy() {
    guard watch is Pending else { continue }
    let sites = sites(path)
    if sites.is_empty() {
      raise NotifyError("No path was found.", path=Some(path))
    }
    for site in sites {
      if !renew.contains(site.0) {
        renew[site.0] = path
      }
    }
    self.paths[path] = Watched(sites)
  }

  // Everything that is watched in these directories, old and new, and the
  // directories that are in use at all.
  let wanted : Map[String, Map[String, Array[String]]] = Map([])
  let used : Map[String, Unit] = Map([])
  for path, watch in self.paths {
    guard watch is Watched(sites) else { continue }
    for site in sites {
      let (dir, name) = site
      used[dir] = ()
      guard renew.contains(dir) else { continue }
      let names = match wanted.get(dir) {
        Some(names) => names
        None => {
          let names = Map([])
          wanted[dir] = names
          names
        }
      }
      match names.get(name) {
        Some(paths) => paths.push(path)
        None => names[name] = [path]
      }
    }
  }
  for dir, wanted in wanted {
    let names = resolve_names(dir, wanted)
    let inner = @fs.Watcher(dir, debounce_timeout=0, ignored_paths=entry => {
      !names.contains(entry)
    }) catch {
      err => raise NotifyError::io(err, renew.get(dir))
    }
    let watcher = { dir, names, task: None, }
    watcher.task = Some(
      self.group.spawn(no_wait=true, () => self.forward(watcher, inner)),
    )
    // The watcher it replaces has seen what happened until now.
    if self.dirs.get(dir) is Some(old) {
      self.idle.push(old)
    }
    self.dirs[dir] = watcher
  }
  for dir, watcher in self.dirs.copy() {
    if !used.contains(dir) {
      self.dirs.remove(dir)
      self.idle.push(watcher)
    }
  }

  // From here on the new watchers report the paths that were unwatched and
  // watched again; the others are forgotten.
  self.retired.clear()
  for watcher in self.idle {
    guard watcher.task is Some(task) else { continue }
    self.group.spawn_bg(no_wait=true, () => {
      @async.sleep(LINGER)
      task.cancel()
    })
  }
  self.idle.clear()
}

///|
/// Whether events of a path are reported: it is watched, or it was until a
/// moment ago.
fn RecommendedWatcher::reports(
  self : RecommendedWatcher,
  path : String,
) -> Bool {
  self.paths.contains(path) || self.retired.contains(path)
}

///|
/// Sends an event for every reported path that is watched under the given
/// entry of a watcher's directory.
async fn RecommendedWatcher::send(
  self : RecommendedWatcher,
  watcher : DirWatcher,
  entry : String,
  kind : EventKind,
) -> Unit {
  guard watcher.names.get(entry) is Some(paths) else { return }
  for path in paths {
    if self.reports(path) {
      self.tx.put(Ok({ kind, paths: [path], }))
    }
  }
}

///|
/// Translates the events of a directory's watcher and sends them to the
/// channel, until the task is cancelled.
async fn RecommendedWatcher::forward(
  self : RecommendedWatcher,
  watcher : DirWatcher,
  inner : @fs.Watcher,
) -> Unit {
  defer inner.close()
  for ;; {
    let events = inner.wait() catch {
      _ => {
        // The watcher gave up, which is what happens when its directory is
        // removed. Unless it was replaced already, its paths are not
        // watched any more: report that like notify reports the watches it
        // drops.
        if self.dirs.get(watcher.dir) is Some(current) &&
          physical_equal(current, watcher) {
          self.dirs.remove(watcher.dir)
          for paths in watcher.names.values() {
            for path in paths {
              if self.reports(path) {
                self.tx.put(Ok({ kind: Remove(File), paths: [path], }))
              }
            }
          }
        }
        return
      }
    }
    for event in events {
      match event {
        Modify(entry) => self.send(watcher, entry, Modify(Data(Any)))
        Create(entry) => self.send(watcher, entry, Create(Any))
        Remove(entry) => self.send(watcher, entry, Remove(File))
        Rename(old~, new~) => {
          self.send(watcher, old, Modify(Name(From)))
          self.send(watcher, new, Modify(Name(To)))
        }
      }
    }
  }
}
