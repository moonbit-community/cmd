///|
fn quality_field(value : Json, name : String) -> Json {
  match value {
    Object(fields) => fields.get(name).unwrap_or(Json::null())
    _ => Json::null()
  }
}

///|
fn quality_exact(fixture : Case, stream : String) -> Bool {
  match stream {
    "stdout" =>
      fixture.expected_stdout_json is None &&
      (
        fixture.expected_stdout_hex is Some(_) ||
        (fixture.expected_stdout_text is Some(text) && !runtime_template(text))
      )
    "stderr" =>
      fixture.expected_stderr_text is Some(_) ||
      fixture.expected_stderr_hex is Some(_)
    _ => false
  }
}

///|
fn quality_fragments(fixture : Case, stream : String) -> Array[String] {
  let (single, multiple) = match stream {
    "stdout" =>
      (fixture.expected_stdout_contains, fixture.expected_stdout_contains_all)
    _ =>
      (fixture.expected_stderr_contains, fixture.expected_stderr_contains_all)
  }
  let result = multiple.unwrap_or([]).copy()
  if single is Some(value) {
    result.push(value)
  }
  result
}

///|
// Keep the generator's typed-output classification aligned with the observers
// the local runner can actually execute. A familiar case name is insufficient.
fn quality_dynamic_observers(fixture : Case) -> Array[String] {
  let observers = runtime_contract_observers(fixture)
  if ["release-metadata-rg-help", "compat-catalog-line-277"].contains(
      fixture.id,
    ) &&
    observers.is_empty() {
    observers.push("dynamic:" + fixture.id)
  }
  observers
}

///|
fn quality_wired_observers(
  fixture : Case,
  scenario_ids : Array[String],
) -> Array[String] {
  let wired = quality_dynamic_observers(fixture)
  if scenario_ids.contains(fixture.id) {
    wired.push("scenario:" + fixture.id)
  }
  wired
}

///|
// Catalog generation classifies independent assertions; it does not execute or
// certify them. Runtime validation still supplies its own observer inventory.
fn quality_catalog_classification(fixture : Case) -> (String, Json, String) {
  if [Some("scenario"), Some("oracle-scenario")].contains(fixture.comparison) {
    return (
      "typed-scenario",
      {
        "kind": "scenario",
        "reason": "Retain the existing scenario's independently asserted values and file or process effects; its executing observer must run all assertions before acceptance.",
        "required_observers": ["scenario:" + fixture.id],
      },
      "Wire the named observer to the existing scenario dispatch and validate its actual assertion outcome; never use the descriptor itself as evidence.",
    )
  }
  if !quality_dynamic_observers(fixture).is_empty() {
    return (
      "typed-dynamic-output",
      {
        "kind": "dynamic",
        "reason": fixture.diagnostic_reason.unwrap_or(""),
        "required_observers": ["dynamic:" + fixture.id],
        "streams": ["stdout"],
      },
      "Execute the named complete independent runtime or metadata assertion; the descriptor itself is not evidence.",
    )
  }
  if case_quality_kind(fixture) == "exact" {
    if fixture.comparison != Some("contract") &&
      fixture.expected_rejection is None {
      return (
        "independent-expectations-not-locally-executed",
        { "kind": "exact" },
        "Execute the existing exact expectations locally before accepting this definition.",
      )
    }
    return ("exact-local", { "kind": "exact" }, "")
  }
  if quality_exact(fixture, "stdout") {
    if quality_fragments(fixture, "stderr").any(value => {
        !value.trim().is_empty()
      }) {
      let supplied = fixture.diagnostic_reason.unwrap_or("")
      return (
        "finite-diagnostic",
        {
          "kind": "diagnostic-fragment",
          "reason": if supplied.trim().is_empty() {
            "The independently retained nonzero rejection status and exact stdout bind this finite failure; only the diagnostic's explicit rejection reason is matched."
          } else {
            supplied
          },
        },
        "",
      )
    }
    return (
      "missing-independent-stderr-assertion",
      Json::null(),
      "Add a bounded diagnostic or exact stderr expectation derived independently from the candidate.",
    )
  }
  (
    "missing-independent-stream-assertions",
    Json::null(),
    "Add exact independently derived streams or an explicit typed observer before local acceptance.",
  )
}

///|
fn quality_strings(value : Json) -> Array[String]? {
  guard value is Array(values) && !values.is_empty() else { return None }
  let result : Array[String] = []
  for value in values {
    guard value is String(text) &&
      !text.trim().is_empty() &&
      !result.contains(text) else {
      return None
    }
    result.push(text)
  }
  Some(result)
}

///|
/// Classifies the local assertions rather than the optional differential oracle.
/// This structural classification does not establish option activation or widen
/// the finite semantic scope of a reviewed fixture.
pub fn case_quality_kind(fixture : Case, descriptor? : Json) -> String {
  let kind = quality_field(descriptor.unwrap_or(Json::null()), "kind")
  match kind {
    String("scenario" | "dynamic" | "diagnostic-fragment" | "finite-fragment") => {
      guard kind is String(value) else { return "missing" }
      value
    }
    Null | String("exact") =>
      if quality_exact(fixture, "stdout") && quality_exact(fixture, "stderr") {
        "exact"
      } else {
        "missing"
      }
    _ => "missing"
  }
}

///|
/// Requires locally executed independent assertions even for differential cases.
/// Fragment and variable-output exceptions require an explicit reviewed
/// descriptor. `wired_observers` must come from the caller's executing observer
/// inventory, not from the case descriptor being validated. Actual execution
/// and receipt checks remain mandatory for acceptance.
pub fn case_quality_errors(
  fixture : Case,
  descriptor? : Json,
  wired_observers~ : Array[String] = [],
) -> Array[String] {
  let errors = contract_errors(fixture)
  let descriptor = descriptor.unwrap_or(Json::null())
  let kind = case_quality_kind(fixture, descriptor~)
  let scenario = fixture.comparison == Some("scenario") ||
    fixture.comparison == Some("oracle-scenario")
  if kind == "scenario" {
    if !scenario {
      errors.push("scenario quality requires an executing scenario case")
    }
  } else if fixture.comparison != Some("contract") &&
    fixture.expected_rejection is None {
    errors.push("independent stream assertions are not executed locally")
  }
  if fixture.expected_rejection is Some(_) && fixture.expected_status == 0 {
    errors.push("rejection quality requires an exact nonzero status")
  }
  if kind == "missing" {
    errors.push(
      "independent assertions require exact streams or an explicit finite, dynamic or scenario descriptor",
    )
    return errors
  }
  if kind == "exact" {
    return errors
  }
  if !(quality_field(descriptor, "reason") is String(reason) &&
    !reason.trim().is_empty()) {
    errors.push("nonexact quality requires an independent review reason")
  }
  if kind == "scenario" || kind == "dynamic" {
    match quality_strings(quality_field(descriptor, "required_observers")) {
      Some(required) =>
        for id in required {
          if !wired_observers.contains(id) {
            errors.push("independent observer is not wired: " + id)
          }
        }
      None => errors.push("typed quality requires nonempty unique observer IDs")
    }
    if kind == "scenario" {
      return errors
    }
    match quality_strings(quality_field(descriptor, "streams")) {
      Some(streams) => {
        for stream in streams {
          if !["stdout", "stderr"].contains(stream) {
            errors.push("unknown dynamic stream: " + stream)
          }
        }
        for stream in ["stdout", "stderr"] {
          if !quality_exact(fixture, stream) && !streams.contains(stream) {
            errors.push("dynamic observer does not bind " + stream)
          }
        }
      }
      None => errors.push("dynamic quality requires its observed streams")
    }
    return errors
  }
  for stream in ["stdout", "stderr"] {
    if quality_exact(fixture, stream) {
      continue
    }
    if kind == "diagnostic-fragment" && stream != "stderr" {
      errors.push("diagnostic fragment requires exact stdout")
      continue
    }
    let fragments = quality_fragments(fixture, stream)
    if fragments.is_empty() ||
      fragments.any(value => {
        value.trim().is_empty() || value.trim().length() < 3
      }) {
      errors.push(stream + " requires a finite nonvacuous fragment assertion")
    }
  }
  errors
}
