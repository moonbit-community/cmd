///|
type ReleaseCase = @testkit.Case

///|
using @testkit {safe_relative_path, safe_symlink_target}

///|
priv struct ReleaseCommand {
  name : String
  package_name : String
  version : String
  published : Bool
  compare_profile : String
  supported_options : Array[String]
  policy_sensitive : Bool
} derive(FromJson, ToJson)

///|
/// Explicit release metadata is deliberately separate from package versions.
/// Versions come from each command's moon.mod; these fields are reviewed test
/// policy and must never be inferred from the case corpus.
priv struct ReleaseMetadataCommand {
  name : String
  package_name : String
  compare_profile : String
  supported_options : Array[String]
  policy_sensitive : Bool
  releasable : Bool
  case_ids : Array[String]?
} derive(FromJson, ToJson)

///|
priv struct ReleaseMetadata {
  schema : Int32
  commands : Array[ReleaseMetadataCommand]
} derive(FromJson)

///|
/// The active case index is a compatibility artifact for the testkit.  Its
/// authoritative input is the unified registry; keeping this type here makes
/// generation deterministic without making the case corpus a second source
/// of test ownership.
priv struct ActiveCasesIndex {
  schema : Int32
  cases : Array[ReleaseCase]
  case_files : Array[String]
  case_overrides : Array[String]
} derive(ToJson)

///|
priv struct ReleaseManifest {
  schema : Int32
  candidate : Bool?
  release_scope : Array[String]?
  core_version : String?
  base_manifest : String
  commands : Array[ReleaseCommand]
  case_ids : Array[String]
  extra_cases : Array[ReleaseCase]
} derive(FromJson, ToJson)

///|
priv struct BaseManifest {
  schema : Int32
  cases : Array[ReleaseCase]
}

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
    if piece == "" || (piece.length() > 1 && piece.has_prefix("0")) {
      return false
    }
    for char in piece {
      if !(char is ('0'..<='9')) {
        return false
      }
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
  failures.append(release_scope_errors(manifest))
  if manifest.schema != 1 && manifest.schema != 2 {
    failures.push("release manifest: expected schema 1 or 2")
  }
  if base.schema != 1 && base.schema != 2 {
    failures.push("base manifest: expected schema 1 or 2")
  }
  if !safe_relative_path(manifest.base_manifest) {
    failures.push(
      "release manifest: base_manifest must be a safe relative path",
    )
  }
  if manifest.core_version is Some(version) && !valid_version(version) {
    failures.push("release manifest: invalid core version '\{version}'")
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
    if !row.published && manifest.candidate != Some(true) {
      failures.push("\{row.name}: published rows must set published=true")
    }
    if row.published && manifest.candidate == Some(true) {
      failures.push(
        "\{row.name}: unpublished candidate rows must set published=false",
      )
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
  // Candidate completeness is checked against registry release_commands by
  // validate_candidate_bindings. The catalog is only an upper support bound.
  if manifest.commands.is_empty() {
    failures.push("release manifest: no command coordinates")
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
    for old_id in fixture.aliases.unwrap_or([]) {
      case_ids[old_id] = true
    }
    if !seen.contains(fixture.command) &&
      selected_cases(manifest, base).any(item => item.id == fixture.id) {
      failures.push("\{fixture.id}: command is not in release manifest")
    }
    ignore(fixture.input()) catch {
      err => failures.push("\{err}")
    }
    for file in fixture.files {
      if !safe_relative_path(file.path) {
        failures.push("\{fixture.id}: unsafe fixture path '\{file.path}'")
      }
      ignore(
        @testkit.input_bytes(
          file.content_hex,
          file.content_text,
          fixture.id + ":" + file.path,
        ),
      ) catch {
        err => failures.push("\{err}")
      }
      match file.kind {
        Some("symlink" | "symbolic-link" | "junction") =>
          match file.target {
            None => failures.push("\{fixture.id}: symlink target is required")
            Some(target) if !safe_symlink_target(target) =>
              failures.push("\{fixture.id}: unsafe symlink target")
            Some(_) => ()
          }
        Some("hardlink") =>
          match file.target {
            Some(target) if safe_relative_path(target) => ()
            _ =>
              failures.push(
                "\{fixture.id}: hardlink target must be a safe relative path",
              )
          }
        Some("file") | Some("directory") | None => ()
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
      None
      | Some("exact")
      | Some("normalized")
      | Some("contract")
      | Some("boundary")
      | Some("scenario")
      | Some("oracle-scenario") => ()
      Some(other) =>
        failures.push("\{fixture.id}: unsupported comparison mode '\{other}'")
    }
    if !fixture.normalizations.is_empty() &&
      fixture.comparison != Some("normalized") &&
      fixture.comparison != Some("contract") {
      failures.push(
        "\{fixture.id}: normalizations require comparison=normalized or contract",
      )
    }
    if fixture.expected_rejection is Some(reason) && reason.is_empty() {
      failures.push("\{fixture.id}: expected_rejection needs a reason")
    }
    if fixture.comparison == Some("boundary") &&
      fixture.expected_rejection is None {
      failures.push(
        "\{fixture.id}: boundary comparison requires expected_rejection",
      )
    }
    if (
        fixture.comparison == Some("scenario") ||
        fixture.comparison == Some("oracle-scenario")
      ) &&
      selected_cases(manifest, base).any(selected => selected.id == fixture.id) {
      if !release_network_scenario(fixture) &&
        !release_mv_scenario(fixture) &&
        !release_mktemp_scenario(fixture) &&
        !release_tee_scenario(fixture) &&
        !release_diff_device_scenario(fixture) {
        failures.push(
          "\{fixture.id}: stateful scenario has no exact published executor",
        )
      } else if release_case_included(manifest, fixture) {
        for
          command in [fixture.command, ..fixture.related_commands.unwrap_or([])] {
          if find_command(manifest, command) is None ||
            !release_includes(manifest, command) {
            failures.push(
              "\{fixture.id}: release_scope must include related command " +
              command,
            )
          }
        }
      }
    }
    for dimension in fixture.observe.unwrap_or([]) {
      if ![
          "content", "type", "mode", "identity", "symlink-target", "atime", "mtime",
          "ctime",
        ].contains(dimension) {
        failures.push("\{fixture.id}: unknown observation '\{dimension}'")
      }
      if ["atime", "ctime"].contains(dimension) &&
        fixture.expected_rejection is None {
        failures.push(
          "\{fixture.id}: time relations require a stateful scenario, not cross-root equality",
        )
      }
      if dimension == "mtime" &&
        fixture.expected_rejection is None &&
        fixture.files.any(file => file.mtime is None) {
        failures.push(
          "\{fixture.id}: differential mtime requires fixed timestamps on every input",
        )
      }
    }
    if manifest.schema == 2 &&
      fixture.comparison == Some("contract") &&
      !has_contract_assertion(fixture) {
      failures.push(
        "\{fixture.id}: contract needs an explicit output assertion",
      )
    }
    if manifest.schema == 2 &&
      (
        fixture.expected_stdout_contains is Some(_) ||
        fixture.expected_stderr_contains is Some(_)
      ) &&
      (
        fixture.diagnostic_reason is None ||
        fixture.diagnostic_reason == Some("")
      ) {
      failures.push(
        "\{fixture.id}: partial output assertion requires diagnostic_reason",
      )
    }
    match fixture.timeout_ms {
      Some(value) if value <= 0 =>
        failures.push("\{fixture.id}: timeout_ms must be positive")
      _ => ()
    }
    if fixture.delay_ms is Some(value) && (value < 0 || value > 10000) {
      failures.push("\{fixture.id}: delay_ms must be between 0 and 10000")
    }
    for
      (hex, text, stream) in [
        (fixture.expected_stdout_hex, fixture.expected_stdout_text, "stdout"),
        (fixture.expected_stderr_hex, fixture.expected_stderr_text, "stderr"),
      ] {
      ignore(@testkit.input_bytes(hex, text, fixture.id + " " + stream)) catch {
        err => failures.push("\{err}")
      }
    }
    match fixture.host_platforms {
      Some(platforms) if platforms.is_empty() =>
        failures.push("\{fixture.id}: host_platforms must not be empty")
      Some(platforms) =>
        for platform in platforms {
          if !["posix", "windows", "linux", "macos"].contains(platform) {
            failures.push(
              "\{fixture.id}: unsupported host platform '\{platform}'",
            )
          }
        }
      None => ()
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
      for fixture in selected_cases(manifest, base) {
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
async fn read_module_field(
  root : String,
  module_directory : String,
  field : String,
) -> String? {
  let path = @path.Path(root)
    .join(Path(module_directory))
    .join(Path("moon.mod"))
    .to_string()
  let text = @fs.read_file(path).text() catch { _ => return None }
  let mut value : String? = None
  for line in text.split("\n") {
    let assignment : Array[String] = line
      .split("=")
      .map(item => item.trim().to_owned())
      .collect()
    if assignment.length() == 2 && assignment[0] == field {
      if value is Some(_) {
        return None
      }
      let pieces : Array[String] = assignment[1]
        .split("\"")
        .map(v => v.to_owned())
        .collect()
      if pieces.length() != 3 || pieces[0] != "" || pieces[2] != "" {
        return None
      }
      value = Some(pieces[1])
    }
  }
  value
}

///|
async fn read_package_version(root : String, command : String) -> String? {
  read_module_field(root, "commands/" + command, "version")
}

///|
/// Candidate coordinates and semantic case bodies must derive from the same
/// reviewed registry. Structural manifest validity alone cannot certify them.
async fn validate_candidate_bindings(
  root : String,
  manifest : ReleaseManifest,
  base : BaseManifest,
  registry_path : String,
) -> Array[String] {
  let registry = @registry.load(registry_path)
  let failures = @registry.validate(registry)
  failures.append(@registry.validate_source_bindings(registry, root~))
  let selected = selected_cases(manifest, base)
  failures.append(@registry.validate_selected_cases(registry, selected, root~))
  let wanted_cases : Set[String] = Set([])
  for reviewed in registry.release_commands {
    let actual = find_command(manifest, reviewed.name)
    if !reviewed.releasable {
      if actual is Some(_) {
        failures.push(reviewed.name + ": registry marks command unreleasable")
      }
      continue
    }
    match actual {
      None =>
        failures.push("registry release command missing: " + reviewed.name)
      Some(row) =>
        if row.package_name != reviewed.package_name ||
          row.compare_profile != reviewed.compare_profile ||
          row.supported_options != reviewed.supported_options ||
          row.policy_sensitive != reviewed.policy_sensitive {
          failures.push(
            reviewed.name + ": release metadata differs from registry",
          )
        }
    }
    for id in reviewed.case_ids.unwrap_or([]) {
      wanted_cases.add(id)
    }
  }
  for row in manifest.commands {
    if !registry.release_commands.any(reviewed => {
        reviewed.releasable && reviewed.name == row.name
      }) {
      failures.push(row.name + ": no releasable registry profile")
    }
  }
  for fixture in selected {
    if !wanted_cases.contains(fixture.id) &&
      !fixture.aliases
      .unwrap_or([])
      .any(old_id => wanted_cases.contains(old_id)) {
      failures.push(fixture.id + ": not selected by registry release profile")
    }
  }
  for id in wanted_cases {
    if !selected.any(fixture => {
        fixture.id == id || fixture.aliases.unwrap_or([]).contains(id)
      }) {
      failures.push(id + ": registry release selection is missing")
    }
  }
  failures
}

///|
/// Read the reviewed release metadata sidecar (or a registry export with the
/// same `commands` field).  Package versions are intentionally absent from
/// this document: they are read from the command module below.
async fn read_release_metadata(path : String) -> ReleaseMetadata raise Failure {
  let source = @json.parse(@fs.read_file(path).text()) catch {
    _ => fail("cannot parse release metadata: \{path}")
  }
  // A registry may expose the release section under `release_commands`; keep
  // the generator compatible with both the standalone sidecar and that
  // export without making either source authoritative for package versions.
  match source {
    { "commands": _, .. } =>
      @json.from_json(source) catch {
        _ => fail("invalid release metadata: \{path}")
      }
    { "release_commands": commands, "schema": schema, .. } =>
      @json.from_json({ "schema": schema, "commands": commands }) catch {
        _ => fail("invalid release metadata: \{path}")
      }
    _ => fail("release metadata must contain commands: \{path}")
  }
}

///|
/// Convert the registry's `tests/registry/registry.json` case references to
/// paths relative to `tests/release_runner/current/active-cases.json`.
/// Both workspace-relative `tests/cases/foo.json` references and the migration
/// adapter's `../cases/foo.json` references resolve from fixed directories.
fn current_case_path(source : String) -> String raise Failure {
  let pieces : Array[String] = source
    .split("/")
    .map(item => item.to_owned())
    .collect()
  guard pieces.length() == 3 &&
    (
      (pieces[0] == ".." && pieces[1] == "cases") ||
      (pieces[0] == "tests" && pieces[1] == "cases")
    ) &&
    pieces[2].has_suffix(".json") else {
    fail("registry JSON case source must be tests/cases/*.json: \{source}")
  }
  "../../cases/" + pieces[2]
}

///|
/// Generate the compatibility case index from the unified registry.  Only
/// JSON case entries contribute files; scenarios, cohorts, package tests and
/// metadata probes remain registry-owned but are selected by their own
/// runners.  Duplicate source paths collapse to one stable entry.
async fn write_active_cases_index(
  registry_path : String,
  output_path : String,
  root~ : String = "",
) -> Unit raise Failure {
  let registry = @registry.load(registry_path)
  let failures = @registry.validate(registry)
  guard failures.is_empty() else {
    fail("registry validation failed: " + failures.join("; "))
  }
  let parent = @path.Path(output_path).dirname().to_string()
  if !(@fs.exists(parent) catch { _ => false }) {
    @fs.mkdir(parent, recursive=true) catch {
      error => fail("cannot create active case index directory: \{error}")
    }
  }
  let registry_realpath = @fs.realpath(registry_path) catch {
    _ => fail("cannot resolve registry path")
  }
  let source_root = if root == "" {
    @path.Path(registry_realpath)
    .dirname()
    .join(Path("../.."))
    .normalize()
    .to_string()
  } else {
    root
  }
  let source_errors = @registry.validate_source_bindings(
    registry,
    root=source_root,
  ) catch {
    error =>
      fail("release registry source validation failed: " + error.to_string())
  }
  guard source_errors.is_empty() else {
    fail(
      "release registry source validation failed: " + source_errors.join("; "),
    )
  }
  let parent_realpath = @fs.realpath(parent) catch {
    _ => fail("cannot resolve active case directory")
  }
  let registry_directory = @path.Path(registry_realpath).dirname()
  let output_directory = @path.Path(parent_realpath)
  let seen : Map[String, Bool] = Map([])
  for entry in registry.entries {
    if entry.implementation == "json-case" {
      ignore(current_case_path(entry.source))
      let source_directory = if entry.source.has_prefix("tests/") {
        @path.Path(source_root)
      } else {
        registry_directory
      }
      let path = source_directory
        .join(Path(entry.source))
        .normalize()
        .relative(base=output_directory)
        .to_string()
      seen[path] = true
    }
  }
  let files : Array[String] = []
  for path, _ in seen {
    files.push(path)
  }
  files.sort_by((left, right) => left.lexical_compare(right))
  guard !files.is_empty() else { fail("registry: no JSON case sources") }
  let index : ActiveCasesIndex = {
    schema: 2,
    cases: [],
    case_files: files,
    case_overrides: [],
  }
  @fs.write_file(output_path, ToJson::to_json(index).stringify(indent=2) + "\n") catch {
    error => fail("cannot write active case index: \{error}")
  }
}

///|
/// Build the current candidate from reviewed release metadata and the exact
/// versions declared by commands/*/moon.mod. The template establishes an
/// unpublished candidate; selection and release profiles come from registry.
async fn generate_candidate_manifest(
  root : String,
  template_path : String,
  metadata_path : String,
  registry_path~ : String = root + "/tests/registry/registry.json",
) -> ReleaseManifest raise Failure {
  let template = read_release_manifest(template_path)
  let metadata = read_release_metadata(metadata_path)
  if metadata.schema != 1 && metadata.schema != 2 {
    fail("release metadata: expected schema 1 or 2")
  }
  let core_name = read_module_field(root, "core", "name") catch { _ => None }
  guard core_name == Some("cli/core") else {
    fail("core: moon.mod module must be cli/core")
  }
  let core_version = read_module_field(root, "core", "version") catch {
    _ => None
  }
  guard core_version is Some(core_version) && valid_version(core_version) else {
    fail("core: missing or invalid moon.mod version")
  }
  let metadata_by_name : Map[String, ReleaseMetadataCommand] = Map([])
  let metadata_case_ids : Array[String] = []
  let registry = @registry.load(registry_path)
  let authoritative_metadata = read_release_metadata(registry_path)
  guard @testkit.canonical_json(ToJson::to_json(metadata.commands)) ==
    @testkit.canonical_json(ToJson::to_json(authoritative_metadata.commands)) else {
    fail("release metadata override differs from authoritative registry")
  }
  let registry_errors = @registry.validate(registry)
  guard registry_errors.is_empty() else {
    fail("release registry invalid: " + registry_errors.join("; "))
  }
  let source_errors = @registry.validate_source_bindings(registry, root~) catch {
    error =>
      fail("release registry source validation failed: " + error.to_string())
  }
  guard source_errors.is_empty() else {
    fail(
      "release registry source validation failed: " + source_errors.join("; "),
    )
  }
  for row in metadata.commands {
    if metadata_by_name.contains(row.name) {
      fail("release metadata: duplicate command '\{row.name}'")
    }
    metadata_by_name[row.name] = row
    guard @cli.find_contract(row.name) is Some(_) else {
      fail("release metadata: unknown command '\{row.name}'")
    }
    match row.case_ids {
      Some(ids) =>
        for id in ids {
          guard row.releasable else {
            fail(
              "\{row.name}: unreleasable command cannot select release cases",
            )
          }
          guard registry.entries.any(entry => {
            entry.is_case() &&
            entry.command == row.name &&
            (entry.case_id == id || entry.aliases.contains(id))
          }) else {
            fail("\{row.name}: release case has no registry binding: \{id}")
          }
          if metadata_case_ids.contains(id) {
            fail("release metadata: duplicate selected case '\{id}'")
          }
          metadata_case_ids.push(id)
        }
      None => ()
    }
    if row.package_name != "cli/" + row.name {
      fail("\{row.name}: package must be cli/\{row.name}")
    }
    if row.releasable {
      match @cli.find_contract(row.name) {
        Some(contract) if @cli.releasable(contract) => ()
        Some(_) =>
          fail("\{row.name}: metadata marks unreleasable command as releasable")
        None => fail("release metadata: unknown command '\{row.name}'")
      }
    }
  }
  let names : Array[String] = []
  for contract in @cli.command_catalog() {
    if @cli.releasable(contract) {
      guard metadata_by_name.contains(contract.name) else {
        fail("release metadata: missing releasable command '\{contract.name}'")
      }
      let row = metadata_by_name[contract.name]
      if !row.releasable {
        continue
      }
      guard ["gnu", "findutils", "jq", "jqlog", "make", "posix", "vim"].contains(
        row.compare_profile,
      ) else {
        fail("\{contract.name}: missing or unknown compare_profile")
      }
      names.push(contract.name)
    }
  }
  metadata_case_ids.sort_by((left, right) => left.lexical_compare(right))
  for name in names {
    if metadata_by_name[name].case_ids is None {
      fail("\{name}: case_ids are required in release metadata")
    }
  }
  names.sort_by((left, right) => left.lexical_compare(right))
  let command_directories = @fs.readdir(root + "/commands", sort=true) catch {
    _ => fail("cannot inspect command module directories")
  }
  for directory in command_directories {
    if (@fs.exists(root + "/commands/" + directory + "/moon.mod") catch {
        _ => false
      }) {
      guard metadata_by_name.contains(directory) else {
        fail("module has no explicit release metadata: " + directory)
      }
    }
  }
  guard template.extra_cases.is_empty() else {
    fail(
      "candidate cases must be registered; inline template extra_cases are unsupported",
    )
  }
  guard template.candidate == Some(true) else {
    fail("historical or published manifests cannot seed current candidates")
  }
  let commands : Array[ReleaseCommand] = []
  for name in names {
    let metadata_row = metadata_by_name[name]
    let module_name = read_module_field(root, "commands/" + name, "name") catch {
      _ => None
    }
    guard module_name == Some("cli/" + name) else {
      fail("\{name}: moon.mod module must be cli/\{name}")
    }
    let version = read_package_version(root, name) catch { _ => None }
    guard version is Some(version) else {
      fail("\{name}: cannot read moon.mod version")
    }
    guard valid_version(version) else {
      fail("\{name}: invalid moon.mod version '\{version}'")
    }
    commands.push({
      name,
      package_name: metadata_row.package_name,
      version,
      published: false,
      compare_profile: metadata_row.compare_profile,
      supported_options: metadata_row.supported_options.copy(),
      policy_sensitive: metadata_row.policy_sensitive,
    })
  }
  guard !commands.is_empty() else {
    fail("release metadata: no releasable commands")
  }
  {
    schema: 2,
    candidate: Some(true),
    release_scope: template.release_scope,
    core_version: Some(core_version),
    base_manifest: "active-cases.json",
    commands,
    case_ids: metadata_case_ids,
    extra_cases: template.extra_cases,
  }
}

///|
/// Write a generated candidate as canonical JSON with a trailing newline.
async fn write_candidate_manifest(
  root : String,
  template_path : String,
  metadata_path : String,
  output_path : String,
  registry_path~ : String = root + "/tests/registry/registry.json",
  active_path? : String,
) -> Unit raise Failure {
  let candidate = generate_candidate_manifest(
    root,
    template_path,
    metadata_path,
    registry_path~,
  )
  let parent = @path.Path(output_path).dirname().to_string()
  if !(@fs.exists(parent) catch { _ => false }) {
    @fs.mkdir(parent, recursive=true) catch {
      _ => fail("cannot create candidate directory")
    }
  }
  let output_directory = @path.Path(
    @fs.realpath(parent) catch {
      _ => fail("cannot resolve candidate directory")
    },
  )
  let base_path = active_path.unwrap_or(
    output_directory.join(Path("active-cases.json")).to_string(),
  )
  let base_absolute = @path.Path(
    @fs.realpath(base_path) catch {
      _ => fail("cannot resolve generated case index")
    },
  )
  let base_reference = base_absolute.relative(base=output_directory).to_string()
  guard safe_relative_path(base_reference) else {
    fail("generated active index must be inside candidate output directory")
  }
  let candidate = { ..candidate, base_manifest: base_reference, }
  let base = read_base_manifest(base_path) catch {
    _ => fail("cannot read candidate base manifest")
  }
  let validation = validate_release_manifest(candidate, base) +
    (validate_package_versions(root, candidate) catch {
      _ => ["cannot validate package versions"]
    }) +
    (validate_candidate_bindings(root, candidate, base, registry_path) catch {
      error => [error.to_string()]
    })
  guard validation.is_empty() else {
    fail("generated candidate validation failed: " + validation.join("; "))
  }
  @fs.write_file(
    output_path,
    ToJson::to_json(candidate).stringify(indent=2) + "\n",
  ) catch {
    error => fail("cannot write candidate manifest: \{error}")
  }
}

///|
async fn validate_package_versions(
  root : String,
  manifest : ReleaseManifest,
) -> Array[String] {
  let failures : Array[String] = []
  if manifest.candidate == Some(true) {
    if read_module_field(root, "core", "name") != Some("cli/core") {
      failures.push("core: moon.mod module must be cli/core")
    }
    match (manifest.core_version, read_module_field(root, "core", "version")) {
      (Some(expected), Some(actual)) if expected == actual &&
        valid_version(actual) => ()
      _ =>
        failures.push(
          "core: candidate version differs from core/moon.mod or is missing",
        )
    }
  }
  for row in manifest.commands {
    if read_module_field(root, "commands/" + row.name, "name") !=
      Some(row.package_name) {
      failures.push(row.name + ": moon.mod module differs from release package")
    }
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
          // Older command modules keep the version literal in main.mbt. The
          // metadata contract test validates their emitted bytes; only
          // modules that provide version.mbt opt into the source-level check.
          None => ()
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
