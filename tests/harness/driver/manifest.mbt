///|
struct CommandRow {
  name : String
} derive(FromJson, Debug)

///|
struct Manifest {
  schema : Int32
  commands : Array[CommandRow]
  cases : Array[OracleCase]
} derive(FromJson, Debug)

///|
fn validate_manifest(manifest : Manifest) -> Array[String] {
  let failures : Array[String] = []
  if manifest.schema != 2 {
    failures.push("manifest: expected schema 2, got \{manifest.schema}")
  }
  if manifest.cases.is_empty() {
    failures.push("manifest: required case corpus is empty")
  }
  let catalog = @contracts.command_catalog()
  if manifest.commands.length() != catalog.length() {
    failures.push(
      "manifest: expected \{catalog.length()} command rows, got \{manifest.commands.length()}",
    )
  }
  let rows : Map[String, Bool] = Map([])
  for row in manifest.commands {
    if rows.contains(row.name) {
      failures.push("manifest: duplicate command row '\{row.name}'")
    }
    rows[row.name] = true
  }
  for contract in catalog {
    if !rows.contains(contract.name) {
      failures.push("manifest: missing command row '\{contract.name}'")
    }
  }
  let case_ids : Map[String, Bool] = Map([])
  for fixture in manifest.cases {
    if fixture.expected_rejection == Some("") {
      failures.push("\{fixture.id}: rejection reason must be nonempty")
    }
    if fixture.id == "" || case_ids.contains(fixture.id) {
      failures.push(
        "manifest: case IDs must be nonempty and unique: '\{fixture.id}'",
      )
    }
    case_ids[fixture.id] = true
    if !safe_relative_path(fixture.id) {
      failures.push("unsafe case ID: " + fixture.id)
    }
    failures.append(@harness.contract_errors(fixture))
    for dimension in fixture.observe.unwrap_or([]) {
      if ![
          "content", "type", "mode", "identity", "symlink-target", "atime", "mtime",
          "ctime",
        ].contains(dimension) {
        failures.push("unknown observation: " + dimension)
      }
      if ["atime", "ctime"].contains(dimension) &&
        fixture.expected_rejection is None &&
        fixture.comparison != Some("contract") {
        failures.push(
          "time observations require a same-fixture boundary or scenario",
        )
      }
      if dimension == "mtime" &&
        fixture.expected_rejection is None &&
        fixture.comparison != Some("contract") &&
        fixture.files.any(file => file.mtime is None) {
        failures.push(
          "differential mtime requires fixed timestamps on every input",
        )
      }
    }
    if !rows.contains(fixture.command) {
      failures.push("\{fixture.id}: unknown command '\{fixture.command}'")
    }
    ignore(fixture.input()) catch {
      err => failures.push("\{err}")
    }
    for file in fixture.files {
      if !safe_relative_path(file.path) {
        failures.push("\{fixture.id}: unsafe fixture path '\{file.path}'")
      }
      ignore(
        @harness.input_bytes(
          file.content_hex,
          file.content_text,
          fixture.id + " file " + file.path,
        ),
      ) catch {
        err => failures.push("\{err}")
      }
      match file.kind {
        Some("file") | Some("directory") | None =>
          if file.target is Some(_) {
            failures.push(
              "\{fixture.id}: regular fixture cannot have a symlink target",
            )
          }
        Some("symlink" | "symbolic-link" | "junction" | "hardlink") => {
          guard file.target is Some(target) && target != "" else {
            failures.push("\{fixture.id}: symlink fixture needs a target")
            continue
          }
          if @path.Path(target).is_absolute() {
            failures.push("\{fixture.id}: symlink target must be relative")
          }
        }
        Some(kind) =>
          failures.push("\{fixture.id}: unsupported fixture kind '\{kind}'")
      }
    }
    if fixture.delay_ms is Some(delay) && (delay < 0 || delay > 10000) {
      failures.push("\{fixture.id}: delay_ms must be between 0 and 10000")
    }
    for normalization in fixture.normalizations {
      if normalization.comment == "" {
        failures.push("\{fixture.id}: every normalization needs a comment")
      }
      if !["stdout", "stderr"].contains(normalization.field) {
        failures.push(
          "\{fixture.id}: unsupported normalization field '\{normalization.field}'",
        )
      }
      if !["temporary-path", "path-separator", "working-directory"].contains(
          normalization.rule,
        ) {
        failures.push(
          "\{fixture.id}: unsupported normalization rule '\{normalization.rule}'",
        )
      }
    }
  }
  failures
}
