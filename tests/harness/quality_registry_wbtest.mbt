///|
test "regression identity ignores labels and assertion strength but retains actual inputs" {
  let base = quality_case({
    "expected_stdout_text": "value",
    "expected_stderr_text": "",
    "args": ["-n", "-b"],
    "stdin_text": "input",
  })
  let strengthened = {
    ..base,
    id: "retained-alias",
    expected_stdout_contains: Some("value"),
    source_version: Some("independent review"),
  }
  assert_eq(case_stimulus_digest(base), case_stimulus_digest(strengthened))
  for
    changed in [
      { ..base, args: ["-b", "-n"], },
      { ..base, stdin_text: Some("different"), },
      { ..base, environment: Map([("VALUE", "changed")]), },
      { ..base, delay_ms: Some(2), },
      { ..base, host_platforms: Some(["linux"]), },
    ] {
    assert_true(case_stimulus_digest(base) != case_stimulus_digest(changed))
  }
  assert_eq(
    case_stimulus_digest(base),
    case_stimulus_digest({
      ..base,
      stdin_text: None,
      stdin_hex: Some("696e707574"),
    }),
  )
  assert_true(
    case_stimulus_digest(base) !=
    case_stimulus_digest({ ..base, comparison: Some("scenario"), }),
  )
  let template = { ..base, stdin_text: Some("${WORK}"), }
  assert_true(
    case_stimulus_digest(template) !=
    case_stimulus_digest({
      ..template,
      stdin_text: None,
      stdin_hex: Some("247b574f524b7d"),
    }),
  )
}
