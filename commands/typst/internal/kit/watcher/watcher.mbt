// File system watching (upstream `typst_kit::watcher`).
//
// This can be used to implement `typst watch`-like functionality.
//
// Upstream is built on the `notify` crate; here its part is played by
// `notify.mbt` on `moonbitlang/async`'s `@fs.Watcher`. That makes `update`
// and `wait` asynchronous: they have to run inside [`run`].

///|
/// Watches file system activity.
pub struct Watcher {
  /// The output file. We ignore any events for it.
  priv output : String?
  /// The underlying watcher.
  priv watcher : RecommendedWatcher
  /// Notify event receiver.
  priv rx : Receiver
  /// Keeps track of which paths are watched via `watcher`. The boolean is
  /// used during updating for mark-and-sweep garbage collection of paths we
  /// should unwatch.
  priv watched : Map[String, Bool]
  /// A set of files that should be watched, but don't exist. We manually poll
  /// for those.
  priv missing : Map[String, Unit]
}

///|
/// How long to wait for a shortly following file system event when
/// watching.
const BATCH_TIMEOUT : Int32 = 100

///|
/// The maximum time we spend batching events before quitting `wait()`.
const STARVE_TIMEOUT : Int32 = 500

///|
/// The interval in which we poll when falling back to poll watching
/// due to missing files.
const POLL_INTERVAL : Int32 = 300

///|
/// Create a new, blank watcher.
///
/// All writes to the `output` path will be ignored.
///
/// The watcher's event sources are tasks of `group`, the group of the
/// [`run`] it is created in (not upstream: notify has a thread of its own).
// Upstream returns a `StrResult` (typst-kit/src/watcher.rs:51): creating
// notify's watcher can fail ("failed to setup file watching ({err})").
// Nothing is acquired here before the first `update`.
#warnings("-unused_error_type")
pub fn Watcher::new(
  output : String?,
  group : Tasks,
) -> Watcher raise @kit.StrError {
  // Set up file watching.
  //
  // (Upstream sets the poll interval of `notify::PollWatcher` here, which
  // only a tiny number of systems use. There is no such fallback.)
  let (watcher, rx) = RecommendedWatcher::new(group)
  { output, rx, watcher, watched: Map([]), missing: Map([]), }
}

///|
/// Update the watching to watch exactly the listed files.
///
/// Files that are not yet watched will be watched. Files that are already
/// watched, but don't need to be watched anymore, will be unwatched.
pub async fn Watcher::update(
  self : Watcher,
  iter : Array[String],
) -> Unit raise @kit.StrError {
  // Mark all files as not "seen" so that we may unwatch them if they
  // aren't in the dependency list.
  for path in self.watched.keys().to_array() {
    self.watched[path] = false
  }

  // Reset which files are missing.
  self.missing.clear()

  // Retrieve the dependencies of the last compilation and watch new paths
  // that weren't watched yet.
  for path in iter {
    // We can't watch paths that don't exist with notify-rs. Instead, we
    // add those to a `missing` set and fall back to manual poll
    // watching.
    if !@platform.exists(path) {
      self.missing[path] = ()
      continue
    }

    // Watch the path if it's not already watched.
    //
    // (The path is only recorded here and watched by the `commit` below,
    // which is also where upstream's error for it is raised.)
    if !self.watched.contains(path) {
      self.watcher.watch(path)
    }

    // Mark the file as "seen" so that we don't unwatch it.
    self.watched[path] = true
  }

  // Unwatch old paths that don't need to be watched anymore.
  for path, seen in self.watched.copy() {
    if !seen {
      self.watcher.unwatch(path)
      self.watched.remove(path)
    }
  }

  // Not upstream: start watching the new paths, one `@fs.Watcher` for all
  // of a directory (see `notify.mbt`).
  self.watcher.commit() catch {
    NotifyError(_, path~) as err =>
      raise @kit.StrError(
        match path {
          Some(path) =>
            "failed to watch \{@unicode.rust_debug_str(path)} (\{err})"
          None => "failed to watch dependencies (\{err})"
        },
      )
  }
}

///|
/// Wait until there is a change to a watched path.
pub async fn Watcher::wait(self : Watcher) -> Unit raise @kit.StrError {
  for ;; {
    // Wait for an initial event. If there are missing files, we need to
    // poll those regularly to check whether they are created, so we
    // wait with a smaller timeout.
    let mut first = self.rx.recv_timeout(
      if self.missing.is_empty() {
        None
      } else {
        Some(POLL_INTERVAL)
      },
    )

    // Watch for file system events. If multiple events happen
    // consecutively all within a certain duration, then they are
    // bunched up without a recompile in-between. This helps against
    // some editors' remove & move behavior. Events are also only
    // watched until a certain point, to hinder a barrage of events from
    // preventing recompilations.
    let mut relevant = false
    let batch_start = @platform.monotonic_nanos()
    for ;; {
      // `first.into_iter().chain(iter::from_fn(..)).take_while(..)`
      let event = match first {
        Some(event) => {
          first = None
          event
        }
        None =>
          match self.rx.recv_timeout(Some(BATCH_TIMEOUT)) {
            Some(event) => event
            None => break
          }
      }
      if @platform.monotonic_nanos() - batch_start >
        STARVE_TIMEOUT.to_int64() * 1000000L {
        break
      }
      let event = match event {
        Ok(event) => event
        Err(err) => raise @kit.StrError("failed to watch dependencies (\{err})")
      }
      if !is_relevant_event_kind(event.kind) {
        continue
      }

      // Workaround for notify-rs' implicit unwatch on remove/rename
      // (triggered by some editors when saving files) with the
      // inotify backend. By keeping track of the potentially
      // unwatched files, we can allow those we still depend on to be
      // watched again later on.
      //
      // (`notify.mbt` reports every removal this way: see there.)
      if event.kind is (Remove(File) | Modify(Name(From))) {
        for path in event.paths {
          // Remove affected path from the watched map to restart
          // watching on it later again.
          self.watcher.unwatch(path)
          self.watched.remove(path)
        }
      }

      // Don't recompile because the output file changed.
      // FIXME: This doesn't work properly for multifile image export.
      if self.output is Some(output) &&
        event.paths.iter().all(path => is_same_file(path, output)) {
        continue
      }
      relevant = true
    }

    // If we found a relevant event or if any of the missing files now
    // exists, stop waiting.
    if relevant || self.missing.keys().any(path => @platform.exists(path)) {
      return
    }
  }
}

///|
/// Whether two paths refer to the same file (the `same-file` crate's
/// `is_same_file(..).unwrap_or(false)`: `false` if either cannot be
/// opened).
fn is_same_file(path1 : String, path2 : String) -> Bool {
  @platform.is_same_file(path1, path2) catch {
    _ => false
  }
}

///|
/// Whether a kind of watch event is relevant for compilation.
fn is_relevant_event_kind(kind : EventKind) -> Bool {
  match kind {
    Any => true
    Access(_) => false
    Create(_) => true
    Modify(kind) =>
      match kind {
        Any => true
        Data(_) => true
        Metadata(_) => false
        Name(_) => true
        Other => false
      }
    Remove(_) => true
    Other => false
  }
}
