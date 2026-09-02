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
priv enum EnvironmentPolicy {
  NativeCompatible
  WasmRestricted
} derive(Eq)

///|
fn environment_with_policy(
  source : Map[String, String],
  policy : EnvironmentPolicy,
  windows? : Bool = false,
) -> Map[String, String] {
  let result : Map[String, String] = Map([])
  for name, value in source {
    if policy == NativeCompatible || allowed_environment_name(name, windows) {
      result[name] = value
    }
  }
  if policy == WasmRestricted {
    // Keep policy-controlled child text classification deterministic.
    result["LC_ALL"] = "C"
    result["LANG"] = "C"
  }
  result
}

///|
#cfg(target="native")
pub fn default_environment() -> Map[String, String] {
  environment_with_policy(@env.get_env_vars(), NativeCompatible)
}

///|
#cfg(not(target="native"))
pub fn default_environment() -> Map[String, String] {
  environment_with_policy(@env.get_env_vars(), WasmRestricted)
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
/// POSIX command-launch outcomes shared by the upstream `env`, `xargs`, and
/// `timeout` contracts. Diagnostic wording remains command-owned.
pub(all) enum LaunchFailure {
  CommandNotFound
  CommandNotInvokable
} derive(Eq, Debug)

///|
pub fn launch_failure_status(failure : LaunchFailure) -> Int {
  match failure {
    CommandNotFound => 127
    CommandNotInvokable => 126
  }
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
