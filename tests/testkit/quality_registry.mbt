///|
let active_quality_descriptors : Ref[Map[String, Json]?] = Ref(None)

///|
pub fn local_quality_descriptor(id : String) -> Json? {
  match active_quality_descriptors.val {
    Some(rows) => rows.get(id)
    None => None
  }
}

///|
pub fn case_stimulus_digest(fixture : Case) -> String raise {
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
pub async fn configure_local_quality(
  path : String,
  cases : Array[Case],
  scenario_ids : Array[String],
) -> Unit {
  let catalog = @json.parse(@fs.read_file(path).text())
  guard quality_field(catalog, "schema") == Json(1) &&
    quality_field(catalog, "descriptors") is Object(descriptors) &&
    quality_field(catalog, "definitions") is Array(definitions) else {
    fail("missing local assertion quality registry")
  }
  let documents : Map[String, Json] = Map([])
  let stimuli : Map[String, String] = Map([])
  for fixture in cases {
    let identity = case_stimulus_digest(fixture)
    guard stimuli.get(identity) is None else {
      fail(
        "duplicate regression stimulus: " +
        stimuli[identity] +
        " / " +
        fixture.id +
        "; consolidate independent assertions and preserve aliases",
      )
    }
    stimuli[identity] = fixture.id
    guard definitions.filter(row => {
        quality_field(row, "case_id") == Json(fixture.id)
      })
      is [definition] &&
      quality_field(definition, "source") is String(source) &&
      descriptors.get(fixture.id) is Some(descriptor) else {
      fail("missing or duplicate local quality definition: " + fixture.id)
    }
    let document = match documents.get(source) {
      Some(value) => value
      None => {
        let value = @json.parse(@fs.read_file(source).text())
        documents[source] = value
        value
      }
    }
    guard quality_field(document, "cases") is Array(rows) &&
      rows.filter(row => quality_field(row, "id") == Json(fixture.id)) is [raw] &&
      quality_field(definition, "definition_sha256") == Json(json_digest(raw)) else {
      fail("stale local quality definition: " + fixture.id)
    }
    let current : Case = @json.from_json(raw)
    guard Json(current) == Json(fixture) else {
      fail(
        "selected local assertion differs from reviewed definition: " +
        fixture.id,
      )
    }
    let errors = case_quality_errors(
      fixture,
      descriptor~,
      wired_observers=quality_wired_observers(fixture, scenario_ids),
    )
    guard errors.is_empty() else { fail(fixture.id + ": " + errors.join("; ")) }
  }
  guard definitions.length() == cases.length() &&
    descriptors.length() == cases.length() else {
    fail("obsolete or extra local quality definitions")
  }
  active_quality_descriptors.val = Some(descriptors)
}

///|
/// Generate schema-1 descriptors from the same classifier used by validation.
/// Raw definitions retain their exact canonical hashes; this is definition
/// inventory only and never substitutes for executing independent assertions.
pub async fn generate_local_quality_catalog(output : String) -> Unit {
  guard !@fs.exists(output) else {
    fail("preserve existing quality catalog output")
  }
  let files = @fs.readdir("tests/cases").filter(name => name.has_suffix(".json"))
  files.sort()
  let definitions : Array[Json] = []
  let counts : Map[String, Int32] = Map([])
  let descriptors : Map[String, Json] = Map([])
  let stimuli : Map[String, String] = Map([])
  for name in files {
    let source = "tests/cases/" + name
    let document = @json.parse(@fs.read_file(source).text())
    guard quality_field(document, "cases") is Array(rows) else {
      fail("quality catalog source requires cases: " + source)
    }
    for raw in rows {
      let fixture : Case = @json.from_json(raw)
      let id = fixture.id
      guard !id.is_empty() && !descriptors.contains(id) else {
        fail("missing or duplicate case identity")
      }
      let stimulus = case_stimulus_digest(fixture)
      guard stimuli.get(stimulus) is None else {
        fail("duplicate regression stimulus: " + stimuli[stimulus] + " / " + id)
      }
      stimuli[stimulus] = id
      let (category, descriptor, required_work) = quality_catalog_classification(
        fixture,
      )
      counts[category] = counts.get(category).unwrap_or(0) + 1
      descriptors[id] = descriptor
      definitions.push({
        "case_id": id,
        "source": source,
        "definition_sha256": json_digest(raw),
        "classification": category,
        "descriptor": descriptor,
        "required_work": required_work,
      })
    }
  }
  let report : Json = {
    "schema": 1,
    "scope": "Independent local assertion classification only; semantic activation and actual execution are separate requirements. Exact retained bytes were never filled from candidate output.",
    "counts": Json(counts),
    "definitions": Json(definitions),
    "descriptors": Json(descriptors),
  }
  @fs.write_file(output, report.stringify(indent=2) + "\n")
  println("classified \{definitions.length()} current case definitions")
}
