///|
let policy_wasm_root : Ref[String] = Ref("")

///|
async fn moon_run(
  root : String,
  policy : String,
  command : String,
  args : Array[String],
  stdin? : Bytes,
) -> @testkit.RunResult {
  let policy_path = @path.Path(root)
    .join(Path("tests/fixtures/policy"))
    .join(Path(policy))
    .to_string()
  let moon_args = [
    "--policy",
    policy_path,
    @testkit.wasm_path(policy_wasm_root.val, command),
  ]
  let resolved_args : Array[String] = []
  for arg in args {
    if arg.has_prefix("tests/") {
      resolved_args.push(root_path(root, arg))
    } else {
      resolved_args.push(arg)
    }
  }
  moon_args.append(resolved_args)
  @testkit.run("moonrun", moon_args, stdin?, cwd=root)
}

///|
fn root_path(root : String, relative : String) -> String {
  @path.Path(root).join(Path(relative)).to_string()
}

///|
fn denied(result : @testkit.RunResult) -> Bool {
  result.status != 0 && result.stderr.length() > 0
}

///|
fn stdout_is(result : @testkit.RunResult, expected : Bytes) -> Bool {
  result.status == 0 && @testkit.bytes_equal(result.stdout, expected)
}

///|
fn record(condition : Bool, message : String, failures : Array[String]) -> Unit {
  if !condition {
    failures.push(message)
  }
}

///|
async fn check_admission(root : String, failures : Array[String]) -> Unit {
  let expected_restricted = [
    "chmod", "curl", "env", "find", "make", "sh", "timeout", "wget", "xargs",
  ]
  let catalog = @cli.command_catalog()
  record(
    catalog.length() == 48,
    "catalog must contain exactly 48 commands",
    failures,
  )
  let mut default_count = 0
  let mut restricted_count = 0
  for contract in catalog {
    if contract.tier == Restricted {
      restricted_count += 1
    } else {
      default_count += 1
    }
    let manifest_path = root_path(
      root,
      "commands/" + contract.name + "/moon.pkg",
    )
    let manifest = @fs.read_file(manifest_path).text() catch {
      err => {
        failures.push("\{contract.name}: cannot read moon.pkg: \{err}")
        continue
      }
    }
    record(
      manifest.contains("supported_targets = \"native+wasm\""),
      "\{contract.name}: must support native+wasm",
      failures,
    )
    if contract.tier != Restricted {
      record(
        !manifest.contains("moonbitlang/async/process") &&
        !manifest.contains("cli/core/process") &&
        !manifest.contains("cli/core/shell"),
        "\{contract.name}: non-restricted command acquired process authority",
        failures,
      )
    } else {
      let command_dir = root_path(root, "commands/" + contract.name)
      let entries = @fs.readdir(
        command_dir,
        include_hidden=true,
        include_special=false,
        sort=false,
      )
      for entry in entries {
        if entry.has_suffix(".mbt") {
          let source = @fs.read_file(root_path(command_dir, entry)).text()
          record(
            !source.contains("spawn_orphan") && !source.contains("\"/bin/"),
            "\{contract.name}: source contains an unsafe direct host path",
            failures,
          )
        }
      }
    }
  }
  record(
    default_count == 39,
    "default allow tier must contain 39 commands",
    failures,
  )
  record(
    restricted_count == 9,
    "restricted tier must contain 9 commands",
    failures,
  )
  for name in expected_restricted {
    match @cli.find_contract(name) {
      Some(contract) =>
        record(
          contract.tier == Restricted,
          "\{name}: must remain restricted",
          failures,
        )
      None => failures.push("\{name}: missing from command catalog")
    }
  }
  for name in ["make", "sh", "xargs"] {
    match @cli.find_contract(name) {
      Some(contract) =>
        record(
          @cli.releasable(contract),
          "\{name}: direct-child semantics must not require process groups",
          failures,
        )
      None => ()
    }
  }
  match @cli.find_contract("timeout") {
    Some(contract) =>
      record(
        !@cli.releasable(contract),
        "timeout: must remain gated without process-group cancellation",
        failures,
      )
    None => ()
  }
}

///|
async fn expect_denied(
  root : String,
  policy : String,
  command : String,
  args : Array[String],
  stdin : Bytes?,
  failures : Array[String],
) -> Unit {
  let result = moon_run(root, policy, command, args, stdin?) catch {
    err => {
      failures.push("\{command}: policy invocation failed: \{err}")
      return
    }
  }
  record(
    denied(result),
    "\{command}: policy must deny operation (status=\{result.status}, stderr=\{result.stderr})",
    failures,
  )
  record(
    !@testkit.contains_bytes(result.stdout, "policy-fixture"),
    "\{command}: denied operation leaked fixture contents",
    failures,
  )
}

///|
async fn expect_allowed(
  root : String,
  command : String,
  args : Array[String],
  expected : Bytes,
  failures : Array[String],
) -> Unit {
  let result = moon_run(root, "read-workspace.json", command, args) catch {
    err => {
      failures.push("\{command}: allowed read failed: \{err}")
      return
    }
  }
  record(
    stdout_is(result, expected),
    "\{command}: allowed read output mismatch",
    failures,
  )
}

///|
async fn expect_allowed_contains(
  root : String,
  command : String,
  args : Array[String],
  needle : String,
  failures : Array[String],
) -> Unit {
  let result = moon_run(root, "read-workspace.json", command, args) catch {
    err => {
      failures.push("\{command}: allowed read failed: \{err}")
      return
    }
  }
  record(result.status == 0, "\{command}: allowed read failed", failures)
  record(
    @testkit.contains_bytes(result.stdout, needle),
    "\{command}: allowed read output missing '\{needle}': \{result.stdout}",
    failures,
  )
}

///|
async fn check_runtime_policy(root : String, failures : Array[String]) -> Unit {
  let input_rel = "tests/fixtures/policy/runtime-input"
  let input = root_path(root, input_rel)
  @fs.write_file(input, b"policy-fixture\n")
  defer (@fs.remove(input) catch { _ => () })
  let zero_rel = "tests/fixtures/policy/runtime-zero"
  let zero = root_path(root, zero_rel)
  @fs.write_file(zero, b"second\x00first\x00first\x00")
  defer (@fs.remove(zero) catch { _ => () })
  let list_rel = "tests/fixtures/policy/runtime-list"
  let list = root_path(root, list_rel)
  @fs.write_file(list, @utf8.encode(input_rel + "\u0000"))
  defer (@fs.remove(list) catch { _ => () })
  let denied = moon_run(root, "deny-all.json", "cat", [input_rel]) catch {
    err => {
      failures.push("deny-all cat could not run: \{err}")
      return
    }
  }
  record(denied.status != 0, "deny-all must reject cat file read", failures)
  record(
    !@testkit.contains_bytes(denied.stdout, "policy-fixture"),
    "deny-all leaked file contents",
    failures,
  )
  let allowed = moon_run(root, "read-workspace.json", "cat", [input_rel]) catch {
    err => {
      failures.push("allowed cat could not run: \{err}")
      return
    }
  }
  record(allowed.status == 0, "read-workspace must allow cat", failures)
  record(
    @testkit.bytes_equal(allowed.stdout, b"policy-fixture\n"),
    "allowed cat output mismatch",
    failures,
  )
  expect_denied(
    root,
    "deny-all.json",
    "jqlog",
    ["-f", "tests/fixtures/policy/input.jsonl", ".message"],
    None,
    failures,
  )
  let jqlog = moon_run(root, "read-workspace.json", "jqlog", [
    "-f", "tests/fixtures/policy/input.jsonl", ".message",
  ]) catch {
    err => {
      failures.push("allowed jqlog could not run: \{err}")
      return
    }
  }
  record(
    stdout_is(jqlog, b"\"policy-fixture\"\n"),
    "allowed jqlog output mismatch",
    failures,
  )
  expect_denied(
    root,
    "deny-all.json",
    "cmp",
    [input_rel, input_rel],
    None,
    failures,
  )
  expect_denied(
    root,
    "deny-all.json",
    "grep",
    ["policy-fixture", input_rel],
    None,
    failures,
  )
  expect_denied(
    root,
    "deny-all.json",
    "ls",
    ["tests/fixtures/policy"],
    None,
    failures,
  )
  expect_denied(
    root,
    "deny-all.json",
    "find",
    ["tests/fixtures/policy", "-maxdepth", "0"],
    None,
    failures,
  )
  expect_denied(root, "deny-all.json", "sha256sum", [input_rel], None, failures)
  expect_denied(root, "deny-all.json", "head", ["-z", zero_rel], None, failures)
  expect_denied(root, "deny-all.json", "sort", ["-z", zero_rel], None, failures)
  expect_denied(root, "deny-all.json", "uniq", ["-z", zero_rel], None, failures)
  expect_denied(root, "deny-all.json", "wc", ["-L", input_rel], None, failures)
  expect_allowed(
    root,
    "grep",
    ["policy-fixture", input_rel],
    b"policy-fixture\n",
    failures,
  )
  expect_allowed(
    root,
    "find",
    ["tests/fixtures/policy", "-maxdepth", "0"],
    @utf8.encode(root_path(root, "tests/fixtures/policy") + "\n"),
    failures,
  )
  expect_allowed_contains(
    root,
    "ls",
    ["tests/fixtures/policy"],
    "runtime-input",
    failures,
  )
  expect_allowed_contains(
    root,
    "sha256sum",
    [input_rel],
    "runtime-input",
    failures,
  )
  let cmp = moon_run(root, "read-workspace.json", "cmp", [input_rel, input_rel]) catch {
    err => {
      failures.push("cmp: allowed read failed: \{err}")
      return
    }
  }
  record(cmp.status == 0, "cmp: allowed identical inputs failed", failures)
  expect_allowed(
    root,
    "head",
    ["-z", zero_rel],
    b"second\x00first\x00first\x00",
    failures,
  )
  expect_allowed(
    root,
    "sort",
    ["-z", zero_rel],
    b"first\x00first\x00second\x00",
    failures,
  )
  expect_allowed(
    root,
    "uniq",
    ["-z", "-s1", "-w1", zero_rel],
    b"second\x00first\x00",
    failures,
  )
  expect_allowed(
    root,
    "wc",
    ["-L", input_rel],
    @utf8.encode("14 " + root_path(root, input_rel) + "\n"),
    failures,
  )
  let listed = moon_run(root, "read-workspace.json", "wc", [
    "-l", "--files0-from", list_rel,
  ]) catch {
    err => {
      failures.push("wc: allowed NUL file list failed: \{err}")
      return
    }
  }
  record(
    stdout_is(listed, @utf8.encode("1 " + input_rel + "\n")),
    "wc: policy-visible --files0-from output mismatch",
    failures,
  )
}

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
    [fixture_rel + "/source", fixture_rel + "/denied-copy"],
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
    fixture_rel + "/source",
    fixture_rel + "/allowed-copy",
  ]) catch {
    err => {
      failures.push("cp: allowed mutation failed: \{err}")
      return
    }
  }
  record(cp.status == 0, "cp: write policy rejected mutation", failures)
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
  if @platform.symbolic_links_supported() {
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
      @testkit.contains_bytes(ln.stderr, "unsupported capability"),
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

///|
async fn check_process_and_network_policy(
  root : String,
  failures : Array[String],
) -> Unit {
  let makefile_rel = "tests/fixtures/policy/make-runner-fixture"
  let makefile = root_path(root, makefile_rel)
  @fs.write_file(makefile, b".PHONY: all\nall:\n\t@printf policy-make-ok\n")
  defer (@fs.remove(makefile) catch { _ => () })
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
    @testkit.contains_bytes(find.stdout, "process-echo.json"),
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
    ["-c", "printf denied"],
    None,
    failures,
  )
  expect_denied(
    root,
    "read-workspace.json",
    "make",
    ["-s", "-f", makefile_rel],
    None,
    failures,
  )
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
    @testkit.contains_bytes(xargs_parallel.stdout, "parallel-one") &&
    @testkit.contains_bytes(xargs_parallel.stdout, "parallel-two"),
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
    find_exec.status == 0 && @testkit.contains_bytes(find_exec.stdout, "policy"),
    "find: allowed child output mismatch: status=\{find_exec.status}, stdout=\{find_exec.stdout}, stderr=\{find_exec.stderr}",
    failures,
  )
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

///|
async fn check_allowed_network_policy(
  root : String,
  failures : Array[String],
) -> Unit {
  @async.with_task_group <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    group.add_defer(() => server.close())
    group.spawn_bg(no_wait=true) <| () => {
      server.run_forever() <| ((_, _, connection) => {
        connection.send_response(200, "OK", extra_headers={
          "Content-Length": "14",
        })
        connection..write("policy-net-ok\n").end_response()
      })
    }
    let url = "http://127.0.0.1:\{server.addr.port()}/allowed"
    let curl = moon_run(root, "net-local.json", "curl", ["-s", url]) catch {
      err => {
        failures.push("curl: allowed network invocation failed: \{err}")
        return
      }
    }
    let wget = moon_run(root, "net-local.json", "wget", ["-qO-", url]) catch {
      err => {
        failures.push("wget: allowed network invocation failed: \{err}")
        return
      }
    }
    record(
      stdout_is(curl, b"policy-net-ok\n"),
      "curl: local network policy did not allow the configured endpoint",
      failures,
    )
    record(
      stdout_is(wget, b"policy-net-ok\n"),
      "wget: local network policy did not allow the configured endpoint",
      failures,
    )
  }
}

///|
async fn check_chmod_policy(root : String, failures : Array[String]) -> Unit {
  let fixture_rel = "tests/fixtures/policy/chmod-runner-fixture"
  let fixture = root_path(root, fixture_rel)
  @fs.write_file(fixture, b"policy-mode\n")
  defer (@fs.remove(fixture) catch { _ => () })
  let result = moon_run(root, "read-workspace.json", "chmod", [
    "600", fixture_rel,
  ]) catch {
    err => {
      failures.push("chmod: policy invocation failed: \{err}")
      return
    }
  }
  record(
    result.status != 0,
    "chmod: read-only policy must deny mutation",
    failures,
  )
  record(
    @fs.read_file(fixture).text() == "policy-mode\n",
    "chmod: denial changed fixture contents",
    failures,
  )
  if !@platform.permission_mutation_supported() {
    record(
      @testkit.contains_bytes(result.stderr, "unsupported capability"),
      "chmod: Windows must return stable unsupported capability",
      failures,
    )
  }
}

///|
async fn run_policy_suite(
  root : String,
  wasm_root : String,
  failures : Array[String],
) -> Unit {
  policy_wasm_root.val = wasm_root
  check_admission(root, failures)
  check_runtime_policy(root, failures)
  check_mutation_policy(root, failures)
  check_process_and_network_policy(root, failures)
  check_allowed_network_policy(root, failures)
  check_chmod_policy(root, failures)
}
