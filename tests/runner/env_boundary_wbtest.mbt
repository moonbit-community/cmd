///|
async test "Windows Native env rejects empty child environments before launch" {
  if !@platform.is_windows() {
    return
  }
  let root = workspace_root()
  let helper = root +
    "/_build/native/release/build/mooxCLI/cmd-tests/runner/runner.exe"
  let marker = b"visible-child\n"
  let child = @testkit.run_with_deadline(
    helper,
    ["--option-test-helper", "printf", "visible-child\\n"],
    15000,
    stdin=b"",
    cwd=root,
    inherit_env=true,
  )
  assert_false(child.timed_out)
  assert_eq(child.cleanup_error, None)
  assert_eq(child.output.status, 0)
  assert_eq(child.output.stdout, marker)
  assert_eq(child.output.stderr, b"")
  let program = @testkit.executable_path(root, "env")
  let rejected = @testkit.run_with_deadline(
    program,
    ["-i", helper, "--option-test-helper", "printf", "visible-child\\n"],
    15000,
    stdin=b"",
    cwd=root,
    inherit_env=true,
  )
  assert_false(rejected.timed_out)
  assert_eq(rejected.cleanup_error, None)
  assert_eq(rejected.output.status, 125)
  assert_eq(rejected.output.stdout, b"")
  assert_eq(
    rejected.output.stderr,
    b"env: unsupported capability: Windows Native empty child environment\n",
  )
  let assigned = @testkit.run_with_deadline(
    program,
    [
      "-i", "O13_TEST=child", helper, "--option-test-helper", "printf", "visible-child\\n",
    ],
    15000,
    stdin=b"",
    cwd=root,
    inherit_env=true,
  )
  assert_false(assigned.timed_out)
  assert_eq(assigned.cleanup_error, None)
  assert_eq(assigned.output.status, 0)
  assert_eq(assigned.output.stdout, marker)
  assert_eq(assigned.output.stderr, b"")
  let listed = @testkit.run_with_deadline(
    program,
    ["-i"],
    15000,
    stdin=b"",
    cwd=root,
    inherit_env=true,
  )
  assert_false(listed.timed_out)
  assert_eq(listed.cleanup_error, None)
  assert_eq(listed.output.status, 0)
  assert_eq(listed.output.stdout, b"")
  assert_eq(listed.output.stderr, b"")
}
