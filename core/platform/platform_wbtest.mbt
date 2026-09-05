///|
test "native separator is accepted" {
  assert_true(accepts_separator(native_separator()))
  assert_true(accepts_separator('/'))
}

///|
test "permission support follows platform" {
  assert_eq(permission_mutation_supported(), !is_windows())
  assert_eq(symbolic_links_supported(), !is_windows())
}

///|
test "filesystem capability gates are explicit" {
  assert_true(file_kind_reads_supported())
  assert_true(regular_file_size_reads_supported())
  assert_true(access_time_reads_supported())
  assert_true(modification_time_reads_supported())
  assert_true(status_change_time_reads_supported())
  assert_true(access_checks_supported())
  assert_eq(symbolic_link_creation_supported(), !is_windows())
  assert_true(metadata_reads_supported())
  assert_false(permission_reads_supported())
  assert_false(timestamp_mutation_supported())
  assert_false(hard_links_supported())
  assert_false(readlink_supported())
  assert_false(cross_device_rename_classification_supported())
  assert_false(special_file_policy_supported())
}

///|
test "terminal output requires explicit policy and a proven terminal" {
  assert_false(terminal_policy_allows(Silent, false))
  assert_false(terminal_policy_allows(Silent, true))
  assert_false(terminal_policy_allows(IfTerminal, false))
  assert_true(terminal_policy_allows(IfTerminal, true))
}

///|
async test "standard stream terminal detection is total" {
  ignore(stdin_is_terminal())
  ignore(stdout_is_terminal())
  ignore(stderr_is_terminal())
  ignore(terminal_output_enabled(IfTerminal, Stderr))
}
