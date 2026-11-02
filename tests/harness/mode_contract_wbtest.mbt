///|
fn mode_contract_case(mode : Int32, mask : Int32?) -> Case raise {
  let file : Map[String, Json] = {
    "path": Json("directory"),
    "mode": Json(mode),
  }
  if mask is Some(bits) {
    file["mode_mask"] = Json(bits)
  }
  @json.from_json({
    "id": "mode-contract",
    "command": "chmod",
    "args": [],
    "files": [],
    "environment": {},
    "normalizations": [],
    "expected_status": 0,
    "comparison": "contract",
    "expected_stdout_text": "",
    "expected_stderr_text": "",
    "expected_files": [Json(file)],
  })
}

///|
test "mode observations fail closed before permission masking" {
  assert_true(mode_observation_matches(Some("755"), 0o755, None))
  assert_true(mode_observation_matches(Some("0755"), 0o755, None))
  assert_true(mode_observation_matches(Some("0"), 0, None))
  assert_true(mode_observation_matches(Some("7755"), 0o7000, Some(0o7000)))
  assert_false(mode_observation_matches(Some("6755"), 0o7000, Some(0o7000)))
  for
    measured in [
      None,
      Some(""),
      Some("not-octal"),
      Some("-1"),
      Some("8888"),
      Some("10000"),
      Some(" 7000"),
      Some("7000\n"),
    ] {
    // A parse sentinel of -1 used to satisfy the all-set special-bit mask.
    assert_false(mode_observation_matches(measured, 0o7000, Some(0o7000)))
  }
}

///|
test "mode contracts reject discarded expected bits and vacuous masks" {
  assert_eq(contract_errors(mode_contract_case(0o7000, Some(0o7000))), [])
  assert_eq(contract_errors(mode_contract_case(0o300, Some(0o300))), [])
  assert_true(
    contract_errors(mode_contract_case(0o700, Some(0o300))).contains(
      "expected mode contains bits outside mode mask",
    ),
  )
  assert_true(
    contract_errors(mode_contract_case(0o10000, None)).contains(
      "expected mode must contain only permission and special bits",
    ),
  )
  assert_true(
    contract_errors(mode_contract_case(-1, None)).contains(
      "expected mode must contain only permission and special bits",
    ),
  )
  assert_false(contract_errors(mode_contract_case(0, Some(0))).is_empty())
  assert_false(mode_observation_matches(Some("300"), 0o700, Some(0o300)))
  assert_false(mode_observation_matches(Some("0"), 0, Some(0)))
  assert_false(mode_observation_matches(Some("755"), 0o10755, None))
}
