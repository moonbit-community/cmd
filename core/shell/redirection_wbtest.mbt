///|
async test "ordered output redirections preserve every filesystem effect" {
  let root = @fs.tmpdir(prefix="cmd-sh-redirect-")
  defer @fs.rmdir(root, recursive=true)
  @fs.write_file(root + "/first", "old")
  assert_eq(
    capture("printf final > first > second; > empty", cwd=root),
    (0, ""),
  )
  assert_eq(@fs.read_file(root + "/first").binary(), b"")
  assert_eq(@fs.read_file(root + "/second").binary(), b"final")
  assert_eq(@fs.read_file(root + "/empty").binary(), b"")
  assert_eq(capture("printf plus 1>> second", cwd=root), (0, ""))
  assert_eq(@fs.read_file(root + "/second").binary(), b"finalplus")
}

///|
async test "an early redirection failure prevents later open and command effects" {
  let root = @fs.tmpdir(prefix="cmd-sh-redirect-fail-")
  defer @fs.rmdir(root, recursive=true)
  let output : ShellTestOutput = { bytes: [], }
  let errors : ShellTestOutput = { bytes: [], }
  let session = Session::new(cwd=root, output~, error=errors)
  assert_eq(session.feed("printf wrong > missing/file > later"), Completed(2))
  assert_eq(output.text(), "")
  assert_false(@fs.exists(root + "/later"))
  assert_false(errors.bytes.is_empty())
  assert_eq(session.feed("printf recovered"), Completed(0))
  assert_eq(output.text(), "recovered")
}

///|
async test "stdout stderr duplication retains the destination at each operation" {
  let root = @fs.tmpdir(prefix="cmd-sh-copy-")
  defer @fs.rmdir(root, recursive=true)
  let script = "f() { printf out; printf err >&2; }; f > first 2>&1; f 2>&1 > second"
  assert_eq(capture(script, cwd=root), (0, "err"))
  assert_eq(@fs.read_file(root + "/first").binary(), b"outerr")
  assert_eq(@fs.read_file(root + "/second").binary(), b"out")
  let output : ShellTestOutput = { bytes: [], }
  let errors : ShellTestOutput = { bytes: [], }
  let session = Session::new(cwd=root, output~, error=errors)
  assert_eq(session.feed("printf redirected 1>&2; printf normal"), Completed(0))
  assert_eq(output.text(), "normal")
  assert_eq(errors.text(), "redirected")
  assert_eq(
    session.feed("printf reverse 1<&2; printf copied 2<&1"),
    Completed(0),
  )
  assert_eq(output.text(), "normalcopied")
  assert_eq(errors.text(), "redirectedreverse")
}

///|
async test "ordered input redirections use the final input and restore the session" {
  let root = @fs.tmpdir(prefix="cmd-sh-input-")
  defer @fs.rmdir(root, recursive=true)
  @fs.write_file(root + "/first", "old\n")
  @fs.write_file(root + "/second", "new\n")
  assert_eq(
    capture("read value 0< first < second; printf '%s' \"$value\"", cwd=root),
    (0, "new"),
  )
  let reader = @io.MemoryReader(writer => writer.write("input\n"))
  defer reader.close()
  let output : ShellTestOutput = { bytes: [], }
  let session = Session::new(input=reader, output~)
  assert_eq(
    session.feed("read value 0<&0; printf '%s' \"$value\""),
    Completed(0),
  )
  assert_eq(output.text(), "input")
}

///|
async test "all redirect targets expand before opens and assignments wait for success" {
  let root = @fs.tmpdir(prefix="cmd-sh-redirect-expand-")
  defer @fs.rmdir(root, recursive=true)
  let output : ShellTestOutput = { bytes: [], }
  let errors : ShellTestOutput = { bytes: [], }
  let session = Session::new(cwd=root, env={}, output~, error=errors)
  assert_eq(
    session.feed(
      "a=1; b=$((a=5)) printf wrong > missing/file; printf '|%s|%s' \"$a\" \"${b-unset}\"",
    ),
    Completed(0),
  )
  assert_eq(output.text(), "|1|unset")
  output.bytes.clear()
  assert_eq(
    session.feed(
      "a=1; printf wrong > missing/file >$((a=7)); printf '|%s' \"$a\"",
    ),
    Completed(0),
  )
  assert_eq(output.text(), "|7")
  assert_false(@fs.exists(root + "/7"))
  @fs.write_file(root + "/first", "sentinel")
  assert_eq(session.feed("printf wrong > first >$((1/0))"), Exit(2))
  assert_eq(@fs.read_file(root + "/first").binary(), b"sentinel")
}

///|
async test "special builtin redirect failure stops the script with status two" {
  let root = @fs.tmpdir(prefix="cmd-sh-redirect-special-")
  defer @fs.rmdir(root, recursive=true)
  let output : ShellTestOutput = { bytes: [], }
  let errors : ShellTestOutput = { bytes: [], }
  let session = Session::new(cwd=root, env={}, output~, error=errors)
  assert_eq(session.feed(": > missing/file; printf wrong"), Exit(2))
  assert_eq(output.text(), "")
  assert_false(errors.bytes.is_empty())
}
