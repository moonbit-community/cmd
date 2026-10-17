///|
test "package adapter accepts exactly one completed passing test" {
  assert_true(
    single_test_passed({
      status: 0,
      stdout: b"Total tests: 1, passed: 1, failed: 0.\r\n",
      stderr: b"",
    }),
  )
  assert_true(
    single_test_passed({
      status: 0,
      stdout: b"",
      stderr: b"Total tests: 1, passed: 1, failed: 0.\n",
    }),
  )
  for
    output in [
      b"", b"\xff", b"Total tests: 0, passed: 0, failed: 0.\n", b"Total tests: 2, passed: 2, failed: 0.\n",
      b"Total tests: 1, passed: 0, failed: 1.\n", b"Total tests: 1, passed: 1, failed: 0, skipped: 1.\n",
      b"Total tests: 1, passed: 1, failed: 0.\nTotal tests: 1, passed: 1, failed: 0.\n",
    ] {
    assert_false(
      single_test_passed({ status: 0, stdout: output, stderr: b"", }),
    )
  }
  assert_false(
    single_test_passed({
      status: 1,
      stdout: b"Total tests: 1, passed: 1, failed: 0.\n",
      stderr: b"",
    }),
  )
}

///|
test "package adapter binds exact source names without glob expansion" {
  let outline : Json = {
    "tests": {
      "fixture_wbtest.mbt": [
        { "index": 0, "name": "name?*\"\\", "attrs": [] },
        { "index": 1, "name": "name-other", "attrs": [] },
      ],
    },
  }
  assert_eq(
    exact_test_index(outline, "tests/fixture/fixture_wbtest.mbt", "name?*\"\\"),
    0,
  )
  assert_true(
    try {
      ignore(
        exact_test_index(outline, "tests/fixture/fixture_wbtest.mbt", "missing"),
      )
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      ignore(
        exact_test_index(
          outline, "tests/fixture/other_wbtest.mbt", "name-other",
        ),
      )
      false
    } catch {
      _ => true
    },
  )
}

///|
test "package adapter rejects ambiguous skipped and unknown test indices" {
  let invalid : Array[Array[Json]] = [
    [{ "index": 0, "name": "named", "attrs": ["skip"] }],
    [{ "index": 0, "name": "named", "attrs": ["unknown"] }],
    [{ "index": -1, "name": "named", "attrs": [] }],
    [
      { "index": 0, "name": "named", "attrs": [] },
      { "index": 1, "name": "named", "attrs": [] },
    ],
    [
      { "index": 0, "name": "named", "attrs": [] },
      { "index": 0, "name": "other", "attrs": [] },
    ],
  ]
  for tests in invalid {
    let outline : Json = { "tests": { "fixture_wbtest.mbt": Json(tests) } }
    assert_true(
      try {
        ignore(exact_test_index(outline, "fixture_wbtest.mbt", "named"))
        false
      } catch {
        _ => true
      },
    )
  }
}

///|
test "package adapter applies exact platform and package restrictions" {
  assert_true(platform_applies([], "windows"))
  assert_true(platform_applies(["posix"], "linux"))
  assert_true(platform_applies(["posix"], "macos"))
  assert_false(platform_applies(["posix"], "windows"))
  assert_false(platform_applies(["linux"], "macos"))
  assert_true(package_selected("core/process/file_test.mbt", "core/process"))
  assert_false(
    package_selected("core/process/nested/file_test.mbt", "core/process"),
  )
}

///|
test "package adapter rejects deadline and cleanup uncertainty" {
  let incomplete : Array[@testkit.TimedRun] = [
    {
      output: { status: 0, stdout: b"", stderr: b"", },
      timed_out: true,
      cleanup_error: None,
    },
    {
      output: { status: 0, stdout: b"", stderr: b"", },
      timed_out: false,
      cleanup_error: Some("reap failed"),
    },
  ]
  for result in incomplete {
    assert_true(
      try {
        require_completed(result, "test")
        false
      } catch {
        _ => true
      },
    )
  }
}

///|
test "package pair compares actual output even when both named tests pass" {
  let native : @testkit.RunResult = {
    status: 0,
    stdout: b"observed=one\nTotal tests: 1, passed: 1, failed: 0.\n",
    stderr: b"",
  }
  assert_true(package_pair_differences(native, native).is_empty())
  let wasm = {
    ..native,
    stdout: b"observed=two\nTotal tests: 1, passed: 1, failed: 0.\n",
  }
  assert_true(single_test_passed(wasm))
  assert_eq(package_pair_differences(native, wasm), [
    "test process stdout differs",
  ])
  assert_false(
    package_pair_differences(native, {
      ..native,
      stderr: b"unexpected diagnostic",
    }).is_empty(),
  )
  assert_false(
    package_pair_differences(native, { ..native, status: 1, }).is_empty(),
  )
  let skipped : @testkit.RunResult = {
    status: 0,
    stdout: b"Total tests: 0, passed: 0, failed: 0.\n",
    stderr: b"",
  }
  assert_false(package_pair_differences(skipped, skipped).is_empty())
}

///|
test "package completion cannot claim command streams or filesystem observations" {
  let (observed, missing) = package_observations(true, [
    "status", "stdout", "stderr", "file-content", "file-mode",
  ])
  assert_eq(observed, ["status"])
  assert_eq(missing, ["stdout", "stderr", "file-content", "file-mode"])
  let (observed, missing) = package_observations(false, ["status"])
  assert_eq(observed, [])
  assert_eq(missing, ["status"])
}
