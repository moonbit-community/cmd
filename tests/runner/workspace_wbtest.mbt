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
  let cases_path = @fs.realpath(root + "/tests/cases.json")
  let local_path = @fs.realpath(caller + "/local.json")
  let native_path = @fs.realpath(root + "/_build/native")
  assert_eq(workspace_input(root, "tests/cases.json", start=caller), cases_path)
  assert_eq(workspace_input(root, "../cases.json", start=caller), cases_path)
  assert_eq(workspace_input(root, "local.json", start=caller), local_path)
  assert_eq(workspace_input(root, "_build/native", start=caller), native_path)
  assert_eq(
    workspace_input(root, root + "/tests/cases.json", start=caller),
    cases_path,
  )
  assert_eq(
    workspace_output("reports/new-run", start=caller),
    @path.Path(caller + "/reports/new-run").normalize().to_string(),
  )
  assert_eq(
    workspace_output(root + "/test-reports/default", start=caller),
    @path.Path(root + "/test-reports/default").normalize().to_string(),
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

///|
async test "default scenario selection uses registered backends while explicit cases remain diagnostic" {
  let root = workspace_root()
  let registry = @registry.load(
    workspace_path(root, "tests/registry/registry.json"),
  )
  for
    (id, supported) in [
      ("mv-windows-native-links", "native"),
      ("mv-windows-wasm-links-boundary", "wasm"),
    ] {
    let fixture : @testkit.Case = @json.from_json({
      "id": Json(id),
      "command": "mv",
      "args": [],
      "files": [],
      "environment": {},
      "normalizations": [],
      "expected_status": 0,
      "comparison": "scenario",
    })
    for backend in ["native", "wasm"] {
      assert_eq(
        registered_scenario_backend_selected(registry, fixture, backend, []),
        backend == supported,
      )
      assert_true(
        registered_scenario_backend_selected(registry, fixture, backend, [id]),
      )
    }
    let both = {
      ..registry,
      entries: registry.entries.map(entry => {
        if entry.source == "tests/runner/scenarios.mbt::" + id {
          { ..entry, required_backends: ["native", "wasm"], }
        } else {
          entry
        }
      }),
    }
    for backend in ["native", "wasm"] {
      assert_true(
        registered_scenario_backend_selected(both, fixture, backend, []),
      )
    }
    let missing = {
      ..registry,
      entries: registry.entries.filter(entry => {
        entry.source != "tests/runner/scenarios.mbt::" + id
      }),
    }
    let rejected = try {
      ignore(
        registered_scenario_backend_selected(missing, fixture, "native", []),
      )
      false
    } catch {
      error => error.to_string().contains("registered typed binding")
    }
    assert_true(rejected)
  }
}
