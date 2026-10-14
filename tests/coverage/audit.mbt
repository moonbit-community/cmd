///|
/// Report paths are repository-relative summary.jsonl files. Claims in this
/// record are checked against execution rows; they never substitute for them.
pub(all) struct CoverageRecord {
  behavior_id : String
  backends : Array[String]
  evidence : Array[String]
  observations : Array[String]
  result : String
  report : String?
  reports : Array[String]?
} derive(FromJson)

///|
pub(all) struct BoundaryRecord {
  behavior_id : String
  support_record : String
  adr : String
  current_limit : String
  unlock_condition : String
} derive(FromJson)

///|
pub(all) struct ChangeDeclaration {
  schema : Int32
  affected_commands : Array[String]
  affected_behaviors : Array[String]
  affected_options : Array[String]?
  affected_operands : Array[String]?
  case_ids : Array[String]?
  core_impact : String?
  published_manifest_affected : Bool?
  required_backends : Array[String]
  required_evidence : Array[String]
  required_observations : Array[String]
  coverage : Array[CoverageRecord]
  boundaries : Array[BoundaryRecord]
  deferred : Array[String]
  uncovered : Array[String]?
} derive(FromJson)

///|
pub(all) struct AuditOptions {
  base : String
  head : String
  declaration_path : String
  run_metadata_paths : Array[String]
  registry_path : String
  case_corpus_paths : Array[String]
  manifest_paths : Array[String]
  oracle_profile_paths : Array[String]
  report_path : String?
}

///|
pub(all) struct AuditReport {
  base : String
  head : String
  changed_paths : Array[String]
  affected_commands : Array[String]
  core_changed : Bool
  status : String
  findings : Array[String]
  run_ids : Array[String]
  uncovered : Array[String]
  unsupported : Array[String]
  boundary : Array[String]
  deferred : Array[String]
} derive(ToJson)

///|
fn sorted_unique(values : Array[String]) -> Array[String] {
  let seen : Map[String, Bool] = Map([])
  let result : Array[String] = []
  for value in values {
    if !seen.contains(value) {
      seen[value] = true
      result.push(value)
    }
  }
  result.sort()
  result
}

///|
fn find_entry(
  registry : @registry.Registry,
  id : String,
) -> @registry.RegistryEntry? {
  for entry in registry.entries {
    if entry.behavior_id == id ||
      entry.aliases.contains(id) ||
      (entry.implementation == "json-case" && entry.case_id == id) {
      return Some(entry)
    }
  }
  None
}

///|
fn canonical_ids(
  registry : @registry.Registry,
  ids : ArrayView[String],
) -> Array[String] {
  sorted_unique(
    ids.map(id => {
      match find_entry(registry, id) {
        Some(entry) => entry.behavior_id
        None => id
      }
    }),
  )
}

///|
fn command_from_path(path : String) -> String? {
  guard path.has_prefix("commands/") else { return None }
  path
  .strip_prefix("commands/")
  .unwrap()
  .split("/")
  .next()
  .map(name => name.to_owned())
}

///|
fn is_core_path(path : String) -> Bool {
  path == "core" || path.has_prefix("core/")
}

///|
fn valid_set(values : ArrayView[String], allowed : ArrayView[String]) -> Bool {
  values.all(value => allowed.contains(value))
}

///|
fn report_references(record : CoverageRecord) -> Array[String] {
  let paths = record.reports.unwrap_or([]).copy()
  if record.report is Some(path) {
    paths.push(path)
  }
  sorted_unique(paths.map(path => @path.Path(path).normalize().to_string()))
}

///|
fn validate_declaration_shape(declaration : ChangeDeclaration) -> Array[String] {
  let failures : Array[String] = []
  if declaration.schema != 1 {
    failures.push("declaration: expected schema 1")
  }
  if declaration.affected_commands.is_empty() ||
    declaration.affected_behaviors.is_empty() {
    failures.push(
      "declaration: affected_commands and affected_behaviors are required",
    )
  }
  if declaration.affected_options is None ||
    declaration.affected_operands is None ||
    declaration.case_ids is None ||
    declaration.published_manifest_affected is None {
    failures.push(
      "declaration: explicitly record affected_options, affected_operands, case_ids, and published_manifest_affected even when empty or false",
    )
  }
  if !valid_set(declaration.required_backends, ["native", "wasm"]) {
    failures.push("declaration: unsupported required backend")
  }
  if !valid_set(declaration.required_evidence, [
      "contract", "backend-pair", "upstream-differential", "published-differential",
      "boundary",
    ]) {
    failures.push("declaration: unsupported required evidence")
  }
  if !valid_set(declaration.required_observations, [
      "status", "stdout", "stderr", "file-content", "file-type", "file-mode", "file-identity",
      "symlink-target", "atime", "mtime", "ctime",
    ]) {
    failures.push("declaration: unsupported required observation")
  }
  for record in declaration.coverage {
    if record.behavior_id.trim() == "" ||
      record.backends.is_empty() ||
      record.evidence.is_empty() ||
      record.observations.is_empty() {
      failures.push(
        "declaration: coverage requires a behavior, backends, evidence, and observations",
      )
    }
    if !valid_set(record.backends, ["native", "wasm"]) ||
      !valid_set(record.evidence, [
        "contract", "backend-pair", "upstream-differential", "published-differential",
        "boundary",
      ]) ||
      !valid_set(record.observations, [
        "status", "stdout", "stderr", "file-content", "file-type", "file-mode", "file-identity",
        "symlink-target", "atime", "mtime", "ctime",
      ]) {
      failures.push(
        "declaration: coverage contains an unsupported backend, evidence, or observation",
      )
    }
    if record.report == Some("") ||
      record.reports.unwrap_or([]).any(path => path.trim() == "") {
      failures.push("declaration: report references must be nonempty paths")
    }
    if !["pass", "deferred"].contains(record.result) {
      failures.push(
        "declaration: coverage '\{record.behavior_id}' must be pass or deferred",
      )
    }
    if report_references(record).is_empty() {
      failures.push(
        "declaration: coverage '\{record.behavior_id}' requires report references, including deferred boundaries",
      )
    }
  }
  for boundary in declaration.boundaries {
    if [
        boundary.behavior_id,
        boundary.support_record,
        boundary.adr,
        boundary.current_limit,
        boundary.unlock_condition,
      ].any(value => value.trim() == "") {
      failures.push(
        "declaration: boundary requires behavior_id, support_record, ADR, current_limit, and unlock_condition",
      )
    }
  }
  for behavior in declaration.uncovered.unwrap_or([]) {
    failures.push("coverage: declared uncovered behavior '\{behavior}'")
  }
  failures
}

///|
fn validate_changed_scope(
  paths : ArrayView[String],
  declaration : ChangeDeclaration,
  registry : @registry.Registry,
) -> (Array[String], Bool, Array[String]) {
  let failures : Array[String] = []
  let changed_commands : Array[String] = []
  let mut core_changed = false
  for path in paths {
    if command_from_path(path) is Some(command) {
      changed_commands.push(command)
    }
    if is_core_path(path) {
      core_changed = true
    }
    let published_input = path == "tests/release_runner/current/published.json" ||
      path == "tests/release_runner/current/published-cases.json" ||
      (
        (
          path.has_prefix("tests/release_runner/published-") ||
          path.has_prefix("tests/release_runner/historical/published-")
        ) &&
        path.has_suffix(".json")
      )
    if published_input && declaration.published_manifest_affected != Some(true) {
      failures.push(
        "scope: changed published manifest requires published_manifest_affected true",
      )
    }
    let owned = registry.entries.filter(entry => {
      entry.source
      .split("::")
      .next()
      .map(source => source == path)
      .unwrap_or(false)
    })
    if path.has_prefix("tests/") &&
      !owned.is_empty() &&
      !declaration.affected_behaviors.any(id => {
        find_entry(registry, id) is Some(entry) &&
        owned.any(owner => owner.behavior_id == entry.behavior_id)
      }) {
      failures.push(
        "scope: changed registered test source has no affected behavior '\{path}'",
      )
    }
  }
  let changed_commands = sorted_unique(changed_commands)
  let declared_commands = sorted_unique(declaration.affected_commands.copy())
  let all_commands = sorted_unique(
    registry.entries
    .filter(entry => entry.implementation == "json-case" && entry.command != "")
    .map(entry => entry.command),
  )
  for command in changed_commands {
    if !declared_commands.contains(command) {
      failures.push(
        "scope: changed command '\{command}' is missing from affected_commands",
      )
    }
  }
  if core_changed {
    match declaration.core_impact {
      Some("explicit") => ()
      Some("all") =>
        for command in all_commands {
          if !declared_commands.contains(command) {
            failures.push("scope: core impact all omits '\{command}'")
          }
        }
      _ =>
        failures.push("scope: core change requires core_impact explicit or all")
    }
  }
  for command in declared_commands {
    if !all_commands.contains(command) {
      failures.push("scope: unknown command '\{command}'")
    }
    if !declaration.affected_behaviors.any(id => {
        find_entry(registry, id) is Some(entry) && entry.command == command
      }) {
      failures.push(
        "scope: affected command has no affected behavior '\{command}'",
      )
    }
  }
  for id in declaration.affected_behaviors {
    if find_entry(registry, id) is Some(entry) &&
      entry.command != "" &&
      entry.command != "all" &&
      !declared_commands.contains(entry.command) {
      failures.push(
        "scope: behavior '\{id}' belongs to undeclared command '\{entry.command}'",
      )
    }
  }
  (changed_commands, core_changed, failures)
}

///|
fn is_deferred(
  declaration : ChangeDeclaration,
  registry : @registry.Registry,
  entry : @registry.RegistryEntry,
) -> Bool {
  entry.status == "boundary" &&
  canonical_ids(registry, declaration.deferred).contains(entry.behavior_id) &&
  declaration.boundaries.any(boundary => {
    find_entry(registry, boundary.behavior_id) is Some(boundary_entry) &&
    boundary_entry.behavior_id == entry.behavior_id
  })
}

///|
fn required_evidence(
  declaration : ChangeDeclaration,
  registry : @registry.Registry,
  entry : @registry.RegistryEntry,
) -> Array[String] {
  if is_deferred(declaration, registry, entry) {
    ["boundary"]
  } else {
    sorted_unique([..entry.required_evidence, ..declaration.required_evidence])
  }
}

///|
fn validate_coverage(
  declaration : ChangeDeclaration,
  registry : @registry.Registry,
) -> Array[String] {
  let failures : Array[String] = []
  let records : Map[String, CoverageRecord] = Map([])
  let affected = canonical_ids(registry, declaration.affected_behaviors)
  for record in declaration.coverage {
    match find_entry(registry, record.behavior_id) {
      None =>
        failures.push("coverage: unknown behavior '\{record.behavior_id}'")
      Some(entry) => {
        let id = entry.behavior_id
        if records.contains(id) {
          failures.push("coverage: duplicate canonical behavior '\{id}'")
        }
        if !affected.contains(id) {
          failures.push("coverage: evidence for unaffected behavior '\{id}'")
        }
        records[id] = record
      }
    }
  }
  for id in affected {
    match find_entry(registry, id) {
      None => failures.push("coverage: unknown affected behavior '\{id}'")
      Some(entry) => {
        if entry.status == "unsupported" {
          failures.push(
            "coverage: unsupported behavior '\{id}' needs a registered boundary/rejection before it can be deferred",
          )
        }
        match records.get(id) {
          None => failures.push("coverage: missing evidence for '\{id}'")
          Some(record) => {
            if record.result != "pass" &&
              !(record.result == "deferred" &&
              is_deferred(declaration, registry, entry)) {
              failures.push(
                "coverage: '\{id}' is not a passing result or documented boundary",
              )
            }
            for
              backend in sorted_unique(
                [..entry.required_backends, ..declaration.required_backends],
              ) {
              if !record.backends.contains(backend) {
                failures.push("coverage: '\{id}' lacks backend '\{backend}'")
              }
            }
            for evidence in required_evidence(declaration, registry, entry) {
              if !record.evidence.contains(evidence) {
                failures.push("coverage: '\{id}' lacks evidence '\{evidence}'")
              }
            }
            for
              observation in sorted_unique(
                [..entry.observations, ..declaration.required_observations],
              ) {
              if !record.observations.contains(observation) {
                failures.push(
                  "coverage: '\{id}' lacks observation '\{observation}'",
                )
              }
            }
          }
        }
      }
    }
  }
  for
    tag in [
      ..declaration.affected_options.unwrap_or([]),
      ..declaration.affected_operands.unwrap_or([]),
    ] {
    if !affected.any(id => {
        find_entry(registry, id) is Some(entry) && entry.coverage.contains(tag)
      }) {
      failures.push(
        "coverage: affected option or operand tag has no affected behavior '\{tag}'",
      )
    }
  }
  failures
}

///|
async fn validate_boundaries(
  declaration : ChangeDeclaration,
  registry : @registry.Registry,
) -> Array[String] {
  let failures : Array[String] = []
  let affected = canonical_ids(registry, declaration.affected_behaviors)
  let seen : Map[String, Bool] = Map([])
  for boundary in declaration.boundaries {
    match find_entry(registry, boundary.behavior_id) {
      None =>
        failures.push("boundary: unknown behavior '\{boundary.behavior_id}'")
      Some(entry) => {
        if seen.contains(entry.behavior_id) {
          failures.push("boundary: duplicate '\{entry.behavior_id}'")
        }
        seen[entry.behavior_id] = true
        if !affected.contains(entry.behavior_id) {
          failures.push("boundary: unaffected behavior '\{entry.behavior_id}'")
        }
        if entry.status != "boundary" ||
          !entry.required_evidence.contains("boundary") {
          failures.push(
            "boundary: '\{entry.behavior_id}' is not a registered rejection boundary",
          )
        }
        for reference in [boundary.support_record, boundary.adr] {
          let file = reference.split("#").next().unwrap().to_owned()
          if file == "" || !@fs.exists(file) {
            failures.push(
              "boundary: support document does not exist '\{reference}'",
            )
          } else if @fs.read_file(file).text().trim() == "" {
            failures.push("boundary: support document is empty '\{reference}'")
          }
        }
      }
    }
  }
  for id in canonical_ids(registry, declaration.deferred) {
    if !affected.contains(id) || !seen.contains(id) {
      failures.push(
        "boundary: deferred behavior lacks an affected boundary record '\{id}'",
      )
    }
  }
  failures
}

///|
pub extend CoverageRecord with @json.FromJson::{from_json}

///|
pub extend BoundaryRecord with @json.FromJson::{from_json}

///|
pub extend ChangeDeclaration with @json.FromJson::{from_json}

///|
pub extend AuditReport with ToJson::{to_json}
