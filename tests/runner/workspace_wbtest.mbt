///|
async test "workspace discovery resolves nested module and runner working directories" {
  let temporary = @fs.tmpdir(prefix="mooncmd-workspace-root")
  defer (@fs.rmdir(temporary, recursive=true) catch { _ => () })
  let root = @fs.realpath(temporary)
  for directory in ["commands", "tests/registry", "tests/runner/deeper"] {
    @fs.mkdir(root + "/" + directory, recursive=true)
  }
  @fs.write_file(root + "/moon.work", "members = []")
  @fs.write_file(root + "/tests/registry/registry.json", "{}")
  for
    directory in [
      root,
      root + "/tests",
      root + "/tests/runner",
      root + "/tests/runner/deeper",
    ] {
    assert_eq(workspace_root(start=directory), root)
  }
  @fs.remove(root + "/moon.work")
  let missing = try {
    ignore(workspace_root(start=root + "/tests/runner"))
    false
  } catch {
    error => error.to_string().contains("cannot locate cmd workspace root")
  }
  assert_true(missing)
}

///|
async test "workspace inputs preserve caller paths and default outputs stay explicit" {
  let temporary = @fs.tmpdir(prefix="mooncmd-workspace-paths")
  defer (@fs.rmdir(temporary, recursive=true) catch { _ => () })
  let root = @fs.realpath(temporary)
  let caller = root + "/tests/runner"
  @fs.mkdir(caller, recursive=true)
  @fs.mkdir(root + "/_build/native", recursive=true)
  @fs.write_file(root + "/tests/cases.json", "{}")
  @fs.write_file(caller + "/local.json", "{}")
  assert_eq(
    workspace_input(root, "tests/cases.json", start=caller),
    root + "/tests/cases.json",
  )
  assert_eq(
    workspace_input(root, "../cases.json", start=caller),
    root + "/tests/cases.json",
  )
  assert_eq(
    workspace_input(root, "local.json", start=caller),
    caller + "/local.json",
  )
  assert_eq(
    workspace_input(root, "_build/native", start=caller),
    root + "/_build/native",
  )
  assert_eq(
    workspace_input(root, root + "/tests/cases.json", start=caller),
    root + "/tests/cases.json",
  )
  assert_eq(
    workspace_output("reports/new-run", start=caller),
    caller + "/reports/new-run",
  )
  assert_eq(
    workspace_output(root + "/test-reports/default", start=caller),
    root + "/test-reports/default",
  )
}

///|
async test "cohort selection requires its unique typed registry owner" {
  let root = workspace_root()
  let registry = @registry.load(
    workspace_path(root, "tests/registry/registry.json"),
  )
  let fixtures = registered_cohort_cases(registry)
  assert_eq(fixtures.length(), cohort_cases().length())
  let removed = {
    ..registry,
    entries: registry.entries.filter(entry => {
      entry.source != "tests/runner/cohorts.mbt::compat-catalog"
    }),
  }
  let refused = try {
    ignore(registered_cohort_cases(removed))
    false
  } catch {
    error => error.to_string().contains("registered typed binding")
  }
  assert_true(refused)
}
