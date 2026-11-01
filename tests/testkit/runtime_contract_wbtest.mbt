///|
fn runtime_fixture(values : Json) -> Case raise {
  let fields : Map[String, Json] = {
    "id": Json("runtime-quality"),
    "command": Json("probe"),
    "args": Json::array([]),
    "files": Json::array([]),
    "environment": Json::object({}),
    "expected_status": Json(0),
    "normalizations": Json::array([]),
    "comparison": Json("contract"),
    "expected_stderr_text": Json(""),
  }
  guard values is Object(extra) else {
    fail("runtime fixture requires an object")
  }
  for key, value in extra {
    fields[key] = value
  }
  @json.from_json(Json(fields))
}

///|
fn runtime_output(text : String) -> RunResult {
  { status: 0, stdout: @utf8.encode(text), stderr: b"", }
}

///|
test "runtime JSON binds complete records keys order and typed durations" {
  let fixture = runtime_fixture({
    "expected_stdout_json": [
      { "type": "match", "data": { "path": "hay", "count": 1 } },
      { "type": "summary", "duration": { "$any": "duration" } },
    ],
    "stdout_json_lines": true,
    "expected_stdout_ends_with_newline": true,
  })
  let first = "{\"data\":{\"count\":1,\"path\":\"hay\"},\"type\":\"match\"}\n"
  let last = "{\"type\":\"summary\",\"duration\":{\"secs\":0,\"nanos\":123000,\"human\":\"0.000123s\"}}\n"
  assert_eq(check_runtime_contract(fixture, runtime_output(first + last)), [])
  for
    invalid in [
      first,
      first + last + last,
      last + first,
      first.replace_all(old="\"count\":1,", new="") + last,
      first.replace_all(old="\"count\":1", new="\"count\":2") + last,
      first.replace_all(old="\"count\":1", new="\"count\":1,\"extra\":0") + last,
      first + "\n" + last,
      first + last.trim().to_owned(),
      first + last.replace_all(old="123000", new="1000000000"),
      first + last.replace_all(old="\"secs\":0", new="\"secs\":-1"),
      first + last.replace_all(old="\"secs\":0", new="\"secs\":0.5"),
      first + last.replace_all(old="0.000123s", new="garbage"),
      first + last.replace_all(old="0.000123s", new="0.123s"),
      first + last.replace_all(old="\"secs\":0", new="\"secs\":0,\"extra\":0"),
    ] {
    assert_false(
      check_runtime_contract(fixture, runtime_output(invalid)).is_empty(),
      msg=invalid,
    )
  }
}

///|
test "runtime JSON rejects duplicate decoded keys and trailing data" {
  let fixture = runtime_fixture({ "expected_stdout_json": { "value": 1 } })
  assert_eq(check_runtime_contract(fixture, runtime_output("{\"value\":1}")), [])
  for
    text in [
      "{\"value\":2,\"value\":1}", "{\"value\":2,\"\\u0076alue\":1}", "{\"value\":1} {}",
      "{\"value\":1,\"unreviewed\":0}",
    ] {
    assert_false(
      check_runtime_contract(fixture, runtime_output(text)).is_empty(),
    )
  }
  assert_false(
    check_runtime_contract(fixture, { status: 0, stdout: b"\xFF", stderr: b"", }).is_empty(),
  )
  let numeric = runtime_fixture({
    "expected_stdout_json": { "value": { "$any": "nonnegative-number" } },
  })
  assert_eq(
    check_runtime_contract(numeric, runtime_output("{\"value\":1.5}")),
    [],
  )
  assert_false(
    check_runtime_contract(numeric, runtime_output("{\"value\":-1}")).is_empty(),
  )
  assert_false(
    check_runtime_contract(numeric, runtime_output("{\"value\":\"1\"}")).is_empty(),
  )
}

///|
async test "runtime observations freeze expected sizes before product execution" {
  let root = @fs.tmpdir(prefix="mooncmd-runtime-expected")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  @fs.write_file(root + "/file", "abc")
  @fs.mkdir(root + "/sub")
  let fixture = runtime_fixture({
    "expected_stdout_text": "😀[${STAT_SIZE:file:4}] ${STAT_SUM:file:2:4} ${HUMAN_SIZE:file} ${SI_SIZE:file}",
    "expected_stdout_json": {
      "size": { "$sum": [{ "$stat_size": "file" }, 2] },
    },
  })
  assert_eq(runtime_contract_observers(fixture), ["dynamic:runtime-quality"])
  let resolved = resolve_runtime_contract(fixture, root)
  assert_eq(resolved.expected_stdout_text, Some("😀[   3]    5    3    3"))
  assert_eq(resolved.expected_stdout_json, Some({ "size": 5 }))
  @fs.write_file(root + "/file", "candidate changed the input")
  assert_eq(check_runtime_contract(resolved, runtime_output("{\"size\":5}")), [])
  assert_false(
    check_runtime_contract(resolved, runtime_output("{\"size\":\"5\"}")).is_empty(),
  )
  let directory = runtime_fixture({
    "expected_stdout_json": { "size": { "$stat_size": "sub" } },
  })
  if @async.platform is Windows {
    let detail = try {
      ignore(resolve_runtime_contract(directory, root))
      "accepted an unsupported directory observer"
    } catch {
      error => error.to_string()
    }
    assert_true(
      detail.contains("directory-size observation is unsupported on Windows"),
    )
  } else {
    let args = if @async.platform is MacOS {
      ["-f", "%z", root + "/sub"]
    } else {
      ["-c", "%s", root + "/sub"]
    }
    let observation = run("/usr/bin/stat", args, inherit_env=false)
    assert_eq(observation.status, 0)
    assert_eq(observation.stderr, b"")
    let before = @json.parse(@utf8.decode(observation.stdout))
    assert_true(before is Number(_, ..))
    let result = resolve_runtime_contract(directory, root)
    assert_eq(result.expected_stdout_json, Some({ "size": before }))
  }
  assert_eq(
    runtime_contract_observers(
      runtime_fixture({ "expected_stdout_text": "literal" }),
    ),
    [],
  )
}

///|
async test "runtime expected paths operators and template syntax fail closed" {
  let root = @fs.tmpdir(prefix="mooncmd-runtime-invalid")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  @fs.write_file(root + "/file", "abc")
  let invalid : Array[Json] = [
    { "expected_stdout_text": "${STAT_SIZE:../outside:11}" },
    { "expected_stdout_text": "${STAT_SIZE:/absolute:11}" },
    { "expected_stdout_text": "${STAT_SIZE:C:\\outside:11}" },
    { "expected_stdout_text": "${STAT_SIZE:file:0}" },
    { "expected_stdout_text": "${STAT_SIZE:file:33}" },
    { "expected_stdout_text": "${STAT_SIZE:file:11" },
    { "expected_stdout_text": "${STAT_UNKNOWN:file:11}" },
    { "expected_stdout_text": "${STAT_SUM:file:-1:11}" },
    { "expected_stdout_json": { "$stat_size": "../outside" } },
    { "expected_stdout_json": { "$stat_size": "file", "extra": 0 } },
    { "expected_stdout_json": { "$sum": [] } },
    { "expected_stdout_json": { "$sum": [-1] } },
    { "expected_stdout_json": { "$sum": [{ "$any": "nonnegative-number" }] } },
    { "expected_stdout_json": { "$any": "anything" } },
    { "expected_stdout_json": { "$unknown": 0 } },
  ]
  for value in invalid {
    let rejected = try {
      ignore(resolve_runtime_contract(runtime_fixture(value), root))
      false
    } catch {
      _ => true
    }
    assert_true(rejected, msg=value.stringify())
  }
}

///|
async test "runtime canonical path check rejects a symlink escape" {
  if @async.platform is Windows {
    return
  }
  let outer = @fs.tmpdir(prefix="mooncmd-runtime-link")
  defer (@fs.rmdir(outer, recursive=true) catch { _ => () })
  @fs.mkdir(outer + "/fixture")
  @fs.write_file(outer + "/outside", "private")
  @fs.symlink(target="../outside", outer + "/fixture/link")
  let rejected = try {
    ignore(
      resolve_runtime_contract(
        runtime_fixture({ "expected_stdout_json": { "$stat_size": "link" } }),
        outer + "/fixture",
      ),
    )
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}

///|
test "runtime human sizes follow independent C float rounding and widths" {
  assert_eq(runtime_human(3L, false), "   3")
  assert_eq(runtime_human(1024L, false), "1.0K")
  assert_eq(runtime_human(1048576L, false), "1.0M")
  assert_eq(runtime_human(1000000L, true), "1.0M")
  assert_eq(runtime_human(1150L, true), "1.1k")
  assert_eq(runtime_decimal(1.25, 1), "1.2")
  assert_eq(runtime_decimal(1.75, 1), "1.8")
}

///|
test "directory-size observer rejects malformed output and failed commands" {
  assert_eq(runtime_directory_size(runtime_output("4096\n")), 4096L)
  assert_eq(runtime_directory_size(runtime_output("0\n")), 0L)
  let invalid : Array[RunResult] = [
    { status: 1, stdout: b"4096\n", stderr: b"", },
    { status: 0, stdout: b"4096\n", stderr: b"warning\n", },
    runtime_output(""),
    runtime_output("4096"),
    runtime_output("4096\n0\n"),
    runtime_output("-1\n"),
    runtime_output(" 4096\n"),
    runtime_output("9007199254740992\n"),
    runtime_output("9999999999999999999999999999999999999999\n"),
    runtime_output("not-a-size\n"),
  ]
  for observed in invalid {
    let rejected = try {
      ignore(runtime_directory_size(observed))
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
}
