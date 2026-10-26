///|
/// Runtime case selection and publication policy. This index contains no
/// change-impact declarations or execution evidence requirements.
pub(all) struct RegistryEntry {
  behavior_id : String
  command : String
  status : String
  implementation : String
  source : String
  case_id : String
  aliases : Array[String]
  platforms : Array[String]
  oracle_profile : String
} derive(FromJson, ToJson, Debug)

///|
pub(all) struct Registry {
  schema : Int32
  entries : Array[RegistryEntry]
  release_commands : Array[ReleaseCommandMetadata]
} derive(FromJson, ToJson, Debug)

///|
pub fn RegistryEntry::is_case(self : RegistryEntry) -> Bool {
  self.implementation == "json-case"
}

///|
pub async fn load(path : String) -> Registry raise Failure {
  @json.from_json(@json.parse(@fs.read_file(path).text())) catch {
    error => fail("cannot read test index: " + error.to_string())
  }
}

///|
pub fn validate(registry : Registry) -> Array[String] {
  let failures : Array[String] = []
  if registry.schema != 3 {
    failures.push("unsupported test index schema")
  }
  let ids : Set[String] = Set([])
  let bindings : Set[String] = Set([])
  for entry in registry.entries {
    for id in [entry.behavior_id, ..entry.aliases] {
      if id.is_empty() || ids.contains(id) {
        failures.push("duplicate or empty test ID: " + id)
      }
      ids.add(id)
    }
    if (entry.command.is_empty() && entry.implementation != "policy-test") ||
      entry.source.is_empty() {
      failures.push("missing command or case source: " + entry.behavior_id)
    }
    let binding = entry.implementation +
      ":" +
      entry.command +
      ":" +
      entry.source +
      ":" +
      entry.case_id
    if bindings.contains(binding) {
      failures.push("duplicate test binding: " + binding)
    }
    bindings.add(binding)
    if ![
        "json-case", "stateful-scenario", "compatibility-cohort", "policy-test",
        "metadata-probe",
      ].contains(entry.implementation) {
      failures.push("unknown test implementation: " + entry.implementation)
    }
    if entry.is_case() && entry.case_id.is_empty() {
      failures.push("missing case ID: " + entry.behavior_id)
    }
    for platform in entry.platforms {
      if !["linux", "macos", "windows", "posix"].contains(platform) {
        failures.push("unknown platform: " + platform)
      }
    }
  }
  failures.append(validate_release_commands(registry))
  failures
}

///|
pub extend RegistryEntry with FromJson::{from_json}

///|
pub extend RegistryEntry with ToJson::{to_json}

///|
pub extend RegistryEntry with @debug.Debug::{to_repr}

///|
pub extend Registry with FromJson::{from_json}

///|
pub extend Registry with ToJson::{to_json}

///|
pub extend Registry with @debug.Debug::{to_repr}
