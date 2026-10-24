///|
async test "tee classifies real public pipe errors separately from regular file errors" {
  let (read, write) = @pipe.pipe()
  defer write.close()
  read.close()
  try write.write(b"x") catch {
    error =>
      if !pipe_error(error) {
        let code = match error {
          @os_error.OSError(code, ..) => code
          _ => -1
        }
        fail("unclassified public pipe error: code=\{code}, \{error}")
      }
  } noraise {
    _ => fail("closed pipe write must fail")
  }
  let root = @fs.tmpdir(prefix="mooncmd-tee-errors")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  @fs.write_file(root + "/file", b"kept")
  let file = @fs.open(root + "/file", mode=ReadOnly)
  defer file.close()
  try file.write(b"x") catch {
    error => assert_false(pipe_error(error))
  } noraise {
    _ => fail("readonly file must reject writes")
  }
}

///|
async test "tee error modes preserve later sinks after a closed output pipe" {
  let root = @fs.tmpdir(prefix="mooncmd-tee-modes")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  for
    (mode, expected_status, expected) in [
      (Traditional, 2, b""),
      (Warn, 1, b"abc"),
      (WarnNoPipe, 0, b"abc"),
      (Exit, 1, b""),
      (ExitNoPipe, 0, b"abc"),
    ] {
    let (read, broken) = @pipe.pipe()
    read.close()
    let output = @fs.open(
      root + "/sink",
      mode=WriteOnly,
      create_mode=CreateOrTruncate,
    )
    let input = @io.MemoryReader(writer => writer.write(b"abc"))
    let status = transfer(
      input,
      [
        { name: "standard output", writer: broken, active: true, },
        { name: "sink", writer: output, active: true, },
      ],
      mode,
    )
    input.close()
    broken.close()
    output.close()
    assert_eq(status, expected_status)
    assert_eq(@fs.read_file(root + "/sink").binary(), expected)
  }
  @fs.write_file(root + "/readonly", b"kept")
  for
    (mode, expected) in [
      (Traditional, b"abc"),
      (Warn, b"abc"),
      (WarnNoPipe, b"abc"),
      (Exit, b""),
      (ExitNoPipe, b""),
    ] {
    let protected_file = @fs.open(root + "/readonly", mode=ReadOnly)
    let output = @fs.open(
      root + "/sink",
      mode=WriteOnly,
      create_mode=CreateOrTruncate,
    )
    let input = @io.MemoryReader(writer => writer.write(b"abc"))
    let status = transfer(
      input,
      [
        { name: "readonly", writer: protected_file, active: true, },
        { name: "sink", writer: output, active: true, },
      ],
      mode,
    )
    input.close()
    protected_file.close()
    output.close()
    assert_eq(status, 1)
    assert_eq(@fs.read_file(root + "/sink").binary(), expected)
    assert_eq(@fs.read_file(root + "/readonly").binary(), b"kept")
  }
}
