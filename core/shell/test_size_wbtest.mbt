///|
async test "test size follows final links and rejects broken and cyclic targets" {
  let root = @fs.tmpdir(prefix="cmd-sh-size-links-")
  defer @fs.rmdir(root, recursive=true)
  @fs.write_file(root + "/empty", "")
  @fs.write_file(root + "/full", "payload")
  for
    (name, target) in [
      ("empty-link", "empty"),
      ("full-link", "full"),
      ("empty-chain", "empty-link"),
      ("full-chain", "full-link"),
      ("absolute-empty", root + "/empty"),
      ("absolute-full", root + "/full"),
      ("dangling", "missing"),
      ("cycle", "cycle"),
      ("cycle-a", "cycle-b"),
      ("cycle-b", "cycle-a"),
    ] {
    @fs.symlink(root + "/" + name, target~, force_symlink=true)
  }
  let errors : ShellTestOutput = { bytes: [], }
  let session = Session::new(cwd=root, env={}, error=errors)
  for
    (name, status) in [
      ("empty", 1),
      ("full", 0),
      ("empty-link", 1),
      ("full-link", 0),
      ("empty-chain", 1),
      ("full-chain", 0),
      ("absolute-empty", 1),
      ("absolute-full", 0),
      ("dangling", 1),
      ("cycle", 1),
      ("cycle-a", 1),
    ] {
    assert_eq(
      @async.with_timeout(2000, () => {
        run_builtin(["test", "-s", name], session.context)
      }),
      Some(status),
      msg=name,
    )
  }
  for name in ["empty-link", "dangling", "cycle", "cycle-a"] {
    assert_eq(run_builtin(["test", "-L", name], session.context), Some(0))
  }
  assert_eq(errors.text(), "")
}

///|
async test "test size preserves POSIX intermediate symlinks before parent components" {
  guard !(@async.platform is Windows) else { return }
  let root = @fs.tmpdir(prefix="cmd-sh-size-parent-")
  defer @fs.rmdir(root, recursive=true)
  @fs.mkdir(root + "/real/nested", recursive=true)
  @fs.write_file(root + "/marker", "")
  @fs.write_file(root + "/real/marker", "payload")
  @fs.symlink(root + "/alias", target="real/nested")
  @fs.symlink(root + "/file-link", target="real/marker")
  let errors : ShellTestOutput = { bytes: [], }
  let session = Session::new(cwd=root, env={}, error=errors)
  assert_eq(
    run_builtin(["test", "-s", "alias/../marker"], session.context),
    Some(0),
  )
  for
    name in [
      "missing/../real/marker", "marker/../real/marker", "real/marker/", "file-link/",
    ] {
    assert_eq(run_builtin(["test", "-s", name], session.context), Some(1))
  }
  assert_eq(errors.text(), "")
}

///|
async test "test size uses metadata without opening an unreadable regular file" {
  guard !(@async.platform is Windows) else { return }
  let root = @fs.tmpdir(prefix="cmd-sh-size-permissions-")
  defer @fs.rmdir(root, recursive=true)
  let path = root + "/opaque"
  @fs.write_file(path, "payload")
  @fs.chmod(path, 0)
  defer @async.protect_from_cancel(() => @fs.chmod(path, 0o600))
  assert_false(@fs.can_read(path), msg="unreadable-file precondition")
  let errors : ShellTestOutput = { bytes: [], }
  let session = Session::new(cwd=root, env={}, error=errors)
  assert_eq(run_builtin(["test", "-s", "opaque"], session.context), Some(0))
  assert_eq(errors.text(), "")
}

///|
async test "test size preserves directory capability errors through expressions and sessions" {
  let root = @fs.tmpdir(prefix="cmd-sh-size-directory-")
  defer @fs.rmdir(root, recursive=true)
  @fs.mkdir(root + "/directory")
  @fs.symlink(root + "/link", target="directory", force_symlink=true)
  let available = try @fs.file_size(root + "/directory") catch {
    @os_error.OSError(code, ..) if code == @os_error.errno_ENOTSUP => None
    error => raise error
  } noraise {
    size => Some(size)
  }
  for name in ["directory", "link"] {
    let errors : ShellTestOutput = { bytes: [], }
    let session = Session::new(cwd=root, env={}, error=errors)
    match available {
      Some(size) => {
        assert_eq(
          run_builtin(["test", "-s", name], session.context),
          Some(if size > 0L { 0 } else { 1 }),
        )
        assert_eq(errors.text(), "")
      }
      None => {
        for
          args in [
            ["test", "-s", name],
            ["test", "!", "-s", name],
            ["test", "x", "-o", "-s", name],
            ["test", "", "-a", "-s", name],
          ] {
          assert_eq(run_builtin(args, session.context), Some(2))
        }
        let message = "sh: test: '-s' target size is unavailable through the public filesystem API: '" +
          name +
          "'\n"
        assert_eq(errors.text(), message.repeat(4))
        let output : ShellTestOutput = { bytes: [], }
        let errors : ShellTestOutput = { bytes: [], }
        let session = Session::new(cwd=root, env={}, output~, error=errors)
        assert_eq(
          session.feed(
            "printf before; test -s " + name + "; printf '|%s|after' $?\n",
          ),
          Completed(0),
        )
        assert_eq(output.text(), "before|2|after")
        assert_eq(errors.text(), message)
      }
    }
  }
}
