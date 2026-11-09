///|
fn workspace_network_executor(root : String) -> @network.Executor {
  {
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
        retain_identity: true,
      }
    },
  }
}

///|
async fn network_curl_transfers_scenario(
  root : String,
  work : String,
  corpus~ : String,
  oracle_image? : String,
) -> Unit {
  @network.run(
    "network-" + corpus,
    workspace_network_executor(root),
    work,
    oracle_image?,
  )
}

///|
async fn network_cookie_domains_scenario(
  root : String,
  work : String,
  tool~ : String,
  oracle_image? : String,
) -> Unit {
  @network.run(
    "network-" + tool + "-cookie-domains",
    workspace_network_executor(root),
    work,
    oracle_image?,
  )
}

///|
async fn network_wget_cookies_scenario(
  root : String,
  work : String,
  oracle_image? : String,
  corpus~ : String = "wget-cookies",
) -> Unit {
  @network.run(
    "network-" + corpus,
    workspace_network_executor(root),
    work,
    oracle_image?,
  )
}

///|
async fn network_wget_authentication_scenario(
  root : String,
  work : String,
  oracle_image? : String,
) -> Unit {
  @network.run(
    "network-wget-authentication",
    workspace_network_executor(root),
    work,
    oracle_image?,
  )
}

///|
async fn network_idna_scenario(
  root : String,
  work : String,
  oracle_image? : String,
) -> Unit {
  @network.run(
    "network-idna",
    workspace_network_executor(root),
    work,
    oracle_image?,
  )
}

///|
async fn network_cookie_suffix_scenario(
  root : String,
  work : String,
  oracle_image? : String,
) -> Unit {
  @network.run(
    "network-cookie-suffix",
    workspace_network_executor(root),
    work,
    oracle_image?,
  )
}

///|
async fn network_transfer_scenario(
  root : String,
  work : String,
  oracle_image? : String,
) -> Unit {
  @network.run(
    "network-transfer-boundaries",
    workspace_network_executor(root),
    work,
    oracle_image?,
  )
}

///|
async fn network_cli_scenario(
  root : String,
  work : String,
  oracle_image? : String,
) -> Unit {
  @network.run(
    "network-auth-cookie",
    workspace_network_executor(root),
    work,
    oracle_image?,
  )
}
