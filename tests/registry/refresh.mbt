///|
/// Discovery adds bindings but never replaces reviewed behavior metadata.
/// Removed or renamed sources need an explicit reviewed identity migration.
fn merge_package_test_bindings(
  registry : Registry,
  discovered : ArrayView[RegistryEntry],
) -> Registry raise Failure {
  let entries = registry.entries.copy()
  let sources : Map[String, Bool] = Map([])
  for entry in discovered {
    guard entry.implementation == "package-test" && entry.case_id == "" else {
      fail("refresh: discovery must contain only named package-test bindings")
    }
    if sources.contains(entry.source) {
      fail(
        "refresh: duplicate discovered package-test binding '" +
        entry.source +
        "'",
      )
    }
    sources[entry.source] = true
    let existing = registry.entries.filter(registered => {
      registered.implementation == "package-test" &&
      registered.source == entry.source
    })
    if existing.length() > 1 {
      fail(
        "refresh: duplicate reviewed package-test binding '" +
        entry.source +
        "'",
      )
    }
    if existing.is_empty() {
      entries.push(entry)
    }
  }
  for entry in registry.entries {
    if entry.implementation == "package-test" && !sources.contains(entry.source) {
      fail(
        "refresh: removed package-test binding needs an explicit identity migration '" +
        entry.source +
        "'",
      )
    }
  }
  { ..registry, entries, }
}

///|
/// Refresh only new package-test bindings. Existing entries and release
/// policy remain exactly as reviewed; source validation detects later drift.
pub async fn refresh_package_tests(
  registry : Registry,
  root~ : String = "",
) -> Registry {
  let root = if root == "" || root.has_suffix("/") { root } else { root + "/" }
  let references : Array[String] = []
  for directory in ["commands", "core", "tests"] {
    scan_package_tests(root, directory, references)
  }
  let exceptions : PlatformExceptions = @json.from_json(
    @json.parse(
      @fs.read_file(root + "tests/registry/platform-exceptions.json").text(),
    ),
  )
  let discovered : Array[RegistryEntry] = []
  for reference in references {
    let parts = reference.split("::").collect()
    let file = parts[0].to_owned()
    let name = parts[1].to_owned()
    let components = file.split("/").collect()
    let owner = components[:components.length() - 1]
      .map(component => component.to_owned())
      .join("/")
    let platforms = exceptions.exceptions
      .filter(item => item.source == reference)
      .get(0)
      .map(item => item.platforms)
      .unwrap_or([])
    let backends = package_backends(
      @fs.read_file(root + owner + "/moon.pkg").text(),
    )
    discovered.push({
      behavior_id: "package-test:" + reference,
      command: if components[0] == "commands" {
        components[1].to_owned()
      } else {
        ""
      },
      owner,
      surface: ["package-api"],
      status: "supported",
      implementation: "package-test",
      source: reference,
      case_id: "",
      aliases: [],
      coverage: [name],
      required_backends: backends,
      platforms,
      required_evidence: if backends.contains("native") &&
        backends.contains("wasm") {
        ["contract", "backend-pair"]
      } else {
        ["contract"]
      },
      observations: ["status"],
      oracle_profile: "",
    })
  }
  merge_package_test_bindings(registry, discovered)
}
