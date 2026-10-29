///|
async test "native: file system" {
  let root = @fs.tmpdir(prefix="rg-original-native-fs-")
  defer @fs.rmdir(root, recursive=true)
  fs_roundtrip(root)
  // Link text/identity cannot be inferred from a successful canonical lookup.
  assert_true(
    try {
      ignore(@sys.read_link(root + "/link"))
      false
    } catch {
      @sys.IOError(kind=Unsupported, ..) => true
      _ => false
    },
  )
  if !(@async.platform is Windows) {
    @sys.symlink("a.txt", root + "/link")
    assert_eq(@sys.symlink_metadata(root + "/link").file_type, Symlink)
    assert_eq(@sys.metadata(root + "/link").len, 12L)
    assert_eq(@sys.read_file(root + "/link"), b"hello\nworld\n")
  }
  @sys.remove_file(root + "/t.txt")
  assert_false(@sys.path_exists(root + "/t.txt"))
}

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
