///|
test "catalog contains exactly 82 unique commands" {
  let catalog = commands()
  assert_eq(catalog.length(), 82)
  let names : Map[String, Bool] = Map([])
  for item in catalog {
    assert_false(names.contains(item.name))
    names[item.name] = true
  }
  assert_true(find("cat") is Some({ tier: Core, .. }))
  assert_true(find("timeout") is Some({ tier: Restricted, .. }))
}

///|
test "every command contract declares common metadata options" {
  for item in commands() {
    assert_true(item.options.contains("help"))
    assert_true(item.options.contains("version"))
  }
}

///|
test "only timeout requires process-group cancellation" {
  for name in ["make", "sh", "xargs"] {
    guard find(name) is Some(contract) else {
      fail("missing command contract: \{name}")
    }
    assert_false(contract.capabilities.contains(ProcessGroupCancellation))
    assert_true(releasable(contract))
  }
  guard find("timeout") is Some(timeout) else {
    fail("missing command contract: timeout")
  }
  assert_true(timeout.capabilities.contains(ProcessGroupCancellation))
  assert_false(releasable(timeout))
}

///|
test "catalog records shared child launch outcomes without owning diagnostics" {
  guard find("env") is Some(environment) else { fail("missing env contract") }
  assert_eq(environment.exit_codes, [0, 125, 126, 127])
  guard find("xargs") is Some(xargs) else { fail("missing xargs contract") }
  assert_eq(xargs.exit_codes, [0, 1, 2, 123, 124, 125, 126, 127])
}

///|
test "rg does not advertise unsupported DFA budgets or indexing" {
  guard find("rg") is Some(contract) else { fail("missing rg contract") }
  for option in ["dfa-size-limit", "index", "x-crud", "x-force", "x-path"] {
    assert_false(contract.options.contains(option))
  }
}
