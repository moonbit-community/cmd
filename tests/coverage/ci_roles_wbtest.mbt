///|
test "CI Linux receipts retain mandatory supplementary execution" {
  assert_true(ci_report_roles("linux").contains("gnu-native"))
  let paths = ci_receipt_paths("linux")
  assert_true(paths.contains("gnu-native/summary.jsonl"))
  assert_true(paths.contains("gnu-native/run-metadata.json"))
  for platform in ["macos", "windows"] {
    assert_false(ci_report_roles(platform).contains("gnu-native"))
    assert_false(
      ci_receipt_paths(platform).contains("gnu-native/summary.jsonl"),
    )
  }
}
