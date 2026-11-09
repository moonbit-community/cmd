///|
/// Assert an observation directly, without a parallel descriptor or receipt.
pub fn assert_observation(
  id : String,
  command : String,
  actual : Json,
  expected : Json,
) -> Unit raise {
  assert_eq(actual, expected, msg=command + ": " + id)
}

///|
pub fn assert_mode_pair(
  id : String,
  command : String,
  actual : String,
  control : String,
) -> Unit raise {
  for value in [actual, control] {
    assert_true(
      value.length() >= 3 &&
      value.length() <= 4 &&
      value.iter().all(c => c >= '0' && c <= '7'),
      msg=command + ": " + id + ": invalid observed mode",
    )
  }
  assert_eq(actual, control, msg=command + ": " + id)
}

///|
pub fn scenario_text(bytes : Bytes) -> String raise {
  @utf8.decode(bytes)
}
