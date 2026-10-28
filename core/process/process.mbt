///|
/// Inherit the environment made available by the host. Commands apply only
/// their own env/export semantics; authorization belongs to the host.
pub fn default_environment() -> Map[String, String] {
  @env.get_env_vars()
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
pub fn launch_failure_status(failure : LaunchFailure) -> Int32 {
  match failure {
    CommandNotFound => 127
    CommandNotInvokable => 126
  }
}

///|
pub fn child(
  program : String,
  args : Array[String],
  context~ : ExecutionContext = ExecutionContext::current(),
) -> ChildSpec {
  { program, args, context, }
}

///|
pub async fn run(
  spec : ChildSpec,
  stdin? : &@async_process.ProcessInput,
  stdout? : &@async_process.ProcessOutput,
  stderr? : &@async_process.ProcessOutput,
) -> Int32 {
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
pub extend LaunchFailure with Eq::{not_equal, equal}

///|
pub extend LaunchFailure with @debug.Debug::{to_repr}
