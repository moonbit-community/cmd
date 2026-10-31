///|
fn patterned_bytes(length : Int32) -> Bytes {
  let data : Array[Byte] = []
  for index = 0; index < length; index = index + 1 {
    data.push((index & 0xFF).to_byte())
  }
  Bytes::from_array(data)
}

///|
/// These checks compose real command processes. Single-command text contracts
/// live in tests/cases; the child executable is intentionally the built command.
async fn run_text_process_composition_cases(
  bin_root : String,
  failures : Array[String],
) -> Unit {
  let root = @fs.tmpdir(prefix="mooncmd-text-composition")
  defer cleanup_compat_fixture(root)
  let find = @testkit.run_command(
    bin_root,
    "find",
    [
      root,
      "-maxdepth",
      "0",
      "-exec",
      ..@testkit.command_line(bin_root, "false", []),
      ";",
    ],
  )
  record_result(
    find.status == 0 && find.stdout.is_empty() && find.stderr.is_empty(),
    "find: -exec false must not turn a successful traversal into status 1",
    failures,
  )
  let printf = @testkit.command_line(bin_root, "printf", [])
  let batched_find = @testkit.run_command(
    bin_root,
    "find",
    [root, "-maxdepth", "0", "-exec", ..printf, "%s\\n", "{}", "+"],
  )
  record_result(
    batched_find.status == 0 &&
    batched_find.stderr.is_empty() &&
    @testkit.bytes_equal(batched_find.stdout, @utf8.encode(root + "\n")),
    "find: -exec ... + batching mismatch",
    failures,
  )
  let xargs_cases : Array[(String, Array[String], Bytes, Int32, Bytes)] = [
    (
      "replace-lines",
      ["-I{}", ..printf, "<%s>\\n", "{}"],
      b"first line\nsecond line\n",
      0,
      b"<first line>\n<second line>\n",
    ),
    (
      "line-limit",
      ["-L", "1", ..printf, "[%s]\\n"],
      b"a b\nc d\n",
      0,
      b"[a]\n[b]\n[c]\n[d]\n",
    ),
    (
      "eof-marker",
      ["-E", "STOP", ..printf, "[%s]\\n"],
      b"a STOP b\n",
      0,
      b"[a]\n",
    ),
    (
      "child-failure",
      [..@testkit.command_line(bin_root, "false", [])],
      b"value\n",
      123,
      b"",
    ),
  ]
  for (name, args, input, status, output) in xargs_cases {
    let result = @testkit.run_command(bin_root, "xargs", args, stdin=input)
    record_result(
      result.status == status &&
      result.stdout == output &&
      result.stderr.is_empty(),
      "xargs: composed \{name} status/output mismatch",
      failures,
    )
  }
  let work = @path.Path(root).join(Path("work")).to_string()
  @fs.mkdir(work)
  let env = @testkit.run_command(
    bin_root,
    "env",
    ["-C", work, ..@testkit.command_line(bin_root, "printenv", []), "PHASE345"],
    extra_env=Map([("PHASE345", "visible")]),
  )
  record_result(
    env.status == 0 &&
    env.stderr.is_empty() &&
    @testkit.bytes_equal(env.stdout, b"visible\n"),
    "env: -C child execution mismatch",
    failures,
  )
  let repeated_cwd = @testkit.run_command(
    bin_root,
    "env",
    ["-C", work, "-C", ".", ..@testkit.command_line(bin_root, "pwd", [])],
  )
  let current = @fs.realpath(".")
  record_result(
    repeated_cwd.status == 0 &&
    repeated_cwd.stderr.is_empty() &&
    @testkit.bytes_equal(repeated_cwd.stdout, @utf8.encode(current + "\n")),
    "env: repeated -C must resolve the last directory from the original cwd",
    failures,
  )
}

///|
/// Check both sides of the lifecycle transition: still running before cancel,
/// then a reaped hard-cancel outcome rather than ordinary successful exit.
async fn observe_sleep_cancellation(
  program : String,
  args : Array[String],
) -> Bool {
  @async.with_task_group <| group => {
    let child = @process.spawn(
      group,
      program,
      args,
      cancel_handler=@process.hard_cancel(),
      no_console_window=true,
      no_wait=true,
    )
    @async.sleep(100)
    let pending_before_cancel = child.try_wait() is None
    child.cancel()
    let terminal : Ref[Int32?] = Ref(None)
    wait_for_direct_child("sleep cancellation", () => {
      let status = child.wait()
      terminal.val = Some(status)
      status
    })
    guard pending_before_cancel && terminal.val is Some(status) else {
      return false
    }
    child.try_wait() == Some(status) &&
    (if @async.platform is Windows { status != 0 } else { status == -9 })
  }
}

///|
/// Cancellation is a lifecycle interaction, not a one-shot command contract.
async fn run_sleep_cancel_case(
  bin_root : String,
  failures : Array[String],
) -> Unit {
  let sleep_cancelled = observe_sleep_cancellation(
    @testkit.command_program(),
    @testkit.command_args(bin_root, "sleep", ["60"]),
  )
  record_result(
    sleep_cancelled, "sleep: expected a pending child followed by a reaped hard-cancel status",
    failures,
  )
}
