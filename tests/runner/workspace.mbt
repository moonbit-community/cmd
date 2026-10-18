///|
/// Locate the owning workspace without changing the process working directory.
async fn workspace_root(start~ : String = ".") -> String {
  let mut current = @fs.realpath(start)
  for ;; {
    if @fs.exists(current + "/moon.work") &&
      @fs.exists(current + "/commands") &&
      @fs.exists(current + "/tests/registry/registry.json") {
      return current
    }
    let parent = @path.Path(current).dirname().normalize().to_string()
    if parent == current {
      fail("cannot locate cmd workspace root from " + start)
    }
    current = parent
  }
}

///|
fn workspace_path(root : String, relative : String) -> String {
  @path.Path(root).join(Path(relative)).normalize().to_string()
}

///|
/// Explicit relative inputs resolve from the caller, with repository-relative
/// fallback for documented paths. Defaults are rooted before this helper runs.
async fn workspace_input(
  root : String,
  configured : String,
  start~ : String = ".",
) -> String {
  if @path.Path(configured).is_absolute() {
    return @path.Path(configured).normalize().to_string()
  }
  let near_start = workspace_path(@fs.realpath(start), configured)
  if @fs.exists(near_start) {
    return near_start
  }
  let from_root = workspace_path(root, configured)
  if @fs.exists(from_root) {
    from_root
  } else {
    near_start
  }
}

///|
/// Output paths use the caller's working directory even before they exist.
async fn workspace_output(configured : String, start~ : String = ".") -> String {
  if @path.Path(configured).is_absolute() {
    @path.Path(configured).normalize().to_string()
  } else {
    workspace_path(@fs.realpath(start), configured)
  }
}

///|
fn registered_cohort_cases(
  registry : @registry.Registry,
) -> Array[@testkit.Case] raise {
  let fixtures = cohort_cases()
  for fixture in fixtures {
    let kind = if fixture.comparison == Some("policy") {
      "policy-test"
    } else {
      "compatibility-cohort"
    }
    let binding = "tests/runner/cohorts.mbt::" + fixture.id
    let owners = registry.entries.filter(entry => {
      entry.implementation == kind && entry.source == binding
    })
    guard owners.length() == 1 else {
      fail(
        "cohort selection requires one registered typed binding: " + fixture.id,
      )
    }
  }
  fixtures
}

///|
/// Default scenario suites run only the backends declared by their typed
/// registry owner. Explicit case selection keeps the scenario's diagnostic
/// rejection path available without reporting that skip as ordinary evidence.
fn registered_scenario_backend_selected(
  registry : @registry.Registry,
  fixture : @testkit.Case,
  backend : String,
  explicit_ids : Array[String],
) -> Bool raise {
  if ![Some("scenario"), Some("oracle-scenario")].contains(fixture.comparison) {
    return true
  }
  let binding = "tests/runner/scenarios.mbt::" + fixture.id
  let owners = registry.entries.filter(entry => {
    entry.implementation == "stateful-scenario" && entry.source == binding
  })
  guard owners.length() == 1 else {
    fail(
      "scenario selection requires one registered typed binding: " + fixture.id,
    )
  }
  !explicit_ids.is_empty() || owners[0].required_backends.contains(backend)
}
