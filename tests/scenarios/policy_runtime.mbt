///|
async fn expect_denied(
  root : String,
  policy : String,
  command : String,
  args : Array[String],
  stdin : Bytes?,
  failures : Array[String],
) -> Unit {
  if !@harness.command_available(command) {
    return
  }
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
    !@harness.contains_bytes(result.stdout, "policy-fixture"),
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
    @harness.contains_bytes(result.stdout, needle),
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
    !@harness.contains_bytes(denied.stdout, "policy-fixture"),
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
    @harness.bytes_equal(allowed.stdout, b"policy-fixture\n"),
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
  // Windows needs an explicitly provisioned temporary environment to reach
  // the filesystem write check instead of aborting during path lookup.
  let sort_spill = moon_run(
    root,
    "read-workspace-temp-env.json",
    "sort",
    [],
    stdin=@utf8.encode("a\n".repeat(524288)),
  ) catch {
    err => {
      failures.push("sort spill policy invocation failed: \{err}")
      return
    }
  }
  record(
    sort_spill.status == 2 &&
    sort_spill.stdout.is_empty() &&
    @harness.contains_bytes(sort_spill.stderr, "blocked file write"),
    "sort must report host temporary-write denial before emitting output (status=\{sort_spill.status}, stdout_bytes=\{sort_spill.stdout.length()}, stderr=\{sort_spill.stderr})",
    failures,
  )
  let fragments = @fs.tmpdir(prefix="cli-resource-policy-")
  defer @fs.rmdir(fragments, recursive=true)
  for
    (command, args) in [
      ("column", ["-t"]),
      ("csplit", ["-s", "-f", fragments + "/part-", "-", "2"]),
      ("tac", []),
    ] {
    let spool = moon_run(
      root,
      "read-workspace-temp-env.json",
      command,
      args,
      stdin=b"first\nsecond\n",
    ) catch {
      error => {
        failures.push(
          "\{command} temporary-write policy invocation failed: \{error}",
        )
        continue
      }
    }
    record(
      spool.status != 0 &&
      spool.stdout.is_empty() &&
      @harness.contains_bytes(spool.stderr, "blocked file write"),
      "\{command} must report host temporary-write denial before emitting output (status=\{spool.status}, stdout_bytes=\{spool.stdout.length()}, stderr=\{spool.stderr})",
      failures,
    )
  }
  record(
    @fs.readdir(fragments).is_empty(),
    "temporary-write denial must not create csplit fragments",
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
