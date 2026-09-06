///|
priv struct ReleaseCommand {
  name : String
  package_name : String
  version : String
  published : Bool
  compare_profile : String
  supported_options : Array[String]
  policy_sensitive : Bool
} derive(FromJson)

///|
priv struct FixtureFile {
  path : String
  content_hex : String
  kind : String?
  target : String?
} derive(FromJson)

///|
priv struct Normalization {
  field : String
  rule : String
  comment : String
} derive(FromJson)

///|
priv struct ReleaseCase {
  id : String
  command : String
  args : Array[String]
  stdin_hex : String
  files : Array[FixtureFile]
  environment : Map[String, String]
  expected_status : Int
  timeout_ms : Int?
  normalizations : Array[Normalization]
  comparison : String?
  expected_stdout_contains : String?
  expected_stdout_ends_with_newline : Bool?
  expected_stderr_ends_with_newline : Bool?
  forbidden_stderr : Array[String]?
  coverage : Array[String]?
} derive(FromJson)

///|
priv struct ReleaseManifest {
  schema : Int
  base_manifest : String
  commands : Array[ReleaseCommand]
  case_ids : Array[String]
  extra_cases : Array[ReleaseCase]
} derive(FromJson)

///|
priv struct BaseManifest {
  schema : Int
  cases : Array[ReleaseCase]
} derive(FromJson)

///|
fn valid_version(version : String) -> Bool {
  let pieces : Array[String] = version
    .split(".")
    .map(v => v.to_owned())
    .collect()
  if pieces.length() != 3 {
    return false
  }
  for piece in pieces {
    if piece == "" {
      return false
    }
    for char in piece {
      if !(char is ('0'..='9')) {
        return false
      }
    }
  }
  true
}

///|
fn safe_relative_path(value : String) -> Bool {
  if value == "" || @path.Path(value).is_absolute() {
    return false
  }
  let normalized = value.replace_all(old="\\", new="/")
  if normalized.length() >= 2 && normalized[1] == ':' {
    return false
  }
  for component in normalized.split("/") {
    if component == "" || component == "." || component == ".." {
      return false
    }
  }
  true
}

///|
fn safe_symlink_target(value : String) -> Bool {
  if value == "" || @path.Path(value).is_absolute() {
    return false
  }
  let normalized = value.replace_all(old="\\", new="/")
  if normalized.length() >= 2 && normalized[1] == ':' {
    return false
  }
  for component in normalized.split("/") {
    if component == ".." {
      return false
    }
  }
  true
}

///|
fn validate_release_manifest(
  manifest : ReleaseManifest,
  base : BaseManifest,
) -> Array[String] {
  let failures : Array[String] = []
  if manifest.schema != 1 {
    failures.push("release manifest: expected schema 1")
  }
  if base.schema != 1 {
    failures.push("base manifest: expected schema 1")
  }
  if !safe_relative_path(manifest.base_manifest) {
    failures.push(
      "release manifest: base_manifest must be a safe relative path",
    )
  }
  let expected : Map[String, Bool] = Map([])
  for contract in @cli.command_catalog() {
    if @cli.releasable(contract) {
      expected[contract.name] = true
    }
  }
  let seen : Map[String, Bool] = Map([])
  for row in manifest.commands {
    if seen.contains(row.name) {
      failures.push("release manifest: duplicate command '\{row.name}'")
    }
    seen[row.name] = true
    if !expected.contains(row.name) {
      failures.push("release manifest: command is not published '\{row.name}'")
    }
    if row.package_name != "cli/" + row.name {
      failures.push("\{row.name}: package must be cli/\{row.name}")
    }
    if !row.published {
      failures.push("\{row.name}: published rows must set published=true")
    }
    if !valid_version(row.version) {
      failures.push("\{row.name}: invalid version '\{row.version}'")
    }
    if row.compare_profile == "" {
      failures.push("\{row.name}: compare_profile is required")
    }
    match @cli.find_contract(row.name) {
      Some(contract) =>
        for option in row.supported_options {
          if !contract.options.contains(option) {
            failures.push(
              "\{row.name}: supported option '\{option}' is not in the command catalog",
            )
          }
        }
      None => ()
    }
  }
  for name, _ in expected {
    if !seen.contains(name) {
      failures.push("release manifest: missing published command '\{name}'")
    }
  }
  let case_ids : Map[String, Bool] = Map([])
  for fixture in base.cases + manifest.extra_cases {
    if fixture.id == "" || case_ids.contains(fixture.id) {
      failures.push("release manifest: duplicate/empty case id '\{fixture.id}'")
    }
    if !safe_relative_path(fixture.id) {
      failures.push(
        "\{fixture.id}: case id must be a safe single path component",
      )
    }
    case_ids[fixture.id] = true
    if !seen.contains(fixture.command) {
      failures.push("\{fixture.id}: command is not in release manifest")
    }
    for file in fixture.files {
      if !safe_relative_path(file.path) {
        failures.push("\{fixture.id}: unsafe fixture path '\{file.path}'")
      }
      match file.kind {
        Some("symlink") =>
          match file.target {
            None => failures.push("\{fixture.id}: symlink target is required")
            Some(target) if !safe_symlink_target(target) =>
              failures.push("\{fixture.id}: unsafe symlink target")
            Some(_) => ()
          }
        Some("file") | None => ()
        Some(_) => failures.push("\{fixture.id}: unsupported fixture kind")
      }
    }
    for normalization in fixture.normalizations {
      if !["stdout", "stderr"].contains(normalization.field) {
        failures.push("\{fixture.id}: unsupported normalization field")
      }
      if !["temporary-path", "path-separator", "working-directory"].contains(
          normalization.rule,
        ) {
        failures.push("\{fixture.id}: unsupported normalization rule")
      }
      if normalization.comment == "" {
        failures.push("\{fixture.id}: normalization comment is required")
      }
    }
    match fixture.comparison {
      None | Some("exact") | Some("normalized") | Some("contract") => ()
      Some(other) =>
        failures.push("\{fixture.id}: unsupported comparison mode '\{other}'")
    }
    if !fixture.normalizations.is_empty() &&
      fixture.comparison != Some("normalized") {
      failures.push(
        "\{fixture.id}: normalizations require comparison=normalized",
      )
    }
    match fixture.timeout_ms {
      Some(value) if value <= 0 =>
        failures.push("\{fixture.id}: timeout_ms must be positive")
      _ => ()
    }
  }
  let selected_ids : Map[String, Bool] = Map([])
  for id in manifest.case_ids {
    if selected_ids.contains(id) {
      failures.push("release manifest: duplicate selected case id '\{id}'")
    }
    selected_ids[id] = true
    if !case_ids.contains(id) {
      failures.push("release manifest: unknown case id '\{id}'")
    }
  }
  for row in manifest.commands {
    for option in row.supported_options {
      let mut covered = false
      for fixture in base.cases + manifest.extra_cases {
        if fixture.command == row.name {
          match fixture.coverage {
            Some(items) if items.contains(option) => covered = true
            _ => ()
          }
        }
      }
      if !covered {
        failures.push(
          "\{row.name}: supported option '\{option}' has no coverage case",
        )
      }
    }
  }
  failures
}

///|
async fn read_package_version(root : String, command : String) -> String? {
  let path = @path.Path(root)
    .join(Path("commands"))
    .join(Path(command))
    .join(Path("moon.mod"))
    .to_string()
  let text = @fs.read_file(path).text() catch { _ => return None }
  for line in text.split("\n") {
    let trimmed = line.trim()
    if trimmed.has_prefix("version") {
      let pieces : Array[String] = trimmed
        .split("\"")
        .map(v => v.to_owned())
        .collect()
      if pieces.length() >= 2 {
        return Some(pieces[1])
      }
    }
  }
  None
}

///|
async fn validate_package_versions(
  root : String,
  manifest : ReleaseManifest,
) -> Array[String] {
  let failures : Array[String] = []
  for row in manifest.commands {
    match read_package_version(root, row.name) {
      Some(version) if version == row.version => ()
      Some(version) =>
        failures.push(
          "\{row.name}: moon.mod version \{version} differs from release version \{row.version}",
        )
      None => failures.push("\{row.name}: cannot read moon.mod version")
    }
    match @cli.find_contract(row.name) {
      Some(contract) if contract.options.contains("version") =>
        match read_command_version(root, row.name) {
          Some(version) if version == row.version => ()
          Some(version) =>
            failures.push(
              "\{row.name}: command version \{version} differs from release version \{row.version}",
            )
          None => failures.push("\{row.name}: version.mbt is required")
        }
      _ => ()
    }
  }
  failures
}

///|
async fn read_command_version(root : String, command : String) -> String? {
  let path = @path.Path(root)
    .join(Path("commands"))
    .join(Path(command))
    .join(Path("version.mbt"))
    .to_string()
  let text = @fs.read_file(path).text() catch { _ => return None }
  for line in text.split("\n") {
    let trimmed = line.trim()
    if trimmed.has_prefix("let command_version") {
      let pieces : Array[String] = trimmed
        .split("\"")
        .map(v => v.to_owned())
        .collect()
      if pieces.length() >= 2 {
        return Some(pieces[1])
      }
    }
  }
  None
}
