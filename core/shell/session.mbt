///|
/// A persistent shell session. Each feed owns exactly the supplied source;
/// the session never reads command source from its command-input reader.
struct Session {
  context : Context
  pending : StringBuilder
  interactive : Bool
  mut finished : Bool
}

///|
pub(all) enum SessionResult {
  NeedMoreInput
  Completed(Int)
  Exit(Int)
} derive(Eq, Debug)

///|
pub fn Session::new(
  name? : String = "sh",
  args? : Array[String] = [],
  env? : Map[String, String] = @child_process.default_environment(),
  cwd? : String,
  input? : &@io.Reader,
  output? : &@io.Writer,
  error? : &@io.Writer,
  interactive? : Bool = false,
) -> Session {
  let cwd = cwd.unwrap_or(@env.current_dir().unwrap_or("."))
  let variables = Map(env.to_array())
  variables["PWD"] = cwd
  let exported = Set(env.keys().collect())
  exported.add("PWD")
  let context : Context = {
    env: variables,
    exported,
    positional: args.copy(),
    name,
    cwd,
    last_status: 0,
    exited: false,
    exit_status: 0,
    capture: None,
    input,
    output,
    error,
    functions: Map([]),
    errexit: false,
    nounset: false,
    return_status: None,
    break_loop: false,
    continue_loop: false,
    loop_depth: 0,
    call_depth: 0,
    substitution_status: None,
    expansion_failed: false,
  }
  { context, pending: StringBuilder(), interactive, finished: false, }
}

///|
fn incomplete(message : String) -> Bool {
  message.has_prefix("incomplete:") ||
  message.has_prefix("unterminated") ||
  message == "script ends with an unmatched backslash" ||
  message == "here-document must start on a new line"
}

///|
pub async fn Session::feed(self : Session, source : String) -> SessionResult {
  if self.finished || self.context.exited {
    return Exit(self.context.exit_status)
  }
  self.context.expansion_failed = false
  self.pending.write_string(source)
  let text = self.pending.to_string()
  if text.has_suffix("\\\n") {
    return NeedMoreInput
  }
  let jobs = parse(text) catch {
    ShellError(message) => {
      if incomplete(message) {
        return NeedMoreInput
      }
      self.pending.reset()
      self.context.last_status = 2
      raise ShellError(message)
    }
  }
  self.pending.reset()
  errdefer {
    self.context.last_status = 2
  }
  let status = run_jobs(jobs, self.context)
  if self.context.exited {
    if self.interactive && self.context.expansion_failed {
      self.context.exited = false
    } else {
      return Exit(self.context.exit_status)
    }
  }
  Completed(status)
}

///|
/// Kept async to share the session driver contract with feed and future IO cleanup.
#warnings("-unused_async")
pub async fn Session::finish(self : Session) -> SessionResult {
  if self.finished {
    return Exit(self.context.last_status)
  }
  if !self.pending.is_empty() {
    self.pending.reset()
    self.context.last_status = 2
    self.finished = true
    raise ShellError("unexpected end of input")
  }
  self.finished = true
  Exit(
    if self.context.exited {
      self.context.exit_status
    } else {
      self.context.last_status
    },
  )
}

///|
pub fn Session::prompt(self : Session, continuation? : Bool = false) -> String {
  self.context.env
  .get(if continuation { "PS2" } else { "PS1" })
  .unwrap_or(if continuation { "> " } else { "$ " })
}

///|
/// Evaluate ENV only for explicitly interactive sessions, without word
/// splitting or pathname expansion. Script execution never loads ENV.
pub async fn Session::load_startup(self : Session) -> Unit {
  if !self.interactive {
    return
  }
  if self.context.env.get("ENV") is Some(value) && value != "" {
    let filename = expand_startup_path(value, self.context)
    if filename != "" {
      let source = @fs.read_file(resolve_path(self.context, filename)).text()
      ignore(run_jobs(parse(source), self.context))
    }
  }
}

///|
/// Read one physical line without prefetching bytes from a foreground child's
/// input. A partial final line is returned before EOF.
pub async fn read_line(input : &@io.Reader) -> String? {
  let bytes : Array[Byte] = []
  let buffer : FixedArray[Byte] = FixedArray::make(1, 0)
  for ;; {
    if input.read(buffer, max_len=1) == 0 {
      return if bytes.is_empty() {
        None
      } else {
        Some(@utf8.decode(Bytes::from_array(bytes)))
      }
    }
    bytes.push(buffer[0])
    if buffer[0] == b'\n' {
      return Some(@utf8.decode(Bytes::from_array(bytes)))
    }
  }
}

///|
pub async fn run(
  script : String,
  name? : String = "sh",
  args? : Array[String] = [],
  env? : Map[String, String] = @child_process.default_environment(),
  cwd? : String,
) -> Int {
  let session = Session::new(name~, args~, env~, cwd?)
  match session.feed(script) {
    Exit(status) => status
    Completed(status) => status
    NeedMoreInput => {
      ignore(session.finish())
      2
    }
  }
}

///|
/// Run shell source and capture stdout for callers such as make's $(shell).
/// Stderr remains a separate stream and the shell exit status is returned.
pub async fn capture(
  script : String,
  name? : String = "sh",
  args? : Array[String] = [],
  env? : Map[String, String] = @child_process.default_environment(),
  cwd? : String,
) -> (Int, String) {
  let session = Session::new(name~, args~, env~, cwd?)
  run_substitution(script, session.context)
}

///|
pub extend SessionResult with Eq::{not_equal, equal}

///|
pub extend SessionResult with @debug.Debug::{to_repr}
