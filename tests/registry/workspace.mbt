///|
pub async fn refresh_workspace_registry() -> Unit {
  let path = "tests/registry/registry.json"
  let current = load(path)
  let refreshed = refresh_package_tests(current)
  let failures = validate(refreshed)
  failures.append(validate_source_bindings(refreshed))
  guard failures.is_empty() else { fail(failures.join("\n")) }
  // This compatibility sidecar is generated output, never a release input.
  let compatibility : Json = {
    "schema": 1,
    "commands": Json(refreshed.release_commands),
  }
  @fs.write_file(path, refreshed.to_json().stringify(indent=2) + "\n")
  @fs.write_file(
    "tests/registry/release-profiles.json",
    compatibility.stringify(indent=2) + "\n",
  )
  println("registered " + refreshed.entries.length().to_string() + " behaviors")
}

///|
/// Explicit strengthening migration after adding metadata, package and scenario
/// pair executors. Refresh itself still preserves all reviewed requirements.
pub async fn strengthen_workspace_backend_pairs() -> Unit {
  let path = "tests/registry/registry.json"
  let current = load(path)
  let exceptions : PlatformExceptions = @json.from_json(
    @json.parse(@fs.read_file("tests/registry/platform-exceptions.json").text()),
  )
  let entries = current.entries.map(entry => {
    let evidence = entry.required_evidence.copy()
    if entry.requires_backend_pair() && !evidence.contains("backend-pair") {
      evidence.push("backend-pair")
    }
    let platforms = if entry.implementation == "stateful-scenario" {
      let name = entry.source.split("::").collect()[1].to_owned()
      current.entries
      .filter(item => item.is_case() && item.case_id == name)
      .get(0)
      .map(item => item.platforms)
      .unwrap_or(entry.platforms)
    } else if entry.implementation == "package-test" {
      exceptions.exceptions
      .filter(item => item.source == entry.source)
      .get(0)
      .map(item => item.platforms)
      .unwrap_or(entry.platforms)
    } else {
      entry.platforms
    }
    { ..entry, required_evidence: evidence, platforms, }
  })
  let updated = refresh_package_tests({ ..current, entries, })
  let failures = validate(updated)
  failures.append(validate_source_bindings(updated))
  guard failures.is_empty() else { fail(failures.join("\n")) }
  @fs.write_file(path, updated.to_json().stringify(indent=2) + "\n")
  println(
    "strengthened supported dual-backend contracts and refreshed package bindings",
  )
}

///|
fn migrate_release_metadata_document(
  registry : Json,
  compatibility : Json,
) -> Registry raise {
  guard registry is Object(fields) &&
    fields.get("schema") == Some(Json(1)) &&
    !fields.contains("release_commands") else {
    fail("release metadata migration requires an unmigrated schema 1 registry")
  }
  guard compatibility
    is { "schema": Number(1, ..), "commands": Array(commands), .. } else {
    fail("release metadata migration requires the reviewed schema 1 metadata")
  }
  let migrated_fields = fields.copy()
  migrated_fields["schema"] = Json(2)
  migrated_fields["release_commands"] = Json(commands)
  let migrated : Registry = @json.from_json(Json(migrated_fields))
  let failures = validate(migrated)
  guard failures.is_empty() else { fail(failures.join("\n")) }
  migrated
}

///|
pub async fn migrate_workspace_release_metadata() -> Unit {
  let path = "tests/registry/registry.json"
  let migrated = migrate_release_metadata_document(
    @json.parse(@fs.read_file(path).text()),
    @json.parse(@fs.read_file("tests/registry/release-profiles.json").text()),
  )
  @fs.write_file(path, migrated.to_json().stringify(indent=2) + "\n")
  println("migrated reviewed release metadata into registry schema 2")
}
