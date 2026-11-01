///|
test "stream diagnostics select the commands actually executed by the cohort" {
  let cases = cohort_cases().filter(fixture => {
    fixture.comparison == Some("stress")
  })
  for command in ["seq", "wc"] {
    let selected = @harness.select_cases(cases, [command], [])
    assert_eq(selected.map(fixture => fixture.id), ["stress-streams"])
  }
  assert_eq(cases[0].command, "seq")
  let environment = cohort_cases().filter(fixture => {
    fixture.id == "compat-environment"
  })
  assert_eq(@harness.select_cases(environment, ["printenv"], []).length(), 1)
}

///|
async test "compatibility fixture cleanup errors propagate" {
  let root = @fs.tmpdir(prefix="mooncmd-cleanup-regression-")
  defer @fs.rmdir(root, recursive=true)
  @fs.write_file(root + "/file", b"not a directory")
  try cleanup_compat_fixture(root + "/file") catch {
    _ => ()
  } noraise {
    _ => fail("fixture cleanup failure was suppressed")
  }
}
