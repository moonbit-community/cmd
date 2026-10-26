///|
/// Release support and case selection. Candidate package versions are read
/// separately from current moon.mod files.
pub(all) struct ReleaseCommandMetadata {
  name : String
  package_name : String
  compare_profile : String
  supported_options : Array[String]
  policy_sensitive : Bool
  releasable : Bool
  case_ids : Array[String]?
} derive(FromJson, ToJson, Debug)

///|
fn validate_release_commands(registry : Registry) -> Array[String] {
  let failures : Array[String] = []
  let names : Map[String, Bool] = Map([])
  for command in registry.release_commands {
    if command.name == "" || names.contains(command.name) {
      failures.push(
        "registry: duplicate or empty release command '" + command.name + "'",
      )
    }
    names[command.name] = true
    if command.package_name != "cli/" + command.name {
      failures.push("registry: release package mismatch '" + command.name + "'")
    }
    if command.compare_profile == "" {
      failures.push(
        "registry: release compare profile required '" + command.name + "'",
      )
    }
    let options : Map[String, Bool] = Map([])
    for option in command.supported_options {
      if option == "" || options.contains(option) {
        failures.push(
          "registry: duplicate or empty release option '" + command.name + "'",
        )
      }
      options[option] = true
    }
    let ids : Map[String, Bool] = Map([])
    for id in command.case_ids.unwrap_or([]) {
      if id == "" || ids.contains(id) {
        failures.push(
          "registry: duplicate or empty release case '" + command.name + "'",
        )
      }
      ids[id] = true
      let bindings = registry.entries.filter(entry => {
        entry.is_case() && (entry.case_id == id || entry.aliases.contains(id))
      })
      if bindings.length() != 1 || bindings[0].command != command.name {
        failures.push(
          "registry: release case binding mismatch '" +
          command.name +
          "::" +
          id +
          "'",
        )
      }
    }
    if !command.releasable && !command.case_ids.unwrap_or([]).is_empty() {
      failures.push(
        "registry: nonreleasable command selects release cases '" +
        command.name +
        "'",
      )
    }
  }
  failures
}

///|
pub extend ReleaseCommandMetadata with @json.FromJson::{from_json}

///|
pub extend ReleaseCommandMetadata with ToJson::{to_json}

///|
pub extend ReleaseCommandMetadata with @debug.Debug::{to_repr}
