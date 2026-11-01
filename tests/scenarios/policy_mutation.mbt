///|
async fn check_mutation_policy(root : String, failures : Array[String]) -> Unit {
  let fixture_rel = "tests/fixtures/policy/write-fixture-runner"
  let fixture = root_path(root, fixture_rel)
  @fs.rmdir(fixture, recursive=true) catch {
    _ => ()
  }
  @fs.mkdir(fixture, recursive=true)
  defer (@fs.rmdir(fixture, recursive=true) catch { _ => () })
  @fs.mkdir(root_path(fixture, "empty-dir"))
  @fs.write_file(root_path(fixture, "source"), b"policy-fixture\n")
  @fs.write_file(root_path(fixture, "backup-target"), b"old-target\n")
  @fs.write_file(root_path(fixture, "movable"), b"move-me\n")
  @fs.write_file(root_path(fixture, "removable"), b"remove-me\n")
  expect_denied(
    root,
    "read-workspace.json",
    "mkdir",
    [fixture_rel + "/denied-dir"],
    None,
    failures,
  )
  expect_denied(
    root,
    "deny-all.json",
    "chmod",
    ["a=rwx", fixture_rel + "/source"],
    None,
    failures,
  )
  expect_denied(
    root,
    "read-workspace.json",
    "touch",
    [fixture_rel + "/denied-touch"],
    None,
    failures,
  )
  expect_denied(
    root,
    "read-workspace.json",
    "tee",
    [fixture_rel + "/denied-tee"],
    Some(b"tee-input\n"),
    failures,
  )
  expect_denied(
    root,
    "read-workspace.json",
    "cp",
    [
      "--no-preserve=mode",
      fixture_rel + "/source",
      fixture_rel + "/denied-copy",
    ],
    None,
    failures,
  )
  expect_denied(
    root,
    "read-workspace.json",
    "mv",
    [fixture_rel + "/movable", fixture_rel + "/denied-move"],
    None,
    failures,
  )
  expect_denied(
    root,
    "read-workspace.json",
    "rm",
    [fixture_rel + "/removable"],
    None,
    failures,
  )
  expect_denied(
    root,
    "read-workspace.json",
    "rmdir",
    [fixture_rel + "/empty-dir"],
    None,
    failures,
  )
  expect_denied(
    root,
    "read-workspace.json",
    "ln",
    ["-s", fixture_rel + "/source", fixture_rel + "/denied-link"],
    None,
    failures,
  )
  for
    denied_path in [
      "denied-dir", "denied-touch", "denied-tee", "denied-copy", "denied-move", "denied-link",
    ] {
    record(
      !@fs.exists(root_path(fixture, denied_path)),
      "\{denied_path}: denied operation left a side effect",
      failures,
    )
  }
  record(
    @fs.read_file(root_path(fixture, "backup-target")).binary() ==
    b"old-target\n" &&
    !@fs.exists(root_path(fixture, "backup-target.~1~")),
    "cp backup: denied operation changed target or left a backup",
    failures,
  )
  for preserved in ["movable", "removable", "empty-dir"] {
    record(
      @fs.exists(root_path(fixture, preserved)),
      "\{preserved}: denied operation removed fixture",
      failures,
    )
  }
  let policy = "read-write-policy.json"
  let mkdir = moon_run(root, policy, "mkdir", [fixture_rel + "/allowed-dir"]) catch {
    err => {
      failures.push("mkdir: allowed mutation failed: \{err}")
      return
    }
  }
  record(mkdir.status == 0, "mkdir: write policy rejected mutation", failures)
  let touch = moon_run(root, policy, "touch", [fixture_rel + "/allowed-touch"]) catch {
    err => {
      failures.push("touch: allowed mutation failed: \{err}")
      return
    }
  }
  record(touch.status == 0, "touch: write policy rejected mutation", failures)
  let tee = moon_run(
    root,
    policy,
    "tee",
    [fixture_rel + "/allowed-tee"],
    stdin=b"policy-fixture\n",
  ) catch {
    err => {
      failures.push("tee: allowed mutation failed: \{err}")
      return
    }
  }
  record(
    stdout_is(tee, b"policy-fixture\n"),
    "tee: write policy output mismatch",
    failures,
  )
  let cp = moon_run(root, policy, "cp", [
    "--no-preserve=mode",
    fixture_rel + "/source",
    fixture_rel + "/allowed-copy",
  ]) catch {
    err => {
      failures.push("cp: allowed mutation failed: \{err}")
      return
    }
  }
  record(cp.status == 0, "cp: write policy rejected mutation", failures)
  let cp_backup = moon_run(root, policy, "cp", [
    "--no-preserve=mode",
    "--backup=numbered",
    fixture_rel + "/source",
    fixture_rel + "/backup-target",
  ]) catch {
    err => {
      failures.push("cp backup: allowed mutation failed: \{err}")
      return
    }
  }
  record(
    cp_backup.status != 0 &&
    @harness.contains_bytes(cp_backup.stderr, "identity"),
    "cp backup: missing implementation must be distinguished from authorization",
    failures,
  )
  record(
    !@fs.exists(root_path(fixture, "backup-target.~1~")) &&
    @fs.read_file(root_path(fixture, "backup-target")).binary() ==
    b"old-target\n",
    "cp backup: unsupported overwrite must preserve target and avoid backup mutation",
    failures,
  )
  let chmod = moon_run(root, policy, "chmod", ["a=rwx", fixture_rel + "/source"]) catch {
    err => {
      failures.push("chmod: allowed mutation failed: \{err}")
      return
    }
  }
  if @platform.permission_mutation_supported() {
    record(chmod.status == 0, "chmod: write policy rejected mutation", failures)
  } else {
    record(
      chmod.status != 0 &&
      @harness.contains_bytes(chmod.stderr, "unsupported capability"),
      "chmod: unsupported capability was not reported",
      failures,
    )
    record(
      @fs.read_file(root_path(fixture, "source")).text() == "policy-fixture\n",
      "chmod: unsupported operation changed fixture contents",
      failures,
    )
  }
  let mv = moon_run(root, policy, "mv", [
    fixture_rel + "/movable",
    fixture_rel + "/allowed-move",
  ]) catch {
    err => {
      failures.push("mv: allowed mutation failed: \{err}")
      return
    }
  }
  record(mv.status == 0, "mv: write policy rejected mutation", failures)
  if @platform.symbolic_link_creation_supported() {
    let ln = moon_run(root, policy, "ln", [
      root_path(fixture, "source"),
      root_path(fixture, "allowed-link"),
      "-s",
    ]) catch {
      err => {
        failures.push("ln: allowed mutation failed: \{err}")
        return
      }
    }
    record(ln.status == 0, "ln: write policy rejected mutation", failures)
    record(
      @fs.exists(root_path(fixture, "allowed-link")),
      "ln: allowed symbolic link missing",
      failures,
    )
  } else {
    let ln = moon_run(root, policy, "ln", [
      "-s",
      fixture_rel + "/source",
      fixture_rel + "/allowed-link",
    ]) catch {
      err => {
        failures.push("ln: unsupported capability check failed: \{err}")
        return
      }
    }
    record(
      ln.status != 0 &&
      @harness.contains_bytes(ln.stderr, "unsupported capability"),
      "ln: Windows must return stable unsupported capability",
      failures,
    )
  }
  let rm = moon_run(root, policy, "rm", [fixture_rel + "/removable"]) catch {
    err => {
      failures.push("rm: allowed mutation failed: \{err}")
      return
    }
  }
  record(rm.status == 0, "rm: write policy rejected mutation", failures)
  let rmdir = moon_run(root, policy, "rmdir", [fixture_rel + "/empty-dir"]) catch {
    err => {
      failures.push("rmdir: allowed mutation failed: \{err}")
      return
    }
  }
  record(rmdir.status == 0, "rmdir: write policy rejected mutation", failures)
  for
    expected in [
      "allowed-dir", "allowed-touch", "allowed-tee", "allowed-copy", "allowed-move",
    ] {
    record(
      @fs.exists(root_path(fixture, expected)),
      "\{expected}: allowed mutation result missing",
      failures,
    )
  }
  for removed in ["movable", "removable", "empty-dir"] {
    record(
      !@fs.exists(root_path(fixture, removed)),
      "\{removed}: allowed removal did not take effect",
      failures,
    )
  }
  record(
    @fs.read_file(root_path(fixture, "allowed-copy")).text() ==
    "policy-fixture\n",
    "cp: copied content mismatch",
    failures,
  )
}
