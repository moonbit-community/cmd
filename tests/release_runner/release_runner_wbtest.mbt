///|
test "release manifest version validation" {
  assert_true(valid_version("0.1.4"))
  assert_true(valid_version("12.0.7"))
  assert_false(valid_version("latest"))
  assert_false(valid_version("0.1"))
  assert_false(valid_version("0.x.1"))
}

///|
test "release fixture paths stay relative" {
  assert_true(safe_relative_path("nested/file"))
  assert_false(safe_relative_path(""))
  assert_false(safe_relative_path("../outside"))
  assert_false(safe_relative_path("/absolute"))
  assert_false(safe_relative_path("nested/../outside"))
  assert_false(safe_relative_path("C:/outside"))
  assert_true(safe_symlink_target("target"))
  assert_false(safe_symlink_target("../outside"))
  assert_false(safe_symlink_target("/absolute"))
}

///|
test "release contract newline checks exactly one terminator" {
  assert_true(ends_with_newline(b"line\n"))
  assert_false(ends_with_newline(b"line\n\n"))
  assert_false(ends_with_newline(b"line"))
  assert_false(ends_with_newline(b""))
}

///|
test "release manifest selects explicit cases" {
  let manifest : ReleaseManifest = {
    schema: 1,
    base_manifest: "tests/fixtures/runner/cases.json",
    commands: [],
    case_ids: [],
    extra_cases: [
      {
        id: "one",
        command: "echo",
        args: [],
        stdin_hex: "",
        files: [],
        environment: {},
        expected_status: 0,
        timeout_ms: None,
        normalizations: [],
        comparison: None,
        expected_stdout_contains: None,
        expected_stdout_ends_with_newline: None,
        expected_stderr_ends_with_newline: None,
        forbidden_stderr: None,
        coverage: None,
      },
    ],
  }
  let base : BaseManifest = { schema: 1, cases: [], }
  assert_eq(selected_cases(manifest, base).length(), 1)
  assert_eq(selected_cases(manifest, base)[0].id, "one")
}
