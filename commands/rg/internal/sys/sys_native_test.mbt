///|
test "native: process info" {
  let time = @sys.now_nanos()
  assert_true(@sys.now_nanos() >= time)
  assert_eq(@sys.env_var("PATH"), @env.get_env_var("PATH"))
  assert_true(@sys.is_tty(1) is Unavailable(_))
}

///|
async test "native: run_command" {
  let root = @fs.tmpdir(prefix="rg-original-process-")
  defer @fs.rmdir(root, recursive=true)
  let output = @sys.run_command("moon", fixture_args(root, "status"))
  assert_eq(output.status, 3)
  assert_eq(output.stdout, b"out\n")
  assert_eq(output.stderr, b"err\n")
  @sys.write_file(root + "/input", b"from file\n")
  let output = @sys.run_command(
    "moon",
    fixture_args(root, "copy"),
    stdin_path=root + "/input",
  )
  assert_eq(output.status, 0)
  assert_eq(output.stdout, b"from file\n")
  let output = @sys.run_command("moon", fixture_args(root, "duplex"))
  assert_eq(output.status, 0)
  assert_eq(output.stdout.length(), 2000 * 41)
  assert_eq(output.stderr.length(), 2000 * 42)
  assert_true(
    try {
      ignore(@sys.run_command("rg-missing-program-20261026", []))
      false
    } catch {
      _ => true
    },
  )
}

///|
async test "native: Process streams output and can stop early" {
  let root = @fs.tmpdir(prefix="rg-original-early-close-")
  defer @fs.rmdir(root, recursive=true)
  let child = @sys.Process::spawn("moon", fixture_args(root, "stream"))
  let chunk = FixedArray::make(8, b'\x00')
  assert_true(child.read(chunk, 0, 8) > 0)
  assert_eq(chunk[0], b'f')
  let (status, _) = child.finish()
  assert_true(status != 0)
  ignore(child.finish())
}
