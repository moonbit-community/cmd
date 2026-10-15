///|
/// Metadata captured once for a runner invocation. Values unavailable through
/// a fixed harness probe remain empty and make reproducibility partial.
pub(all) struct RunMetadata {
  schema : Int32
  run_id : String
  git_revision : String
  git_dirty : String
  toolchain : String
  runner_version : String
  registry_hash : String
  manifest_hash : String
  case_corpus_hash : String
  native_artifact_hash : String
  wasm_artifact_hash : String
  oracle_profile_id : String
  oracle_image_digest : String
  oracle_versions_hash : String
  moonx_coordinates : Array[String]
  platform : String
  os : String
  architecture : String
  locale : String
  timezone : String
  docker_version : String
  policy_hash : String
  environment_fingerprint : String
  host_environment_fingerprint : String
  execution_environments : Array[ExecutionEnvironment]
  started_at_ms : Int64
  ended_at_ms : Int64
  reproducibility_status : String
} derive(FromJson, ToJson, @debug.Debug)

///|
/// SHA-256 is used for all content fingerprints written by the harness.
pub fn sha256_bytes(bytes : Bytes) -> String {
  @crypto.bytes_to_hex_string(@crypto.sha256(bytes))
}

///|
/// Hash UTF-8 text without normalizing its bytes first.
pub fn sha256_text(text : String) -> String {
  sha256_bytes(@utf8.encode(text))
}

///|
/// Return canonical JSON with object keys sorted recursively.  This avoids
/// map iteration order becoming part of a manifest or registry fingerprint.
pub fn canonical_json(value : Json) -> String {
  match value {
    Null => "null"
    True => "true"
    False => "false"
    Number(_, ..) => value.stringify()
    String(value) => Json::string(value).stringify()
    Array(items) =>
      "[" + items.map(item => canonical_json(item)).join(",") + "]"
    Object(fields) => {
      let keys = fields.keys().collect()
      keys.sort()
      let entries = keys.map(key => {
        Json::string(key).stringify() + ":" + canonical_json(fields[key])
      })
      "{" + entries.join(",") + "}"
    }
  }
}

///|
/// Hash JSON after canonicalizing object key order.
pub fn json_digest(value : Json) -> String {
  sha256_text(canonical_json(value))
}

///|
/// Hash a single file.  A missing or unreadable path returns an empty digest
/// so callers can distinguish an unavailable input from a valid hash.
pub async fn file_digest(path : String) -> String {
  guard @fs.exists(path) else { return "" }
  let data = @fs.read_file(path) catch { _ => return "" }
  sha256_bytes(data.binary())
}

///|
/// Hash a file or directory using sorted relative paths and file bytes.  The
/// path labels and directory markers make two trees with different layouts
/// produce different fingerprints while remaining independent of traversal
/// order and filesystem enumeration order.
pub async fn artifact_digest(path : String) -> String {
  guard @fs.exists(path) else { return "" }
  let records : Array[(String, String, Bytes)] = []
  collect_artifact_records(path, "", records) catch {
    _ => return ""
  }
  records.sort_by_key(item => item.0)
  json_digest(
    Json(
      records.map(record => {
        let (relative, kind, bytes) = record
        {
          "path": Json(relative),
          "kind": Json(kind),
          "sha256": Json(sha256_bytes(bytes)),
        }
      }),
    ),
  )
}

///|
/// Fingerprint only the exact cached Wasm assets consumed by pinned MoonX
/// coordinates. A missing asset yields partial provenance, never a coordinate
/// hash presented as an artifact hash. Cache locations are toolchain-specific.
pub async fn moonx_artifact_digest(coordinates : ArrayView[String]) -> String {
  let home = env_or_empty("MOON_HOME")
  if home == "" || coordinates.is_empty() {
    return ""
  }
  let unique : Set[String] = Set([])
  for coordinate in coordinates {
    unique.add(coordinate)
  }
  let ordered = unique.to_array()
  ordered.sort()
  let assets : Array[Json] = []
  for coordinate in ordered {
    let parts = coordinate.split("@").map(value => value.to_owned()).collect()
    guard parts.length() == 2 else { return "" }
    let package_name = parts[0]
    let version = parts[1]
    let names = package_name.split("/").map(value => value.to_owned()).collect()
    guard names.length() == 2 &&
      names[0] == "cli" &&
      safe_relative_path(names[1]) &&
      safe_relative_path(version) else {
      return ""
    }
    let path = home +
      "/registry/cache/assets/" +
      package_name +
      "/" +
      version +
      "/" +
      names[1] +
      ".wasm"
    let digest = file_digest(path)
    guard digest != "" else { return "" }
    assets.push({ "coordinate": Json(coordinate), "sha256": Json(digest) })
  }
  json_digest(Json(assets))
}

///|
pub fn with_wasm_artifact_hash(
  metadata : RunMetadata,
  digest : String,
) -> RunMetadata {
  let updated = { ..metadata, wasm_artifact_hash: digest, }
  {
    ..updated,
    reproducibility_status: if metadata.reproducibility_status ==
      "changed-during-run" {
      "changed-during-run"
    } else if complete_enough(updated) {
      "complete"
    } else {
      "partial"
    },
  }
}

///|
/// Preserve the inputs observed before execution and reject a complete label
/// when the checkout, fixtures, policy, environment, or artifacts changed.
pub fn finalize_run_metadata(
  start : RunMetadata,
  finish : RunMetadata,
) -> RunMetadata {
  let stable = start.reproducibility_status != "changed-during-run" &&
    finish.reproducibility_status != "changed-during-run" &&
    start.git_revision == finish.git_revision &&
    start.git_dirty == finish.git_dirty &&
    start.registry_hash == finish.registry_hash &&
    start.manifest_hash == finish.manifest_hash &&
    start.case_corpus_hash == finish.case_corpus_hash &&
    start.native_artifact_hash == finish.native_artifact_hash &&
    start.wasm_artifact_hash == finish.wasm_artifact_hash &&
    start.oracle_profile_id == finish.oracle_profile_id &&
    start.oracle_image_digest == finish.oracle_image_digest &&
    start.oracle_versions_hash == finish.oracle_versions_hash &&
    start.policy_hash == finish.policy_hash &&
    start.host_environment_fingerprint == finish.host_environment_fingerprint &&
    start.toolchain == finish.toolchain
  let metadata = {
    ..start,
    ended_at_ms: finish.ended_at_ms,
    execution_environments: finish.execution_environments,
    environment_fingerprint: finish.environment_fingerprint,
  }
  {
    ..metadata,
    reproducibility_status: if !stable {
      "changed-during-run"
    } else if complete_enough(metadata) {
      "complete"
    } else {
      "partial"
    },
  }
}

///|
async fn collect_artifact_records(
  path : String,
  relative : String,
  records : Array[(String, String, Bytes)],
) -> Unit {
  let kind = @fs.kind(path, follow_symlink=false) catch {
    _ => @fs.FileKind::Unknown
  }
  match kind {
    @fs.FileKind::Directory => {
      // Directory markers preserve empty directories.  readdir(sort=true)
      // plus the final sort below makes the digest traversal-independent.
      records.push((relative, "directory", b""))
      let names = @fs.readdir(
        path,
        include_hidden=true,
        include_special=false,
        sort=true,
      )
      for name in names {
        let child = @path.Path(path).join(Path(name)).to_string()
        let child_relative = if relative == "" {
          name
        } else {
          @path.Path(relative).join(Path(name)).to_string()
        }
        collect_artifact_records(child, child_relative, records)
      }
    }
    @fs.FileKind::Regular | @fs.FileKind::SymLink => {
      let data = @fs.read_file(path)
      records.push((relative, "file", data.binary()))
    }
    _ => records.push((relative, "special", b""))
  }
}

///|
fn first_environment(names : Array[String]) -> String {
  for name in names {
    match @env.get_env_var(name) {
      Some(value) if !value.is_empty() => return value
      _ => ()
    }
  }
  ""
}

///|
/// Probe a fixed executable for one short, non-sensitive metadata value. This
/// runs only in the test harness; command implementations never call it.
async fn probe_output(program : String, args : Array[String]) -> String {
  let result = run_with_deadline(
      program,
      args,
      10000,
      capture_environment=false,
    ).output catch {
      _ => return ""
    }
  if result.status != 0 {
    return ""
  }
  @utf8.decode(result.stdout).trim().to_owned()
}

///|
async fn probe_git_revision() -> String {
  let value = probe_output("git", ["rev-parse", "HEAD"])
  if value == "" {
    first_environment(["GIT_REVISION", "GITHUB_SHA", "CI_COMMIT_SHA"])
  } else {
    value
  }
}

///|
async fn probe_git_dirty() -> String {
  let result = run_with_deadline(
      "git",
      ["status", "--porcelain", "--untracked-files=all"],
      10000,
      stdin=b"",
      capture_environment=false,
    ).output catch {
      _ => return first_environment(["GIT_DIRTY"])
    }
  if result.status != 0 {
    return first_environment(["GIT_DIRTY"])
  }
  if result.stdout.length() == 0 {
    "false"
  } else {
    "true"
  }
}

///|
async fn probe_toolchain() -> String {
  let value = probe_output("moon", ["--version"])
  if value == "" {
    first_environment(["MOONBIT_TOOLCHAIN", "MOON_VERSION"])
  } else {
    value
  }
}

///|
async fn probe_docker_version() -> String {
  let value = probe_output("docker", ["--version"])
  if value == "" {
    first_environment(["DOCKER_VERSION"])
  } else {
    value
  }
}

///|
fn environment_fingerprint() -> String {
  // This allowlist intentionally excludes PATH, HOME, credentials and other
  // high-cardinality or sensitive variables.
  let names = [
    "CI", "GIT_REVISION", "GIT_DIRTY", "GITHUB_SHA", "CI_COMMIT_SHA", "MOONBIT_TOOLCHAIN",
    "MOON_VERSION", "RUNNER_VERSION", "LC_ALL", "LANG", "TZ", "HOSTTYPE", "TARGETARCH",
    "DOCKER_VERSION", "ORACLE_IMAGE_DIGEST", "TEST_REGISTRY_REVISION",
  ]
  let values : Array[String] = []
  for name in names {
    match @env.get_env_var(name) {
      Some(value) => values.push(name + "=" + value)
      None => ()
    }
  }
  values.sort()
  sha256_text(values.join("\n"))
}

///|
fn env_or_empty(name : String) -> String {
  @env.get_env_var(name).unwrap_or("")
}

///|
fn join_nonempty(values : Array[String], separator : String) -> String {
  values.filter(value => !value.is_empty()).join(separator)
}

///|
async fn platform_architecture() -> String {
  let observed = probe_output("uname", ["-m"])
  if observed == "" {
    first_environment(["TARGETARCH", "HOSTTYPE", "PROCESSOR_ARCHITECTURE"])
  } else {
    observed
  }
}

///|
async fn platform_os() -> String {
  let observed = probe_output("uname", ["-sr"])
  if observed == "" {
    let configured = first_environment(["OS", "RUNNER_OS"])
    if configured == "" {
      host_platform()
    } else {
      configured
    }
  } else {
    observed
  }
}

///|
async fn platform_timezone() -> String {
  let configured = env_or_empty("TZ")
  if configured == "" {
    probe_output("date", ["+%Z %z"])
  } else {
    configured
  }
}

///|
async fn platform_locale() -> String {
  let configured = first_environment(["LC_ALL", "LANG"])
  if configured != "" {
    return configured
  }
  probe_output("locale", [])
}

///|
fn complete_enough(metadata : RunMetadata) -> Bool {
  run_metadata_errors(metadata).is_empty()
}

///|
/// Recompute provenance completeness from its fields. A supplied classification
/// string is never evidence for the fields it purports to summarize. An unused
/// backend may have no artifact, but coordinates cannot substitute for bytes.
pub fn run_metadata_errors(metadata : RunMetadata) -> Array[String] {
  let failures : Array[String] = []
  if metadata.reproducibility_status == "changed-during-run" {
    failures.push("execution inputs changed during run")
  }
  if metadata.schema != 1 {
    failures.push("unsupported run metadata schema")
  }
  for
    (name, value) in [
      ("run_id", metadata.run_id),
      ("git_revision", metadata.git_revision),
      ("toolchain", metadata.toolchain),
      ("runner_version", metadata.runner_version),
      ("platform", metadata.platform),
      ("os", metadata.os),
      ("architecture", metadata.architecture),
      ("locale", metadata.locale),
      ("timezone", metadata.timezone),
    ] {
    if value == "" {
      failures.push("missing " + name)
    }
  }
  if !["true", "false"].contains(metadata.git_dirty) {
    failures.push("git_dirty must be true or false")
  }
  for
    (name, digest) in [
      ("registry_hash", metadata.registry_hash),
      ("manifest_hash", metadata.manifest_hash),
      ("case_corpus_hash", metadata.case_corpus_hash),
      ("policy_hash", metadata.policy_hash),
      ("environment_fingerprint", metadata.environment_fingerprint),
      ("host_environment_fingerprint", metadata.host_environment_fingerprint),
    ] {
    if !valid_sha256(digest) {
      failures.push("missing or invalid " + name)
    }
  }
  if metadata.environment_fingerprint !=
    execution_environment_digest(metadata.execution_environments) {
    failures.push("execution environment fingerprint mismatch")
  }
  if metadata.execution_environments.is_empty() {
    failures.push("missing executed environment profiles")
  }
  if metadata.native_artifact_hash == "" && metadata.wasm_artifact_hash == "" {
    failures.push("missing executed artifact hash")
  }
  for
    (name, digest) in [
      ("native_artifact_hash", metadata.native_artifact_hash),
      ("wasm_artifact_hash", metadata.wasm_artifact_hash),
    ] {
    if digest != "" && !valid_sha256(digest) {
      failures.push("invalid " + name)
    }
  }
  if metadata.oracle_profile_id != "" {
    if !valid_image_digest(metadata.oracle_image_digest) {
      failures.push("missing or invalid oracle_image_digest")
    }
    if !valid_sha256(metadata.oracle_versions_hash) {
      failures.push("missing or invalid oracle_versions_hash")
    }
    if metadata.docker_version == "" {
      failures.push("missing docker_version")
    }
  } else if metadata.oracle_image_digest != "" ||
    metadata.oracle_versions_hash != "" {
    failures.push("oracle identity requires oracle_profile_id")
  }
  if metadata.started_at_ms <= 0L ||
    metadata.ended_at_ms < metadata.started_at_ms {
    failures.push("invalid run timestamps")
  }
  failures
}

///|
/// Bind the complete identity returned by successful oracle preflight before
/// any differential cases execute. Rebinding an observed identity is drift.
pub fn with_oracle_identity(
  metadata : RunMetadata,
  identity : OracleIdentity,
) -> RunMetadata {
  let inventory_hash = sha256_text(identity.versions)
  let changed = metadata.reproducibility_status == "changed-during-run" ||
    (
      metadata.oracle_profile_id != "" &&
      metadata.oracle_profile_id != identity.profile_id
    ) ||
    (
      metadata.oracle_image_digest != "" &&
      metadata.oracle_image_digest != identity.digest
    ) ||
    (
      metadata.oracle_versions_hash != "" &&
      metadata.oracle_versions_hash != inventory_hash
    )
  if changed {
    return { ..metadata, reproducibility_status: "changed-during-run", }
  }
  let updated = {
    ..metadata,
    oracle_profile_id: identity.profile_id,
    oracle_image_digest: identity.digest,
    oracle_versions_hash: inventory_hash,
  }
  {
    ..updated,
    reproducibility_status: if complete_enough(updated) {
      "complete"
    } else {
      "partial"
    },
  }
}

///|
/// Apply an oracle inventory hash captured after image preflight and recompute
/// the run classification. Runners discover the inventory while starting the
/// oracle, so assigning the field after collection must not leave a stale
/// `partial` status in the report.
pub fn with_oracle_versions_hash(
  metadata : RunMetadata,
  oracle_versions_hash : String,
) -> RunMetadata {
  let metadata = { ..metadata, oracle_versions_hash, }
  {
    ..metadata,
    reproducibility_status: if metadata.reproducibility_status ==
      "changed-during-run" {
      "changed-during-run"
    } else if complete_enough(metadata) {
      "complete"
    } else {
      "partial"
    },
  }
}

///|
/// Collect run-level inputs. Fixed host probes provide local truth for git,
/// Moon and Docker; CI may provide authoritative overrides through the
/// documented environment allowlist.
pub async fn collect_run_metadata(
  run_id : String,
  manifest_path? : String,
  case_corpus_path? : String,
  native_root? : String,
  wasm_root? : String,
  registry_path? : String,
  oracle_profile_id? : String,
  oracle_image_digest? : String,
  oracle_versions_path? : String,
  policy_path? : String,
  moonx_coordinates? : ArrayView[String],
  started_at_ms? : Int64,
  ended_at_ms? : Int64,
) -> RunMetadata {
  let started = started_at_ms.unwrap_or(@async.now())
  let manifest_hash = match manifest_path {
    Some(path) => manifest_digest(path)
    None => ""
  }
  let case_corpus_hash = match case_corpus_path {
    Some(path) => manifest_digest(path)
    None => ""
  }
  let registry_hash = match registry_path {
    Some(path) => manifest_digest(path)
    None => env_or_empty("TEST_REGISTRY_HASH")
  }
  let native_artifact_hash = match native_root {
    Some(path) => artifact_digest(path)
    None => ""
  }
  let wasm_artifact_hash = match wasm_root {
    Some(path) => artifact_digest(path)
    None => ""
  }
  let oracle_versions_hash = match oracle_versions_path {
    Some(path) => file_digest(path)
    None => env_or_empty("ORACLE_VERSIONS_HASH")
  }
  let policy_hash = match policy_path {
    Some(path) => artifact_digest(path)
    None => json_digest({ "policy": "no-explicit-policy-file" })
  }
  let coordinates = match moonx_coordinates {
    Some(values) => values.to_owned()
    None => []
  }
  coordinates.sort()
  let git_revision = probe_git_revision()
  let git_dirty = probe_git_dirty()
  let toolchain = probe_toolchain()
  let docker_version = probe_docker_version()
  let os = platform_os()
  let architecture = platform_architecture()
  let timezone = platform_timezone()
  let locale = platform_locale()
  let configured_runner_version = env_or_empty("RUNNER_VERSION")
  let runner_version = if configured_runner_version == "" {
    if git_revision == "" {
      ""
    } else {
      "workspace:" + git_revision
    }
  } else {
    configured_runner_version
  }
  let metadata : RunMetadata = {
    schema: 1,
    run_id,
    git_revision,
    git_dirty,
    toolchain,
    runner_version,
    registry_hash,
    manifest_hash,
    case_corpus_hash,
    native_artifact_hash,
    wasm_artifact_hash,
    oracle_profile_id: oracle_profile_id.unwrap_or(
      env_or_empty("ORACLE_PROFILE_ID"),
    ),
    oracle_image_digest: oracle_image_digest.unwrap_or(
      env_or_empty("ORACLE_IMAGE_DIGEST"),
    ),
    oracle_versions_hash,
    moonx_coordinates: coordinates,
    platform: host_platform(),
    os,
    architecture,
    locale,
    timezone,
    docker_version,
    policy_hash,
    host_environment_fingerprint: environment_fingerprint(),
    execution_environments: captured_execution_environments(),
    environment_fingerprint: execution_environment_digest(
      captured_execution_environments(),
    ),
    started_at_ms: started,
    ended_at_ms: ended_at_ms.unwrap_or(@async.now()),
    reproducibility_status: "partial",
  }
  {
    ..metadata,
    reproducibility_status: if complete_enough(metadata) {
      "complete"
    } else {
      "partial"
    },
  }
}

///|
/// Hash a JSON manifest after canonicalization, recursively including every
/// referenced case file and override.  This makes the corpus fingerprint
/// change when a selected case changes even if the top-level index is stable.
pub async fn manifest_digest(path : String) -> String {
  manifest_digest_at(path, [])
}

///|
async fn manifest_digest_at(path : String, ancestors : Array[String]) -> String {
  guard @fs.exists(path) else { return "" }
  let resolved = @fs.realpath(path) catch { _ => return "" }
  guard !ancestors.contains(resolved) else { return "" }
  let ancestors = [..ancestors, resolved]
  let value = @json.parse(@fs.read_file(path).text()) catch { _ => return "" }
  let children : Array[(String, String)] = []
  for field in ["case_files", "case_overrides"] {
    if value is Object(fields) && fields.get(field) is Some(Array(paths)) {
      for reference in paths {
        guard reference is String(reference) else { return "" }
        let child = case_reference_path(path, reference)
        let digest = manifest_digest_at(child, ancestors)
        guard digest != "" else { return "" }
        children.push((reference, digest))
      }
    }
  }
  children.sort_by_key(item => item.0)
  sha256_text(
    canonical_json(value) +
    "\n" +
    children.map(item => item.0 + "\u0000" + item.1).join("\n"),
  )
}

///|
/// Return the stable identifier used in report records for the artifacts in a
/// run.  Empty hashes are omitted so partial runs do not claim a fake hash.
pub fn artifact_id(metadata : RunMetadata) -> String {
  join_nonempty(
    [
      if metadata.native_artifact_hash == "" {
        ""
      } else {
        "native:" + metadata.native_artifact_hash
      },
      if metadata.wasm_artifact_hash == "" {
        ""
      } else {
        "wasm:" + metadata.wasm_artifact_hash
      },
    ],
    ",",
  )
}

///|
pub extend RunMetadata with ToJson::{to_json}

///|
pub extend RunMetadata with FromJson::{from_json}

///|
pub extend RunMetadata with @debug.Debug::{to_repr}
