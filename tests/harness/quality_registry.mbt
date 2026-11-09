///|
fn case_stimulus_digest(fixture : Case) -> String raise {
  let platforms = fixture.host_platforms
    .unwrap_or(["linux", "macos", "windows"])
    .copy()
  platforms.sort()
  let files : Array[Json] = []
  for file in fixture.files {
    files.push({
      "path": file.path,
      "kind": file.kind.unwrap_or("file"),
      "bytes": Json(input_bytes(file.content_hex, file.content_text, file.path)),
      "template": Json(file.content_text is Some(text) && text.contains("${")),
      "target": Json(file.target),
      "mode": Json(file.mode),
      "atime": Json(file.atime),
      "mtime": Json(file.mtime),
      "readable": Json(file.readable),
    })
  }
  // Scenario dispatch supplies its own streams, peers or child lifecycle.
  // Its observer identity is part of the stimulus, rather than an assertion.
  let dispatch = if [Some("scenario"), Some("oracle-scenario")].contains(
      fixture.comparison,
    ) {
    Json(fixture.id)
  } else {
    Json::null()
  }
  let stdin_template = fixture.stdin_text is Some(text) && text.contains("${")
  json_digest([
    Json(fixture.command),
    Json(fixture.args),
    Json(fixture.input()),
    Json(stdin_template),
    Json(files),
    Json(fixture.environment),
    Json(fixture.cwd.unwrap_or(".")),
    Json(platforms),
    Json(fixture.delay_ms.unwrap_or(0)),
    Json(fixture.timeout_ms.unwrap_or(15000)),
    dispatch,
  ])
}

///|
/// Validate the executing assertions directly from current cases.
pub fn validate_local_assertions(
  cases : Array[Case],
  scenario_ids : Array[String],
) -> Unit raise {
  let stimuli : Map[String, String] = Map([])
  for fixture in cases {
    let identity = case_stimulus_digest(fixture)
    guard stimuli.get(identity) is None else {
      fail(
        "duplicate regression stimulus: " +
        stimuli[identity] +
        " / " +
        fixture.id,
      )
    }
    stimuli[identity] = fixture.id
    let errors = case_assertion_errors(fixture, scenario_ids~)
    guard errors.is_empty() else { fail(fixture.id + ": " + errors.join("; ")) }
  }
}
