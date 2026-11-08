///|
async test "POSIX trailing separators require directories for every file predicate" {
  guard !(@async.platform is Windows) else { return }
  let root = @fs.tmpdir(prefix="cmd-sh-test-directory-suffix-")
  defer @fs.rmdir(root, recursive=true)
  @fs.write_file(root + "/known", "data")
  @fs.mkdir(root + "/directory")
  @fs.symlink(root + "/file-link", target="known")
  @fs.symlink(root + "/directory-link", target="directory")
  @fs.symlink(root + "/dangling", target="missing")
  let errors : ShellTestOutput = { bytes: [], }
  let session = Session::new(cwd=root, env={}, error=errors)
  for
    value in [
      "known/", "known//", "file-link/", "file-link//", "dangling/", "known/../known",
      "file-link/../known",
    ] {
    assert_eq(test_mtime(value, session.context), None)
    for
      operator in [
        "-e", "-f", "-d", "-b", "-c", "-p", "-S", "-L", "-h", "-r", "-w", "-x", "-s",
      ] {
      assert_eq(
        run_builtin(["test", operator, value], session.context),
        Some(1),
        msg="test \{operator} '\{value}'",
      )
    }
    for operator in ["-nt", "-ot"] {
      assert_eq(
        run_builtin(["test", value, operator, "known"], session.context),
        Some(1),
        msg="invalid left timestamp operand: \{value}",
      )
      assert_eq(
        run_builtin(["test", "known", operator, value], session.context),
        Some(1),
        msg="invalid right timestamp operand: \{value}",
      )
    }
  }
  for
    value in [
      "directory/", "directory//", "directory-link/", "directory-link//",
    ] {
    for operator in ["-d", "-e"] {
      assert_eq(
        run_builtin(["test", operator, value], session.context),
        Some(0),
      )
    }
    for operator in ["-f", "-L", "-h"] {
      assert_eq(
        run_builtin(["test", operator, value], session.context),
        Some(1),
      )
    }
    assert_eq(
      test_mtime(value, session.context),
      Some(@fs.mtime(root + "/directory")),
    )
  }
  assert_eq(run_builtin(["test", "-f", "file-link"], session.context), Some(0))
  assert_eq(run_builtin(["test", "-L", "file-link"], session.context), Some(0))
  assert_eq(
    run_builtin(["test", "-L", "directory-link"], session.context),
    Some(0),
  )
  assert_eq(errors.text(), "")
}

///|
async test "test file predicates preserve empty paths missing components and not-directory errors" {
  let root = @fs.tmpdir(prefix="cmd-sh-test-")
  defer @fs.rmdir(root, recursive=true)
  @fs.write_file(root + "/known", "data")
  @fs.mkdir(root + "/directory")
  let errors : ShellTestOutput = { bytes: [], }
  let session = Session::new(cwd=root, env={}, error=errors)
  let invalid_paths = ["", "missing", "known/child"]
  if !(@async.platform is Windows) {
    invalid_paths.append(["missing/../known", "known/../known"])
  }
  for value in invalid_paths {
    for
      operator in [
        "-e", "-f", "-d", "-b", "-c", "-p", "-S", "-L", "-h", "-r", "-w", "-x", "-s",
      ] {
      let actual = run_builtin(["test", operator, value], session.context)
      assert_true(
        actual == Some(1),
        msg="expected false: test \{operator} '\{value}'",
      )
    }
    for operator in ["-nt", "-ot"] {
      assert_eq(
        run_builtin(["test", value, operator, "known"], session.context),
        Some(1),
      )
      assert_eq(
        run_builtin(["test", "known", operator, value], session.context),
        Some(1),
      )
    }
  }
  assert_eq(errors.text(), "")
  assert_eq(run_builtin(["test", "-f", "known"], session.context), Some(0))
  assert_eq(run_builtin(["test", "-d", "directory"], session.context), Some(0))
  assert_eq(
    run_builtin(["test", "known", "-nt", "known"], session.context),
    Some(1),
  )
}

///|
async test "Windows file predicates retain the host normalized parent-component profile" {
  guard @async.platform is Windows else { return }
  let root = @fs.tmpdir(prefix="cmd-sh-windows-path-")
  defer @fs.rmdir(root, recursive=true)
  @fs.write_file(root + "/known", "data")
  // This external observer only establishes the native Windows path contract.
  // The product still passes raw paths to the public MoonBit filesystem API.
  let (status, output) = @async.with_timeout(10000, () => {
    @async_process.collect_stdout(
      "powershell.exe",
      [
        "-NoProfile", "-NonInteractive", "-Command", "$ErrorActionPreference = 'Stop'; $r = $env:MOONCMD_SHELL_PATH_ROOT; [Console]::Write(([IO.File]::Exists($r + '/missing/../known')).ToString() + '|' + [IO.File]::ReadAllText($r + '/missing/../known') + '|' + ([IO.File]::Exists($r + '/known/child')).ToString() + '|' + ([IO.File]::Exists($r + '/missing')).ToString())",
      ],
      extra_env=Map([("MOONCMD_SHELL_PATH_ROOT", root)]),
    )
  }) catch {
    error => fail("required Windows path observer failed: \{error}")
  }
  assert_eq(status, 0)
  assert_eq(output.text(), "True|data|False|False")
  let errors : ShellTestOutput = { bytes: [], }
  let session = Session::new(cwd=root, env={}, error=errors)
  for value in ["missing/../known", "known/../known"] {
    for operator in ["-e", "-f", "-s"] {
      assert_eq(
        run_builtin(["test", operator, value], session.context),
        Some(0),
      )
    }
    for operator in ["-d", "-b", "-c", "-p", "-S", "-L", "-h"] {
      assert_eq(
        run_builtin(["test", operator, value], session.context),
        Some(1),
      )
    }
    for operator in ["-nt", "-ot"] {
      assert_eq(
        run_builtin(["test", value, operator, "known"], session.context),
        Some(1),
      )
    }
  }
  assert_eq(errors.text(), "")
}

///|
async test "test argument count precedence negation and errors match fixed dash examples" {
  for
    (args, status) in [
      ([], 1),
      (["!"], 0),
      (["!", "!"], 1),
      (["!", "!", "!"], 0),
      (["!", "!", "!", "!"], 0),
      (["!", "!", "-n", "foo"], 1),
      (["!", "!", "(", ")"], 0),
      (["!", "!", "!", "foo"], 0),
      (["!", "=", "!"], 0),
      (["(", "!", "=", "!", ")"], 2),
      (["x", "-a", "!", "=", "!"], 2),
      (["(", "=", "("], 0),
      (["x", "-a", "(", "=", "("], 2),
      (["x", "-a", "-n", "=", "-n"], 0),
      (["x", "-a", "-n"], 0),
      (["x", "-a", "-n", "="], 0),
      (["x", "-a"], 1),
      (["", "-o"], 1),
      (["(", "x", "-a", ")"], 1),
      (["(", "-a", ")"], 0),
      (["x", "-o", "bad", "-eq", "1"], 2),
      (["", "-a", "bad", "-eq", "1"], 2),
      (["x", "-o", "", "-a", ""], 0),
      (["𐀀", "<", "\uE000"], 1),
    ] {
    let errors : ShellTestOutput = { bytes: [], }
    let session = Session::new(env={}, error=errors)
    assert_eq(run_builtin(["test"] + args, session.context), Some(status))
    assert_eq(errors.bytes.is_empty(), status != 2)
  }
}

///|
async test "test integers are signed decimal with C whitespace and checked range" {
  for
    (left, right, status) in [
      ("010", "10", 0),
      ("+010", "10", 0),
      ("0x10", "16", 2),
      ("0o10", "8", 2),
      ("0b10", "2", 2),
      ("1_0", "10", 2),
      ("\u000b10\u000b", "10", 0),
      ("\u000c10\u000c", "10", 0),
      ("\u00a010\u00a0", "10", 2),
      (" ", "0", 2),
      ("", "0", 2),
      ("-9223372036854775808", "-9223372036854775808", 0),
      ("9223372036854775807", "9223372036854775807", 0),
      ("9223372036854775808", "0", 2),
    ] {
    let errors : ShellTestOutput = { bytes: [], }
    let session = Session::new(env={}, error=errors)
    assert_eq(
      run_builtin(["test", left, "-eq", right], session.context),
      Some(status),
    )
    assert_eq(errors.bytes.is_empty(), status != 2)
  }
}

///|
async test "test status and diagnostic do not discard prior output or poison a session" {
  let output : ShellTestOutput = { bytes: [], }
  let errors : ShellTestOutput = { bytes: [], }
  let session = Session::new(env={}, output~, error=errors)
  assert_eq(session.feed("printf before; test bad -eq 1"), Completed(2))
  assert_eq(output.text(), "before")
  assert_eq(errors.text(), "sh: test: integer expected\n")
  assert_eq(session.feed("[ x = x ]; printf '%s' \"$?\""), Completed(0))
  assert_eq(output.text(), "before0")
  assert_eq(session.feed("[ x = x"), Completed(2))
  assert_eq(session.feed("test x == x"), Completed(0))
}
