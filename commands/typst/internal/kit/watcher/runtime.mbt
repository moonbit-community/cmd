// The event loop a `Watcher` runs on. Not upstream: notify delivers its
// events from a thread of its own, `@fs.Watcher` from tasks of
// `moonbitlang/async`'s event loop, so whoever watches has to run on that
// loop.

///|
/// The tasks of a [`run`]: where a [`Watcher`]'s event sources live.
pub type Tasks = @async.TaskGroup[Unit]

///|
/// Runs `f` in a task group on the caller's event loop.
/// The tasks it is given are the ones to create a [`Watcher`] with; they end
/// with `f`.
///
/// Work between waits (a compilation) is synchronous and is not interrupted
/// by the loop. Errors propagate to the caller.
pub async fn run(f : async (Tasks) -> Unit) -> Unit {
  // By default the runtime blocks SIGINT, SIGTERM and SIGHUP and turns them
  // into a cancellation of the main task, which it only delivers when that
  // task waits: a compilation would have to finish first. Leave them alone,
  // so that they end the process at once like they end upstream's.
  @signal.set_global_cancellation_signals([])
  // With nothing to watch (`typst watch` of standard input), waiting never
  // ends, which is what upstream does too. The runtime calls that a
  // deadlock and panics unless told otherwise.
  @async.set_deadlock_handler(_ => ())
  // kqueue needs an open file per watched file (and directory), and the
  // default limit of macOS is 256. (notify's FSEvents backend needs none.)
  @platform.raise_fd_limit()
  // Reuse the caller's event loop rather than nesting run_async_main.
  @async.with_task_group(group => f(group))
}
