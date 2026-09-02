///|
test "catalog contains exactly 48 unique commands" {
  let catalog = command_catalog()
  assert_eq(catalog.length(), 48)
  let names : Map[String, Bool] = Map([])
  for item in catalog {
    assert_false(names.contains(item.name))
    names[item.name] = true
  }
  assert_true(find_contract("cat") is Some({ tier: Core, .. }))
  assert_true(find_contract("timeout") is Some({ tier: Restricted, .. }))
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
  assert_eq(xargs.exit_codes, [0, 1, 126, 127])
}

///|
test "parse option forms and operands" {
  let specs = [
    flag("all", short='a'),
    flag("verbose", short='v'),
    option("output", short='o'),
  ]
  let parsed = parse(["-av", "-ofile", "--output=last", "--", "-a", "-"], specs)
  assert_true(parsed.contains("all"))
  assert_true(parsed.contains("verbose"))
  assert_eq(parsed.last_value("output"), Some("last"))
  assert_eq(parsed.values("output"), ["file", "last"])
  assert_eq(parsed.operands, ["-a", "-"])
  assert_eq(parsed.last_occurrence(["all", "verbose"]), Some("verbose"))
}

///|
test "parse rejects missing, unknown, and duplicate options" {
  let specs = [option("output", short='o', repeatable=false)]
  try parse(["--missing"], specs) catch {
    CliError(kind=UnknownOption, ..) => ()
    _ => fail("expected unknown-option error")
  } noraise {
    _ => fail("expected unknown-option error")
  }
  try parse(["-o"], specs) catch {
    CliError(kind=MissingOptionValue, ..) => ()
    _ => fail("expected missing-value error")
  } noraise {
    _ => fail("expected missing-value error")
  }
  try parse(["-oa", "--output=b"], specs) catch {
    CliError(kind=DuplicateOption, ..) => ()
    _ => fail("expected duplicate-option error")
  } noraise {
    _ => fail("expected duplicate-option error")
  }
}

///|
test "idle timeout accepts fractional seconds" {
  assert_eq(parse_idle_timeout("0.001"), 1)
  assert_eq(parse_idle_timeout("1.5"), 1500)
  assert_eq(parse_idle_timeout("30"), 30000)
}

///|
test "idle timeout rejects non-positive and invalid values" {
  fn assert_rejected(value : String) raise {
    try parse_idle_timeout(value) catch {
      CliError(kind=InvalidValue, ..) => ()
      _ => fail("expected invalid-value error")
    } noraise {
      _ => fail("expected timeout value to be rejected")
    }
  }
  assert_rejected("0")
  assert_rejected("-1")
  assert_rejected("not-a-number")
  assert_rejected("1e100")
}
