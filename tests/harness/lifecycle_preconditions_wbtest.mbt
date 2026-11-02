///|
async fn require_lifecycle_observers(paths : ArrayView[String]) -> Unit {
  for path in paths {
    guard @fs.exists(path) else {
      fail("lifecycle prerequisite unavailable: required observer " + path)
    }
  }
}

///|
fn require_lifecycle_unprivileged_user(identity : RunResult) -> Unit raise {
  guard identity.status == 0 else {
    fail(
      "lifecycle prerequisite unavailable: cannot identify cleanup fault user",
    )
  }
  let uid = @string.parse_int(@utf8.decode(identity.stdout).trim().to_owned()) catch {
    _ =>
      fail("lifecycle prerequisite unavailable: invalid cleanup fault user ID")
  }
  guard uid > 0 else {
    fail(
      "lifecycle prerequisite unavailable: cleanup permission fault requires a non-root user",
    )
  }
}

///|
async test "missing lifecycle observers fail before fixture execution" {
  let root = @fs.tmpdir(prefix="mooncmd-lifecycle-precondition-")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let marker = root + "/fixture-executed"
  try {
    require_lifecycle_observers([root + "/missing-observer"])
    @fs.write_file(marker, "must not execute")
  } catch {
    error => {
      assert_true(
        error.to_string().contains("lifecycle prerequisite unavailable"),
      )
      assert_true(error.to_string().contains("missing-observer"))
    }
  } noraise {
    _ => fail("a missing lifecycle observer must not certify the test")
  }
  assert_false(@fs.exists(marker))
}

///|
test "root and unavailable user observations cannot certify cleanup permission faults" {
  for
    identity in [
      { status: 0, stdout: b"0\n", stderr: b"", },
      { status: 1, stdout: b"501\n", stderr: b"observer failure", },
      { status: 0, stdout: b"unknown\n", stderr: b"", },
    ] {
    try require_lifecycle_unprivileged_user(identity) catch {
      error =>
        assert_true(
          error.to_string().contains("lifecycle prerequisite unavailable"),
        )
    } noraise {
      _ => fail("an unavailable permission fault must not certify cleanup")
    }
  }
  require_lifecycle_unprivileged_user({
    status: 0,
    stdout: b"501\n",
    stderr: b"",
  })
}
