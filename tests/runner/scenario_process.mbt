///|
async fn process_lifecycle_scenario(
  root : String,
  wasm : Bool,
  work : String,
) -> Unit {
  let helper = @fs.realpath(@env.args()[0])
  let env = scenario_run(
    work,
    root,
    wasm,
    "env",
    [helper, "--test-helper", "environment", "CMD_INHERITED"],
    stdin=b"",
    extra_env={ "CMD_INHERITED": "retained" },
  )
  assert_eq(env.status, 0)
  assert_eq(env.stdout, b"retained\n")
  assert_eq(env.stderr, b"")
  for value in ["C", "POSIX"] {
    let locale = scenario_run(
      work,
      root,
      wasm,
      "env",
      [helper, "--test-helper", "environment", "LC_ALL"],
      stdin=b"",
      extra_env={ "LC_ALL": value },
    )
    assert_eq(locale.status, 0)
    assert_eq(locale.stdout, @utf8.encode(value + "\n"))
    assert_eq(locale.stderr, b"")
  }
  let command = shell_quote(helper) + " --test-helper environment LOCAL"
  let exported = scenario_run(
    work,
    root,
    wasm,
    "sh",
    ["-c", "LOCAL=secret; " + command + "; export LOCAL; " + command],
    stdin=b"",
    cwd=work,
  )
  assert_eq(exported.status, 0)
  assert_eq(exported.stdout, b"\nsecret\n")
  assert_eq(exported.stderr, b"")
  let cancelled = @async.with_timeout_opt(5, () => {
    @async.sleep(60000)
    "unexpected"
  })
  assert_eq(cancelled, None)
  let continuing = scenario_run(work, root, wasm, "true", [], stdin=b"")
  assert_eq(continuing.status, 0)
  let deadline = @testkit.run_with_deadline(
    helper,
    ["--test-helper", "capture-then-wait"],
    1000,
  )
  assert_true(deadline.timed_out)
  assert_eq(deadline.output.stdout, b"partial stdout\n")
  assert_eq(deadline.output.stderr, b"partial stderr\n")
  assert_eq(deadline.cleanup_error, None)
  let status_124 = @testkit.run_with_deadline(
    helper,
    ["--test-helper", "status-124"],
    15000,
    stdin=@utf8.encode("x".repeat(100000)),
  )
  assert_false(status_124.timed_out)
  assert_eq(status_124.output.status, 124)
  assert_eq(status_124.cleanup_error, None)
  @async.with_task_group(group => {
    let (reader, output) = @process.read_from_process()
    defer reader.close()
    let child = @process.spawn(
      group,
      helper,
      ["--test-helper", "wait-ready"],
      stdout=output,
      cancel_handler=@process.hard_cancel(),
    )
    assert_eq(reader.read_until("\n"), Some("ready"))
    child.cancel()
    let first = @async.protect_from_cancel(() => child.wait())
    assert_eq(child.wait(), first)
    assert_eq(reader.read_all().binary(), b"")
  })
}
