///|
test "selected results reject omissions, duplicates, substitutions and undeclared skips" {
  let fixture = quality_case({
    "expected_stdout_text": "",
    "expected_stderr_text": "",
  })
  let report = {
    ..suite_report(fixture.id, "wasm", 0L, []),
    command: fixture.command,
  }
  assert_eq(result_integrity_errors([fixture], [report]), [])
  for
    (selected, actual) in [
      ([], [report]),
      ([fixture], []),
      ([fixture, fixture], [report]),
      ([fixture], [report, report]),
      ([fixture], [{ ..report, id: "unknown", }]),
      ([fixture], [{ ..report, command: "unknown", }]),
      ([fixture], [{ ..report, result: "skip", }]),
      ([fixture], [{ ..report, result: "unknown", }]),
      ([fixture], [{ ..report, missing_observations: ["stdout"], }]),
    ] {
    assert_false(result_integrity_errors(selected, actual).is_empty())
  }
  let other = if host_platform() == "windows" { "linux" } else { "windows" }
  assert_eq(
    result_integrity_errors([{ ..fixture, host_platforms: Some([other]), }], [
      { ..report, result: "skip", },
    ]),
    [],
  )
}

///|
test "direct scenario assertions reject mismatches and malformed independent modes" {
  assert_observation("response", "curl", { "status": 0 }, { "status": 0 })
  try
    assert_observation("response", "curl", { "status": 1 }, { "status": 0 })
  catch {
    _ => ()
  } noraise {
    _ => fail("mismatched direct observation passed")
  }
  for (actual, control) in [("600", "644"), ("999", "999"), ("", "")] {
    try assert_mode_pair("creation-mode", "mktemp", actual, control) catch {
      _ => ()
    } noraise {
      _ => fail("invalid mode relation passed")
    }
  }
}
