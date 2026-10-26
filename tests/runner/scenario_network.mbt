///|
fn workspace_network_executor(
  root : String,
  wasm : Bool,
) -> @network_scenarios.Executor {
  {
    invoke: invocation => {
      let program = @testkit.command_program()
      let args = @testkit.command_args(
        root,
        invocation.command,
        invocation.args,
      )
      {
        run: @testkit.run_with_deadline(
          program,
          args,
          15000,
          stdin=invocation.stdin,
          cwd=invocation.cwd,
          extra_env=invocation.environment,
        ),
        source_version: if wasm {
          @testkit.wasm_path(root, invocation.command)
        } else {
          program
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
  wasm : Bool,
  work : String,
  oracle_image? : String,
) -> Unit {
  @network_scenarios.run(
    "network-transfer-boundaries",
    workspace_network_executor(root, wasm),
    work,
    oracle_image?,
  )
}

///|
async fn network_cli_scenario(
  root : String,
  wasm : Bool,
  work : String,
  oracle_image? : String,
) -> Unit {
  @network_scenarios.run(
    "network-auth-cookie",
    workspace_network_executor(root, wasm),
    work,
    oracle_image?,
  )
}
