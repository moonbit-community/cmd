///|
let policy_wasm_root : Ref[String] = Ref("")

///|
async fn moon_run(
  root : String,
  policy : String,
  command : String,
  args : Array[String],
  stdin? : Bytes,
) -> @harness.RunResult {
  let policy_path = @path.Path(root)
    .join(Path("tests/fixtures/policy"))
    .join(Path(policy))
    .to_string()
  let moon_args = @harness.command_args(
    policy_wasm_root.val,
    command,
    [],
    policy=policy_path,
  )
  let resolved_args : Array[String] = []
  for arg in args {
    if arg.has_prefix("tests/") {
      resolved_args.push(root_path(root, arg))
    } else {
      resolved_args.push(arg)
    }
  }
  moon_args.append(resolved_args)
  @harness.run(@harness.command_program(), moon_args, stdin?, cwd=root)
}

///|
fn root_path(root : String, relative : String) -> String {
  @path.Path(root).join(Path(relative)).to_string()
}

///|
fn denied(result : @harness.RunResult) -> Bool {
  result.status != 0 && result.stderr.length() > 0
}

///|
fn stdout_is(result : @harness.RunResult, expected : Bytes) -> Bool {
  result.status == 0 && @harness.bytes_equal(result.stdout, expected)
}

///|
fn record(condition : Bool, message : String, failures : Array[String]) -> Unit {
  if !condition {
    failures.push(message)
  }
}
