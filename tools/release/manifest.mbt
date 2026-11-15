///|
async fn module_field(path : String, key : String) -> String {
  let prefix = key + " = \""
  for line in @fs.read_file(path).text().split("\n") {
    if line.trim().strip_prefix(prefix) is Some(value) &&
      value.strip_suffix("\"") is Some(value) {
      return value.to_owned()
    }
  }
  fail("missing " + key + " in " + path)
}

///|
async fn generate_candidate(output : String) -> Unit {
  let registry = @catalog.load("tests/cases/index.json")
  let failures = @catalog.validate(registry)
  guard failures.is_empty() else { fail(failures.join("\n")) }
  let cases = @harness.load_cases("tests/cases/manifest.json")
  let commands = registry.release_commands.filter(row => row.releasable)
  commands.sort_by((a, b) => a.name.lexical_compare(b.name))
  let rows : Array[Json] = []
  let selected : Set[String] = Set([])
  for command in commands {
    let module_path = "commands/" + command.name + "/moon.mod"
    guard module_field(module_path, "name") == command.package_name else {
      fail("module name mismatch: " + command.name)
    }
    let version = module_field(module_path, "version")
    rows.push({
      "name": command.name,
      "package_name": command.package_name,
      "version": version,
      "published": false,
      "compare_profile": command.compare_profile,
      "supported_options": command.supported_options,
      "policy_sensitive": command.policy_sensitive,
    })
    guard command.case_ids is Some(ids) && !ids.is_empty() else {
      fail("missing release cases: " + command.name)
    }
    for fixture in @harness.select_cases(cases, [], ids) {
      selected.add(fixture.id)
    }
  }
  let ids = selected.iter().collect()
  ids.sort()
  let candidate : Json = {
    "schema": 2,
    "candidate": true,
    "core_version": module_field("core/moon.mod", "version"),
    "base_manifest": "../cases/manifest.json",
    "commands": rows,
    "case_ids": ids,
    "extra_cases": [],
  }
  @fs.write_file(output, candidate.stringify(indent=2) + "\n")
  println(
    "Prepared \{commands.length()} candidate coordinates; no packages were published.",
  )
}
