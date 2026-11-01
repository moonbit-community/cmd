///|
pub struct ScenarioProof {
  case_id : String
  definitions : Array[Json]
  records : Array[Json]
  definition_id : Json
}

///|
fn scenario_field(value : Json, key : String) -> Json {
  match value {
    Object(fields) => fields.get(key).unwrap_or(Json::null())
    _ => Json::null()
  }
}

///|
fn scenario_rows(value : Json) -> Array[Json] {
  match value {
    Array(items) => items
    _ => []
  }
}

///|
pub fn scenario_definition(catalog : Json, id : String) -> Json? {
  let matches = scenario_rows(scenario_field(catalog, "scenarios")).filter(row => {
    scenario_field(row, "case_id") == Json(id)
  })
  if matches is [definition] {
    Some(definition)
  } else {
    None
  }
}

///|
pub fn ScenarioProof::new(id : String, definition : Json) -> ScenarioProof {
  {
    case_id: id,
    definitions: scenario_rows(scenario_field(definition, "assertions")),
    records: [],
    definition_id: scenario_field(definition, "case_id"),
  }
}

///|
pub fn ScenarioProof::accepts(
  self : ScenarioProof,
  id : String,
  command : String,
) -> Bool {
  self.definitions.any(row => {
    scenario_field(row, "id") == Json(id) &&
    scenario_field(row, "command") == Json(command)
  })
}

///|
pub fn ScenarioProof::observe_equal(
  self : ScenarioProof,
  id : String,
  command : String,
  actual : Json,
  expected : Json,
) -> Unit {
  if self.accepts(id, command) {
    self.records.push({
      "id": id,
      "command": command,
      "relation": "equal",
      "actual": scenario_freeze_json(actual),
      "expected": scenario_freeze_json(expected),
    })
  }
}

///|
pub fn ScenarioProof::observe_pair(
  self : ScenarioProof,
  id : String,
  command : String,
  actual : String,
  control : String,
) -> Unit {
  if self.accepts(id, command) {
    self.records.push({
      "id": id,
      "command": command,
      "relation": "equal-pair",
      "value_kind": "octal-mode",
      "actual": [actual, control],
    })
  }
}

///|
pub fn ScenarioProof::receipt(self : ScenarioProof) -> Json {
  { "schema": 1, "case_id": self.case_id, "assertions": Json(self.records) }
}

///|
pub fn scenario_assertion_errors(
  definition : Json,
  record : Json,
) -> Array[String] {
  let errors : Array[String] = []
  if !(record is Object(fields) && fields.contains("actual")) {
    errors.push("actual assertion observation is absent")
  }
  if scenario_field(definition, "id") != scenario_field(record, "id") ||
    scenario_field(definition, "command") != scenario_field(record, "command") ||
    scenario_field(definition, "relation") != scenario_field(record, "relation") {
    errors.push("assertion identity, command or relation differs")
  }
  match scenario_field(definition, "relation") {
    String("equal") => {
      if !(definition is Object(fields) && fields.contains("expected")) ||
        !(record is Object(fields) && fields.contains("expected")) {
        errors.push("exact assertion expectation is absent")
      }
      if scenario_field(record, "expected") !=
        scenario_field(definition, "expected") {
        errors.push(
          "executing assertion expectation differs from reviewed descriptor",
        )
      }
      if scenario_field(record, "actual") !=
        scenario_field(definition, "expected") {
        errors.push("actual observation differs from reviewed expectation")
      }
    }
    String("equal-pair") => {
      if scenario_field(definition, "value_kind") != Json("octal-mode") ||
        scenario_field(record, "value_kind") != Json("octal-mode") {
        errors.push("unsupported relational value kind")
      }
      match scenario_field(record, "actual") {
        Array([String(actual), String(control)]) => {
          let valid = fn(value : String) {
            value.length() >= 3 &&
            value.length() <= 4 &&
            value.iter().all(c => c >= '0' && c <= '7')
          }
          if actual != control || !valid(actual) || !valid(control) {
            errors.push(
              "actual and independent control modes differ or are malformed",
            )
          }
        }
        _ =>
          errors.push(
            "relational assertion requires both actual and control observations",
          )
      }
    }
    _ => errors.push("unknown scenario assertion relation")
  }
  errors
}

///|
pub fn scenario_catalog_errors(catalog : Json) -> Array[String] {
  let errors : Array[String] = []
  let scenes = scenario_rows(scenario_field(catalog, "scenarios"))
  if scenario_field(catalog, "schema") != Json(1) || scenes.is_empty() {
    errors.push("missing scenario catalog schema or definitions")
  }
  let seen : Set[String] = Set([])
  for scene in scenes {
    guard scenario_field(scene, "case_id") is String(id) &&
      safe_relative_path(id) &&
      !seen.contains(id) else {
      errors.push("empty, unsafe or duplicate scenario definition")
      continue
    }
    seen.add(id)
    let definitions = scenario_rows(scenario_field(scene, "assertions"))
    if definitions.is_empty() {
      errors.push("scenario has no typed assertions: " + id)
    }
    let ids : Set[String] = Set([])
    for row in definitions {
      guard scenario_field(row, "id") is String(name) &&
        !name.is_empty() &&
        !ids.contains(name) else {
        errors.push("empty or duplicate assertion descriptor: " + id)
        continue
      }
      ids.add(name)
      if !(scenario_field(row, "command") is String(command) &&
        !command.is_empty()) ||
        scenario_rows(scenario_field(row, "observations")).is_empty() {
        errors.push("assertion requires command and observations: " + name)
      }
      let dimensions : Set[String] = Set([])
      for dimension in scenario_rows(scenario_field(row, "observations")) {
        if dimension is String(value) &&
          !value.trim().is_empty() &&
          !dimensions.contains(value) {
          dimensions.add(value)
        } else {
          errors.push(
            "empty, nonstring or duplicate observation dimension: " + name,
          )
        }
      }
      match scenario_field(row, "relation") {
        String("equal") =>
          if !(row is Object(fields) && fields.contains("expected")) {
            errors.push(
              "exact assertion requires reviewed expected value: " + name,
            )
          }
        String("equal-pair") =>
          if scenario_field(row, "value_kind") != Json("octal-mode") {
            errors.push("unsupported relational assertion kind: " + name)
          }
        _ => errors.push("unsupported assertion relation: " + name)
      }
    }
  }
  errors
}

///|
pub fn scenario_receipt_errors(
  definition : Json,
  receipt : Json,
  required? : Array[String],
  command? : String,
) -> Array[String] {
  let errors : Array[String] = []
  if scenario_field(receipt, "schema") != Json(1) ||
    scenario_field(receipt, "case_id") != scenario_field(definition, "case_id") {
    errors.push("scenario receipt schema or identity differs")
  }
  let definitions = scenario_rows(scenario_field(definition, "assertions"))
  let records = scenario_rows(scenario_field(receipt, "assertions"))
  let seen : Set[String] = Set([])
  for record in records {
    guard scenario_field(record, "id") is String(id) else {
      errors.push("missing assertion identity")
      continue
    }
    if seen.contains(id) {
      errors.push("duplicate actual scenario assertion: " + id)
    }
    seen.add(id)
    let matches = definitions.filter(row => {
      scenario_field(row, "id") == Json(id)
    })
    if matches is [row] {
      errors.append(
        scenario_assertion_errors(row, record).map(error => id + ": " + error),
      )
    } else {
      errors.push("undeclared actual assertion: " + id)
    }
  }
  let ids = required.unwrap_or(
    definitions.map(row => {
      match scenario_field(row, "id") {
        String(id) => id
        _ => ""
      }
    }),
  )
  if ids.is_empty() {
    errors.push("empty required scenario assertion selection")
  }
  let selected : Set[String] = Set([])
  for id in ids {
    if selected.contains(id) {
      errors.push("duplicate required scenario assertion: " + id)
    }
    selected.add(id)
    let declared = definitions.filter(row => {
      scenario_field(row, "id") == Json(id)
    })
    if !(declared is [row] &&
      (
        command is None ||
        scenario_field(row, "command") == Json(command.unwrap())
      )) {
      errors.push(
        "missing or cross-command scenario assertion declaration: " + id,
      )
    }
    if !seen.contains(id) {
      errors.push("required actual assertion missing: " + id)
    }
  }
  errors
}

///|
pub fn ScenarioProof::errors(self : ScenarioProof) -> Array[String] {
  scenario_receipt_errors(
    { "case_id": self.definition_id, "assertions": Json(self.definitions) },
    self.receipt(),
  )
}

///|
fn scenario_freeze_json(value : Json) -> Json {
  match value {
    Object(fields) => {
      let frozen : Map[String, Json] = Map([])
      for key, value in fields {
        frozen[key] = scenario_freeze_json(value)
      }
      Json(frozen)
    }
    Array(items) => Json(items.map(scenario_freeze_json))
    _ => value
  }
}

///|
pub fn scenario_text(bytes : Bytes) -> String raise {
  @utf8.decode(bytes)
}
