///|
/// Observation adapter for the unmodified fixed ripgrep integration harness.
async fn main {
  let wasm = @env.get_env_var("RG_WASM_PATH").unwrap()
  let args = [wasm, "--", ..@env.args()[1:]]
  let status = @process.run(
    "moonrun",
    args,
    stdin=@stdio.stdin,
    stdout=@stdio.stdout,
    stderr=@stdio.stderr,
  )
  @sys.exit(status)
}
