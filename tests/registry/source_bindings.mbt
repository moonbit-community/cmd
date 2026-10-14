///|
fn test_name(line : String) -> String? raise {
  let line = line.trim().to_owned()
  let literal = if line.has_prefix("async test ") {
    line.strip_prefix("async test ")
  } else {
    line.strip_prefix("test ")
  }
  guard literal is Some(literal) else { return None }
  guard literal.strip_suffix(" {") is Some(literal) else {
    fail("test declaration needs a single stable name: " + line)
  }
  guard @json.parse(literal.to_owned()) is String(name) else {
    fail("test declaration needs a stable name: " + line)
  }
  Some(name)
}

///|
async fn scan_package_tests(
  root : String,
  relative : String,
  references : Array[String],
) -> Unit {
  let path = root + relative
  for name in @fs.readdir(path, sort=true) {
    if name.has_prefix(".") || name == "_build" || name == "target" {
      continue
    }
    let next = relative + "/" + name
    match @fs.kind(root + next, follow_symlink=false) {
      Directory => scan_package_tests(root, next, references)
      Regular if name.has_suffix("_test.mbt") || name.has_suffix("_wbtest.mbt") =>
        for line in @fs.read_file(root + next).text().split("\n") {
          if test_name(line.to_owned()) is Some(name) {
            references.push(next + "::" + name)
          }
        }
      _ => ()
    }
  }
}

///|
fn cohort_ids(source : String) -> Array[String] {
  let names : Array[String] = []
  let mut inside = false
  let mut next_line = false
  for line in source.split("\n") {
    let line = line.trim()
    if line.has_prefix("let specs :") {
      inside = true
      continue
    }
    if !inside {
      continue
    }
    if line == "]" {
      break
    }
    if line == "(" {
      next_line = true
    } else if line.has_prefix("(\"") || (next_line && line.has_prefix("\"")) {
      let pieces = line.split("\"").collect()
      if pieces.length() >= 3 {
        names.push(pieces[1].to_owned())
      }
      next_line = false
    }
  }
  names
}

///|
fn dispatch_ids(source : String) -> Array[String] {
  let names : Array[String] = []
  let mut inside = false
  for line in source.split("\n") {
    let line = line.trim()
    if line == "match fixture.id {" {
      inside = true
      continue
    }
    if !inside {
      continue
    }
    if line == "}" {
      inside = false
      continue
    }
    if line.has_prefix("\"") {
      let pieces = line.split("\"").collect()
      if pieces.length() >= 3 && pieces[2].trim().has_prefix("=>") {
        names.push(pieces[1].to_owned())
      }
    }
  }
  names
}

///|
fn compare_references(
  discovered : ArrayView[String],
  registered : ArrayView[String],
  kind : String,
  failures : Array[String],
) -> Unit {
  let discovered_seen : Map[String, Bool] = Map([])
  for reference in discovered {
    if discovered_seen.contains(reference) {
      failures.push(
        "registry: duplicate source " + kind + " '" + reference + "'",
      )
    }
    discovered_seen[reference] = true
    if !registered.contains(reference) {
      failures.push("registry: unregistered " + kind + " '" + reference + "'")
    }
  }
  let registered_seen : Map[String, Bool] = Map([])
  for reference in registered {
    if registered_seen.contains(reference) {
      failures.push(
        "registry: duplicate registered " + kind + " '" + reference + "'",
      )
    }
    registered_seen[reference] = true
    if !discovered.contains(reference) {
      failures.push("registry: orphan " + kind + " '" + reference + "'")
    }
  }
}

///|
async fn command_names(directory : String) -> Array[String] {
  let commands : Array[String] = []
  for command in @fs.readdir(directory, sort=true) {
    let path = directory + "/" + command
    guard @fs.kind(path, follow_symlink=false) is Directory else { continue }
    if @fs.exists(path + "/moon.mod") {
      commands.push(command)
    }
  }
  commands
}

///|
fn validate_case_source(
  registry : Registry,
  source : String,
  cases : ArrayView[Json],
) -> Array[String] {
  let failures : Array[String] = []
  for item in cases {
    guard item is { "id": String(id), "command": String(command), .. } else {
      failures.push(
        "registry: case source lacks a stable ID and command '\{source}'",
      )
      continue
    }
    let entries = registry.entries.filter(entry => {
      entry.is_case() && entry.case_id == id
    })
    if entries.length() == 1 {
      let entry = entries[0]
      if entry.source != source || entry.command != command {
        failures.push(
          "registry: case binding source or command mismatch '\{id}'",
        )
      }
      let platforms : Array[String] = if item is { "host_platforms": value, .. } {
        @json.from_json(value) catch {
          _ => ["invalid"]
        }
      } else {
        []
      }
      if !platforms.all(platform => entry.platforms.contains(platform)) ||
        !entry.platforms.all(platform => platforms.contains(platform)) {
        failures.push("registry: case platform exception mismatch '\{id}'")
      }
    }
  }
  failures
}

///|
/// Check executable source ownership as well as the JSON corpus. This check
/// deliberately discovers named tests from source; a directory-level row is
/// not evidence that every package test has been registered.
pub async fn validate_source_bindings(
  registry : Registry,
  root~ : String = "",
) -> Array[String] {
  let root = if root == "" || root.has_suffix("/") { root } else { root + "/" }
  let failures : Array[String] = []
  let package_tests : Array[String] = []
  for directory in ["core", "commands", "tests"] {
    scan_package_tests(root, directory, package_tests)
  }
  let registered = registry.entries
    .filter(entry => entry.implementation == "package-test")
    .map(entry => entry.source)
  compare_references(package_tests, registered, "package test", failures)
  let exceptions : PlatformExceptions = @json.from_json(
    @json.parse(
      @fs.read_file(root + "tests/registry/platform-exceptions.json").text(),
    ),
  )
  failures.append(
    validate_platform_exceptions(exceptions, registry, package_tests),
  )
  let lifecycle_path = root + "tests/registry/lifecycle.json"
  if @fs.exists(lifecycle_path) {
    let lifecycle : LifecycleRegistry = @json.from_json(
      @json.parse(@fs.read_file(lifecycle_path).text()),
    )
    failures.append(
      validate_lifecycle_bindings(lifecycle, registry, package_tests),
    )
  } else {
    failures.push("registry: missing lifecycle registry")
  }
  for entry in registry.entries {
    let parts = entry.source.split("::").collect()
    let file = parts[0].to_owned()
    let expected_file = match entry.implementation {
      "stateful-scenario" => "tests/runner/scenarios.mbt"
      "compatibility-cohort" | "policy-test" => "tests/runner/cohorts.mbt"
      "metadata-probe" => "tests/metadata/verify.mbtx"
      _ => file
    }
    if file != expected_file {
      failures.push("registry: wrong executable source '\{entry.source}'")
    }
    if entry.implementation == "metadata-probe" &&
      (parts.length() != 2 || parts[1] != entry.command) {
      failures.push(
        "registry: metadata command binding mismatch '\{entry.source}'",
      )
    }
    if entry.implementation == "stateful-scenario" && parts.length() == 2 {
      let cases = registry.entries.filter(item => {
        item.is_case() && item.case_id == parts[1].to_owned()
      })
      if cases.length() != 1 ||
        !entry.platforms.all(platform => cases[0].platforms.contains(platform)) ||
        !cases[0].platforms.all(platform => entry.platforms.contains(platform)) {
        failures.push(
          "registry: scenario platform applicability differs from its case '\{entry.source}'",
        )
      }
    }
    if entry.implementation == "policy-test" &&
      (
        parts.length() != 2 ||
        parts[1] != "policy-host" ||
        entry.required_backends != ["wasm"]
      ) {
      failures.push("registry: policy execution requires its Wasm host binding")
    }
    if entry.implementation == "compatibility-cohort" &&
      entry.required_backends != ["native"] {
      failures.push("registry: retained cohort execution requires Native")
    }
    if entry.behavior_id == "cohort:gnu-host" && entry.platforms != ["linux"] {
      failures.push(
        "registry: GNU host cohort requires the Linux platform exception",
      )
    }
    if !@fs.exists(root + file) {
      failures.push("registry: missing source '" + file + "'")
      continue
    }
    if entry.implementation == "package-test" {
      let path = file.split("/").collect()
      let directory = path[:path.length() - 1]
        .map(part => part.to_owned())
        .join("/")
      let expected = package_backends(
        @fs.read_file(root + directory + "/moon.pkg").text(),
      )
      if !entry.required_backends.all(backend => expected.contains(backend)) ||
        !expected.all(backend => entry.required_backends.contains(backend)) {
        failures.push("registry: package backend mismatch '\{entry.source}'")
      }
    }
    if ["stateful-scenario", "compatibility-cohort", "policy-test"].contains(
        entry.implementation,
      ) {
      if parts.length() != 2 ||
        !@fs.read_file(root + file)
        .text()
        .contains("\"" + parts[1].to_owned() + "\"") {
        failures.push(
          "registry: missing implementation reference '" + entry.source + "'",
        )
      }
    }
  }
  let commands = command_names(root + "commands")
  compare_references(
    commands,
    implementation_ids(registry, "metadata-probe"),
    "metadata probe",
    failures,
  )
  let cohorts = cohort_ids(
    @fs.read_file(root + "tests/runner/cohorts.mbt").text(),
  )
  let registered_cohorts = implementation_ids(registry, "compatibility-cohort")
  registered_cohorts.append(implementation_ids(registry, "policy-test"))
  compare_references(cohorts, registered_cohorts, "cohort", failures)
  compare_references(
    dispatch_ids(@fs.read_file(root + "tests/runner/cohorts.mbt").text()),
    registered_cohorts,
    "cohort dispatch",
    failures,
  )
  compare_references(
    dispatch_ids(@fs.read_file(root + "tests/runner/scenarios.mbt").text()),
    implementation_ids(registry, "stateful-scenario"),
    "scenario dispatch",
    failures,
  )
  let scenarios : Array[String] = []
  let sources : Array[String] = []
  for name in @fs.readdir(root + "tests/cases", sort=true) {
    if name.has_suffix(".json") {
      sources.push("tests/cases/" + name)
    }
  }
  compare_references(sources, case_sources(registry), "case source", failures)
  let case_ids : Array[String] = []
  for path in sources {
    if @json.parse(@fs.read_file(root + path).text())
      is { "cases": Array(cases), .. } {
      failures.append(validate_case_source(registry, path, cases))
      for item in cases {
        if item is { "id": String(id), .. } {
          case_ids.push(id)
        }
        if item is { "id": String(id), "comparison": String(comparison), .. } &&
          ["scenario", "oracle-scenario"].contains(comparison) {
          scenarios.push(id)
        }
      }
    } else {
      failures.push("registry: case source has no cases '\{path}'")
    }
  }
  failures.append(validate_case_bindings(registry, case_ids))
  compare_references(
    scenarios,
    implementation_ids(registry, "stateful-scenario"),
    "scenario",
    failures,
  )
  failures
}
