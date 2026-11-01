///|
/// Locate the owning workspace without changing the process working directory.
async fn workspace_root(start~ : String = ".") -> String {
  @harness.repository_root(start~)
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
  registry : @catalog.Registry,
) -> Array[@harness.Case] raise {
  let fixtures = @scenarios.cohort_cases()
  for fixture in fixtures {
    let kind = if fixture.comparison == Some("policy") {
      "policy-test"
    } else {
      "compatibility-cohort"
    }
    let binding = "tests/scenarios/cohorts.mbt::" + fixture.id
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
