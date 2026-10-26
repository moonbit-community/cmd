///|
let messages_enabled : Ref[Bool] = Ref(false)

///|
let ignore_messages_enabled : Ref[Bool] = Ref(false)

///|
let errored_flag : Ref[Bool] = Ref(false)

///|
/// The log level: 0 = warn (default), 1 = debug, 2 = trace.
let log_level : Ref[Int32] = Ref(0)

///|
/// Writes a line to stderr prefixed with `rg: `. If writing fails, the
/// process exits (with 0 on a broken pipe, like ripgrep).
pub async fn eprintln_locked(msg : String) -> Unit {
  // Messages may contain OS strings (paths); display them lossily, like
  // Rust's `Path::display`.
  let bytes = @utf8.encode("rg: " + @osstr.to_lossy(msg) + "\n").to_fixedarray()
  @sys.write_fd(2, bytes, 0, bytes.length()) catch {
    e =>
      if @sys.from_error(e).kind() is BrokenPipe {
        @sys.exit(0)
      } else {
        @sys.exit(2)
      }
  }
}

///|
pub fn messages() -> Bool {
  messages_enabled.val
}

///|
pub fn set_messages(yes : Bool) -> Unit {
  messages_enabled.val = yes
}

///|
pub fn ignore_messages() -> Bool {
  ignore_messages_enabled.val
}

///|
pub fn set_ignore_messages(yes : Bool) -> Unit {
  ignore_messages_enabled.val = yes
}

///|
pub fn errored() -> Bool {
  errored_flag.val
}

///|
pub fn set_errored() -> Unit {
  errored_flag.val = true
}

///|
/// Emits a non-fatal message if messages are enabled.
pub async fn message(msg : String) -> Unit {
  if messages() {
    eprintln_locked(msg)
  }
}

///|
/// Emits an error message and records that an error occurred.
pub async fn err_message(msg : String) -> Unit {
  set_errored()
  message(msg)
}

///|
/// Emits a message about ignore files, if enabled.
pub async fn ignore_message(msg : String) -> Unit {
  if messages() && ignore_messages() {
    eprintln_locked(msg)
  }
}

///|
/// Emits a debug log message (shown with --debug or --trace).
pub async fn log_debug(target : String, msg : String) -> Unit {
  if log_level.val >= 1 {
    eprintln_locked_raw("DEBUG|\{target}|\{msg}")
  }
}

///|
/// Emits a trace log message (shown with --trace).
pub async fn log_trace(target : String, msg : String) -> Unit {
  if log_level.val >= 2 {
    eprintln_locked_raw("TRACE|\{target}|\{msg}")
  }
}

///|
async fn eprintln_locked_raw(msg : String) -> Unit {
  eprintln_locked(msg)
}
