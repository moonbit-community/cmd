///|
pub async fn metadata_version(name : String) -> String {
  if command_version(name) is Some(version) {
    return version
  }
  for line in @fs.read_file("commands/" + name + "/moon.mod").text().split("\n") {
    if line.trim().strip_prefix("version = \"") is Some(value) &&
      value.strip_suffix("\"") is Some(version) {
      return version.to_owned()
    }
  }
  fail("missing metadata package version: " + name)
}

///|
pub async fn metadata_contract_snapshot(cases : Array[Case]) -> Json {
  let expectations : Map[String, Json] = Map([])
  for fixture in cases {
    if fixture.comparison == Some("metadata") {
      let version = metadata_version(fixture.command)
      expectations[fixture.id] = {
        "observer_schema": 1,
        "version_stdout": fixture.command + " " + version + "\n",
        "status": 0,
        "stderr": "",
        "stdin_unread": "metadata stdin must remain unread\n",
        "help_prefix": "Usage: " + fixture.command,
        "help_required": ["--help", "--version"],
        "help_final_lf": true,
      }
    }
  }
  Json(expectations)
}
