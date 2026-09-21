///|
test "byte differences identify offset and length" {
  assert_true(first_byte_difference(b"abc", b"axc").contains("at 1"))
  assert_true(first_byte_difference(b"abc", b"abcx").contains("length differs"))
}

///|
test "suite filtering respects case kind before fixtures or artifacts" {
  let cohorts = cohort_cases()
  let selected = @testkit.select_cases(cohorts, ["tail"], ["compat-tail-follow"])
  assert_eq(selected.length(), 1)
  assert_true(case_in_suites(selected[0], ["compat"]))
  assert_false(case_in_suites(selected[0], ["oracle", "contract", "scenarios"]))
  assert_true(
    cohorts
    .filter(item => case_in_suites(item, ["gnu"]))
    .all(item => item.id == "gnu-host"),
  )
}
