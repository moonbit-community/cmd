///|
async fn check_split_filter_process_policy(
  root : String,
  failures : Array[String],
) -> Unit {
  let args = @harness.expand_args(
    ["-b", "1", "--filter=${PRINTENV_CHILD} FILE"],
    root,
  )
  let policy_name = "runtime-split-filter-process.json"
  let policy_path = root_path(root, "tests/fixtures/policy/" + policy_name)
  let policy : Map[String, Json] = { "fs": { "read": [Json(root)] } }
  @fs.write_file(policy_path, Json::object(policy).stringify())
  defer @fs.remove(policy_path)
  let denied = moon_run(root, policy_name, "split", args, stdin=b"x") catch {
    error => {
      failures.push("split: denied filter invocation failed: \{error}")
      return
    }
  }
  record(
    denied.status != 0 &&
    denied.stdout.is_empty() &&
    @harness.contains_bytes(denied.stderr, "blocked process"),
    "split: filter must report host process denial (status=\{denied.status}, stdout=\{denied.stdout}, stderr=\{denied.stderr})",
    failures,
  )
  policy["process"] = {
    "allow": [
      {
        "program": Json(@harness.option_child_path()),
        "args_prefix": ["--option-test-helper", "printenv", "FILE"],
      },
    ],
  }
  @fs.write_file(policy_path, Json::object(policy).stringify())
  let allowed = moon_run(root, policy_name, "split", args, stdin=b"x") catch {
    error => {
      failures.push("split: allowed filter invocation failed: \{error}")
      return
    }
  }
  record(
    stdout_is(allowed, b"xaa\n") && allowed.stderr.is_empty(),
    "split: allowed filter must run the external child with FILE (status=\{allowed.status}, stdout=\{allowed.stdout}, stderr=\{allowed.stderr})",
    failures,
  )
}

///|
async fn check_process_and_network_policy(
  root : String,
  failures : Array[String],
) -> Unit {
  let makefile_rel = "tests/fixtures/policy/make-runner-fixture"
  let makefile = root_path(root, makefile_rel)
  @fs.write_file(makefile, b".PHONY: all\nall:\n\t@printf policy-make-ok\n")
  defer (@fs.remove(makefile) catch { _ => () })
  check_split_filter_process_policy(root, failures)
  let env_setup = moon_run(root, "deny-all.json", "env", ["-C"]) catch {
    err => {
      failures.push("env: status-125 setup case failed to run: \{err}")
      return
    }
  }
  record(
    env_setup.status == 125,
    "env: Wasm setup failure must return 125",
    failures,
  )
  let env_denied = moon_run(root, "read-workspace.json", "env", [
    "echo", "denied",
  ]) catch {
    err => {
      failures.push("env: status-126 denial case failed to run: \{err}")
      return
    }
  }
  record(
    env_denied.status == 126,
    "env: denied Wasm child must return 126",
    failures,
  )
  let env_missing = moon_run(root, "process-missing.json", "env", [
    "mooncmd-command-that-does-not-exist",
  ]) catch {
    err => {
      failures.push("env: status-127 lookup case failed to run: \{err}")
      return
    }
  }
  record(
    env_missing.status == 127,
    "env: missing Wasm child must return 127",
    failures,
  )
  expect_denied(
    root,
    "read-workspace.json",
    "env",
    ["-i", "echo", "denied"],
    None,
    failures,
  )
  expect_denied(
    root,
    "process-echo.json",
    "env",
    ["-C", "tests/fixtures/policy", "echo", "denied-cwd"],
    None,
    failures,
  )
  expect_denied(
    root,
    "read-workspace.json",
    "xargs",
    ["-n", "1", "echo"],
    Some(b"denied\n"),
    failures,
  )
  let find = moon_run(root, "read-workspace.json", "find", [
    "tests/fixtures/policy", "-maxdepth", "1", "-type", "f", "-print",
  ]) catch {
    err => {
      failures.push("find: allowed metadata traversal failed: \{err}")
      return
    }
  }
  record(
    find.status == 0 &&
    @harness.contains_bytes(find.stdout, "process-echo.json"),
    "find: allowed metadata traversal mismatch",
    failures,
  )
  expect_denied(
    root,
    "read-workspace.json",
    "find",
    ["tests/fixtures/policy", "-maxdepth", "1", "-exec", "echo", "{}", ";"],
    None,
    failures,
  )
  expect_denied(
    root,
    "read-workspace.json",
    "find",
    ["tests/fixtures/policy", "-maxdepth", "1", "-type", "f", "-delete"],
    None,
    failures,
  )
  expect_denied(
    root,
    "read-workspace.json",
    "timeout",
    ["1s", "echo", "denied"],
    None,
    failures,
  )
  expect_denied(
    root,
    "read-workspace.json",
    "sh",
    ["-c", "printenv CMD_PROCESS_DENIAL"],
    None,
    failures,
  )
  // printf is now interpreted locally and needs no process permission.
  // Exercise an actual external command for the process-denial assertion.
  @fs.write_file(
    makefile, b".PHONY: all\nall:\n\t@printenv CMD_PROCESS_DENIAL\n",
  )
  expect_denied(
    root,
    "read-workspace.json",
    "make",
    ["-s", "-f", makefile_rel],
    None,
    failures,
  )
  @fs.write_file(makefile, b".PHONY: all\nall:\n\t@printf policy-make-ok\n")
  let env = moon_run(root, "process-echo.json", "env", [
    "-i", "echo", "process-policy-ok",
  ]) catch {
    err => {
      failures.push("env: allowed process failed: \{err}")
      return
    }
  }
  record(
    stdout_is(env, b"process-policy-ok\n"),
    "env: allowed process output mismatch",
    failures,
  )
  let env_cwd = moon_run(root, "process-echo-cwd.json", "env", [
    "-C", "tests/fixtures/policy", "echo", "cwd-policy-ok",
  ]) catch {
    err => {
      failures.push("env: allowed cwd process failed: \{err}")
      return
    }
  }
  record(
    stdout_is(env_cwd, b"cwd-policy-ok\n"),
    "env: -C must use the policy-visible child working directory",
    failures,
  )
  let xargs = moon_run(
    root,
    "process-echo.json",
    "xargs",
    ["-n", "1", "echo"],
    stdin=b"one two\n",
  ) catch {
    err => {
      failures.push("xargs: allowed process failed: \{err}")
      return
    }
  }
  record(
    stdout_is(xargs, b"one\ntwo\n"),
    "xargs: allowed process output mismatch",
    failures,
  )
  let xargs_parallel = moon_run(
    root,
    "process-echo.json",
    "xargs",
    ["-P", "2", "-n", "1", "echo"],
    stdin=b"parallel-one parallel-two\n",
  ) catch {
    err => {
      failures.push("xargs: bounded parallel process failed: \{err}")
      return
    }
  }
  record(
    xargs_parallel.status == 0 &&
    @harness.contains_bytes(xargs_parallel.stdout, "parallel-one") &&
    @harness.contains_bytes(xargs_parallel.stdout, "parallel-two"),
    "xargs: bounded parallel output mismatch",
    failures,
  )
  let find_exec = moon_run(root, "process-echo-cwd.json", "find", [
    "tests/fixtures/policy", "-maxdepth", "0", "-exec", "echo", "{}", ";",
  ]) catch {
    err => {
      failures.push("find: allowed child process failed: \{err}")
      return
    }
  }
  record(
    find_exec.status == 0 && @harness.contains_bytes(find_exec.stdout, "policy"),
    "find: allowed child output mismatch: status=\{find_exec.status}, stdout=\{find_exec.stdout}, stderr=\{find_exec.stderr}",
    failures,
  )
  if @harness.command_available("timeout") {
    let timeout = moon_run(root, "process-echo.json", "timeout", [
      "1s", "echo", "timeout-policy-ok",
    ]) catch {
      err => {
        failures.push("timeout: allowed process failed: \{err}")
        return
      }
    }
    record(
      stdout_is(timeout, b"timeout-policy-ok\n"),
      "timeout: allowed process output mismatch",
      failures,
    )
  }
  let sh = moon_run(root, "process-printf.json", "sh", [
    "-c", "printf '%s' \"$(printf policy-shell-ok)\"",
  ]) catch {
    err => {
      failures.push("sh: allowed process failed: \{err}")
      return
    }
  }
  record(
    stdout_is(sh, b"policy-shell-ok"),
    "sh: allowed process output mismatch: status=\{sh.status}, stdout=\{sh.stdout}, stderr=\{sh.stderr}",
    failures,
  )
  let make = moon_run(root, "process-printf.json", "make", [
    "-s", "-f", makefile_rel,
  ]) catch {
    err => {
      failures.push("make: allowed process failed: \{err}")
      return
    }
  }
  record(
    stdout_is(make, b"policy-make-ok"),
    "make: allowed process output mismatch: status=\{make.status}, stdout=\{make.stdout}, stderr=\{make.stderr}",
    failures,
  )
  expect_denied(
    root,
    "net-deny.json",
    "curl",
    ["http://127.0.0.1:1/"],
    None,
    failures,
  )
  expect_denied(
    root,
    "net-deny.json",
    "wget",
    ["http://127.0.0.1:1/"],
    None,
    failures,
  )
}
