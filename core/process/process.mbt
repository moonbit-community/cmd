///|
fn allowed_environment_name(name : String, windows : Bool) -> Bool {
  let normalized = if windows { name.to_upper() } else { name }
  match normalized {
    "PATH" | "HOME" | "TMPDIR" | "TMP" | "TEMP" => true
    "LANG" | "LC_ALL" => true
    "SYSTEMROOT"
    | "WINDIR"
    | "SYSTEMDRIVE"
    | "COMSPEC"
    | "PATHEXT"
    | "USERPROFILE"
    | "HOMEDRIVE"
    | "HOMEPATH" => windows
    _ => false
  }
}

///|
fn sanitize_environment(source : Map[String, String]) -> Map[String, String] {
  let result : Map[String, String] = Map([])
  let windows = @platform.is_windows()
  for name, value in source {
    if allowed_environment_name(name, windows) {
      result[name] = value
    }
  }
  // Keep child text classification deterministic even when the host locale is not.
  result["LC_ALL"] = "C"
  result["LANG"] = "C"
  result
}

///|
pub fn default_environment() -> Map[String, String] {
  sanitize_environment(@env.get_env_vars())
}

///|
pub(all) struct ExecutionContext {
  cwd : String
  env : Map[String, String]
}

///|
pub fn ExecutionContext::current() -> ExecutionContext {
  { cwd: @env.current_dir().unwrap_or("."), env: default_environment(), }
}

///|
pub(all) struct ChildSpec {
  program : String
  args : Array[String]
  context : ExecutionContext
}

///|
pub fn child(
  program : String,
  args : Array[String],
  context? : ExecutionContext = ExecutionContext::current(),
) -> ChildSpec {
  { program, args, context, }
}

///|
pub async fn run(
  spec : ChildSpec,
  stdin? : &@async_process.ProcessInput,
  stdout? : &@async_process.ProcessOutput,
  stderr? : &@async_process.ProcessOutput,
) -> Int {
  @async_process.run(
    spec.program,
    spec.args,
    extra_env=spec.context.env,
    inherit_env=false,
    stdin?,
    stdout?,
    stderr?,
    cwd=spec.context.cwd,
    no_console_window=true,
    cancel_handler=@async_process.hard_cancel(),
  )
}

///|
pub async fn redirect_from_file(path : String) -> &@async_process.ProcessInput {
  @async_process.redirect_from_file(path)
}

///|
pub async fn redirect_to_file(
  path : String,
  append? : Bool = false,
) -> &@async_process.ProcessOutput {
  @async_process.redirect_to_file(path, append~)
}

///|
pub fn pipe() -> (&@async_process.ProcessInput, &@async_process.ProcessOutput) raise {
  @async_process.pipe()
}
