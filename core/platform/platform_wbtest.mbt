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
