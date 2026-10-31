///|
test "catalog contains exactly 80 unique commands" {
  let catalog = command_catalog()
  assert_eq(catalog.length(), 80)
  let names : Map[String, Bool] = Map([])
  for item in catalog {
    assert_false(names.contains(item.name))
    names[item.name] = true
  }
  assert_true(find_contract("cat") is Some({ tier: Core, .. }))
  assert_true(find_contract("timeout") is Some({ tier: Restricted, .. }))
}

///|
test "every command contract declares common metadata options" {
  for item in command_catalog() {
    assert_true(item.options.contains("help"))
    assert_true(item.options.contains("version"))
  }
}

///|
test "only timeout requires process-group cancellation" {
  for name in ["make", "sh", "xargs"] {
    guard find_contract(name) is Some(contract) else {
      fail("missing command contract: \{name}")
    }
    assert_false(contract.capabilities.contains(ProcessGroupCancellation))
    assert_true(releasable(contract))
  }
  guard find_contract("timeout") is Some(timeout) else {
    fail("missing command contract: timeout")
  }
  assert_true(timeout.capabilities.contains(ProcessGroupCancellation))
  assert_false(releasable(timeout))
}

///|
test "catalog records shared child launch outcomes without owning diagnostics" {
  guard find_contract("env") is Some(environment) else {
    fail("missing env contract")
  }
  assert_eq(environment.exit_codes, [0, 125, 126, 127])
  guard find_contract("xargs") is Some(xargs) else {
    fail("missing xargs contract")
  }
  assert_eq(xargs.exit_codes, [0, 1, 2, 123, 124, 125, 126, 127])
}

///|
test "rg does not advertise unsupported DFA budgets or indexing" {
  guard find_contract("rg") is Some(contract) else {
    fail("missing rg contract")
  }
  for option in ["dfa-size-limit", "index", "x-crud", "x-force", "x-path"] {
    assert_false(contract.options.contains(option))
  }
}
