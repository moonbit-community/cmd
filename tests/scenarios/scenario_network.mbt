///|
fn workspace_network_executor(
  root : String,
  proof? : @harness.ScenarioProof,
) -> @network.Executor {
  {
    proof,
    invoke: invocation => {
      let program = @harness.command_program()
      let args = @harness.command_args(
        root,
        invocation.command,
        invocation.args,
      )
      {
        run: @harness.run_with_deadline(
          program,
          args,
          15000,
          stdin=invocation.stdin,
          cwd=invocation.cwd,
          extra_env=invocation.environment,
        ),
        source_version: if @harness.published_mode() {
          args[0]
        } else {
          @harness.wasm_path(root, invocation.command)
        },
        program,
        args,
        infrastructure_error: None,
        retain_identity: false,
      }
    },
  }
}

///|
async fn network_transfer_scenario(
  root : String,
  work : String,
  oracle_image? : String,
  proof? : @harness.ScenarioProof,
) -> Unit {
  @network.run(
    "network-transfer-boundaries",
    workspace_network_executor(root, proof?),
    work,
    oracle_image?,
  )
}

///|
async fn network_cli_scenario(
  root : String,
  work : String,
  oracle_image? : String,
  proof? : @harness.ScenarioProof,
) -> Unit {
  @network.run(
    "network-auth-cookie",
    workspace_network_executor(root, proof?),
    work,
    oracle_image?,
  )
}
