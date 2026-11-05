// File system watching on the targets without `moonbitlang/async`'s
// `@fs.Watcher` (wasm-gc, js): there is no `Watcher` here.

///|
/// Why this build cannot watch files. `Watcher` and `run` only exist on the
/// native and wasm targets.
pub let unsupported : String = "no file system events"
