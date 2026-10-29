///|
test "grep execution preserves flag priority and contextual span output" {
  let base = streaming_options()
  assert_true(base.execution(false) is BatchedRecords)
  assert_true(base.execution(true) is Records)
  assert_true({ ..base, count: true, }.execution(false) is Summary(true))
  assert_true(
    { ..base, count: true, files_with_matches: true, }.execution(false)
    is Summary(false),
  )
  assert_true({ ..base, quiet: true, }.execution(false) is Summary(false))
  assert_true(
    { ..base, files_without_match: true, }.execution(false) is Summary(true),
  )
  assert_true(
    { ..base, only_matching: true, context_enabled: true, }.execution(false)
    is MatchSpans,
  )
  assert_true(
    { ..base, only_matching: true, invert: true, }.execution(false) is Records,
  )
  assert_true({ ..base, line_number: true, }.execution(false) is Records)
}
