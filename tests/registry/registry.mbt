///|
/// A stable registration for one behavior covered by the test system.
///
/// The registry deliberately stores references to the existing implementation
/// instead of re-encoding scenarios or JSON cases. This lets the runner keep
/// its current execution model while giving audits one machine-readable
/// ownership and coverage index.
pub(all) struct RegistryEntry {
  behavior_id : String
  command : String
  owner : String
  surface : Array[String]
  status : String
  implementation : String
  source : String
  case_id : String
  aliases : Array[String]
  coverage : Array[String]
  required_backends : Array[String]
  platforms : Array[String]
  required_evidence : Array[String]
  observations : Array[String]
  oracle_profile : String
} derive(FromJson, ToJson, Debug)

///|
/// The top-level registry document. `schema` is bumped when the shape of an
/// entry changes; behavior IDs remain stable across schema migrations.
pub(all) struct Registry {
  schema : Int32
  entries : Array[RegistryEntry]
  release_commands : Array[ReleaseCommandMetadata]
} derive(FromJson, ToJson, Debug)

///|
/// Executable implementation references decoded from the registry transport.
/// The JSON representation remains readable by standalone MoonBit scripts;
/// runners use this closed set rather than accepting arbitrary source kinds.
pub(all) enum ImplementationBinding {
  PackageTest(file~ : String, name~ : String)
  JsonCase(file~ : String, case_id~ : String)
  StatefulScenario(file~ : String, name~ : String)
  CompatibilityCohort(file~ : String, name~ : String)
  PolicyTest(file~ : String, name~ : String)
  MetadataProbe(file~ : String, command~ : String)
}

///|
pub fn RegistryEntry::binding(
  self : RegistryEntry,
) -> ImplementationBinding raise Failure {
  if self.implementation == "json-case" {
    guard self.case_id != "" && self.source.has_suffix(".json") else {
      fail("invalid JSON case reference: " + self.behavior_id)
    }
    return JsonCase(file=self.source, case_id=self.case_id)
  }
  let parts = self.source.split("::").collect()
  guard parts.length() == 2 && !parts[0].is_empty() && !parts[1].is_empty() else {
    fail("named source reference required: " + self.behavior_id)
  }
  let file = parts[0].to_owned()
  let name = parts[1].to_owned()
  match self.implementation {
    "package-test" => PackageTest(file~, name~)
    "stateful-scenario" => StatefulScenario(file~, name~)
    "compatibility-cohort" => CompatibilityCohort(file~, name~)
    "policy-test" => PolicyTest(file~, name~)
    "metadata-probe" => MetadataProbe(file~, command=name)
    _ => fail("unknown registry implementation: " + self.implementation)
  }
}

///|
pub fn RegistryEntry::is_case(self : RegistryEntry) -> Bool {
  self.implementation == "json-case"
}

///|
pub fn RegistryEntry::is_oracle_bound(self : RegistryEntry) -> Bool {
  self.required_evidence.contains("upstream-differential") ||
  self.required_evidence.contains("published-differential")
}

///|
/// Supported contracts executed on both targets require an actual comparison
/// of their portable observations. Two independent contract passes do not
/// satisfy this requirement.
pub fn RegistryEntry::requires_backend_pair(self : RegistryEntry) -> Bool {
  self.status == "supported" &&
  self.required_evidence.contains("contract") &&
  self.required_backends.contains("native") &&
  self.required_backends.contains("wasm")
}

///|
/// Return the stable IDs that an execution row may use for this binding.
///
/// The prefixed IDs are deliberately derived from the typed source binding,
/// rather than from a display label. This prevents a scenario and a cohort
/// with the same local name from borrowing one another's evidence.
pub fn RegistryEntry::evidence_ids(
  self : RegistryEntry,
) -> Array[String] raise Failure {
  let ids : Array[String] = [self.behavior_id, ..self.aliases]
  match self.binding() {
    StatefulScenario(file=_, name~) => ids.push("scenario:" + name)
    CompatibilityCohort(file=_, name~) => ids.push("cohort:" + name)
    PolicyTest(file=_, name~) => ids.push("policy:" + name)
    MetadataProbe(file=_, command~) => ids.push("metadata:" + command)
    PackageTest(file~, name~) => ids.push("package-test:" + file + "::" + name)
    JsonCase(file=_, case_id~) => ids.push(case_id)
  }
  ids
}

///|
/// Read a registry document without coupling callers to the on-disk format.
pub async fn load(path : String) -> Registry raise Failure {
  // Keep the package's async file access explicit; registry loading is used
  // by async runners as well as by synchronous schema checks.
  ignore(@async.platform)
  let text = @fs.read_file(path).text() catch {
    _ => fail("registry read failed")
  }
  let value = @json.parse(text) catch {
    _ => fail("registry JSON parse failed")
  }
  @json.from_json(value) catch {
    _ => fail("registry schema decode failed")
  }
}

///|
fn contains_all(
  values : ArrayView[String],
  required : ArrayView[String],
) -> Bool {
  required.all(value => values.contains(value))
}

///|
/// Validate intrinsic registry invariants.
///
/// Source/case existence is checked separately by `validate_case_bindings`,
/// because a registry package must also be usable by tools that do not load the
/// full command case corpus.
pub fn validate(registry : Registry) -> Array[String] {
  validate_registry(registry, require_pair=true)
}

///|
/// Validate an archived registry only after its frozen provenance has been
/// verified. Historical evidence requirements are immutable; all structural,
/// binding, evidence-kind and declared-backend checks still apply.
pub fn validate_frozen_registry(registry : Registry) -> Array[String] {
  validate_registry(registry, require_pair=false)
}

///|
fn validate_registry(
  registry : Registry,
  require_pair~ : Bool,
) -> Array[String] {
  let failures : Array[String] = []
  if registry.schema != 2 {
    failures.push("registry: unsupported schema \{registry.schema}")
  }
  let seen : Map[String, Bool] = Map([])
  let bindings : Map[String, Bool] = Map([])
  let evidence_owners : Map[String, String] = Map([])
  for entry in registry.entries {
    if entry.behavior_id == "" {
      failures.push("registry: behavior_id must be nonempty")
    } else if seen.contains(entry.behavior_id) {
      failures.push("registry: duplicate behavior_id '\{entry.behavior_id}'")
    }
    seen[entry.behavior_id] = true
    for legacy_id in entry.aliases {
      if legacy_id == "" {
        failures.push("\{entry.behavior_id}: aliases must be nonempty")
      } else if seen.contains(legacy_id) {
        failures.push("registry: duplicate behavior ID or alias '\{legacy_id}'")
      }
      seen[legacy_id] = true
    }
    if entry.owner == "" {
      failures.push("\{entry.behavior_id}: owner is required")
    }
    if entry.source == "" {
      failures.push("\{entry.behavior_id}: source is required")
    }
    ignore(entry.binding()) catch {
      error => failures.push(error.to_string())
    }
    let binding_key = entry.implementation +
      "::" +
      entry.source +
      "::" +
      entry.case_id
    if bindings.contains(binding_key) {
      failures.push(
        "\{entry.behavior_id}: duplicate executable binding '\{entry.source}'",
      )
    }
    bindings[binding_key] = true
    let evidence_ids = entry.evidence_ids() catch { _ => [] }
    for id in evidence_ids {
      if evidence_owners.get(id) is Some(owner) && owner != entry.behavior_id {
        failures.push(
          "registry: evidence ID '\{id}' belongs to multiple behaviors",
        )
      }
      evidence_owners[id] = entry.behavior_id
    }
    if ![
        "package-test", "json-case", "stateful-scenario", "compatibility-cohort",
        "policy-test", "metadata-probe",
      ].contains(entry.implementation) {
      failures.push(
        "\{entry.behavior_id}: unsupported implementation '\{entry.implementation}'",
      )
    }
    if !["supported", "boundary", "unsupported"].contains(entry.status) {
      failures.push(
        "\{entry.behavior_id}: unsupported status '\{entry.status}'",
      )
    }
    for backend in entry.required_backends {
      if !["native", "wasm"].contains(backend) {
        failures.push("\{entry.behavior_id}: unsupported backend '\{backend}'")
      }
    }
    if entry.required_backends.is_empty() {
      failures.push("\{entry.behavior_id}: at least one backend is required")
    }
    for platform in entry.platforms {
      if !["linux", "macos", "windows", "posix"].contains(platform) {
        failures.push(
          "\{entry.behavior_id}: unsupported platform '\{platform}'",
        )
      }
    }
    if entry.platforms.contains("posix") &&
      entry.platforms.any(platform => ["linux", "macos"].contains(platform)) {
      failures.push(
        "\{entry.behavior_id}: POSIX platform exception must not duplicate linux or macos",
      )
    }
    if entry.observations.is_empty() {
      failures.push(
        "\{entry.behavior_id}: at least one observation is required",
      )
    }
    if entry.required_evidence.is_empty() {
      failures.push(
        "\{entry.behavior_id}: at least one evidence requirement is required",
      )
    }
    for evidence in entry.required_evidence {
      if ![
          "contract", "backend-pair", "upstream-differential", "published-differential",
          "boundary", "supplementary",
        ].contains(evidence) {
        failures.push(
          "\{entry.behavior_id}: unsupported evidence '\{evidence}'",
        )
      }
    }
    for observation in entry.observations {
      if ![
          "status", "stdout", "stderr", "file-content", "file-type", "file-mode",
          "file-identity", "symlink-target", "atime", "mtime", "ctime",
        ].contains(observation) {
        failures.push(
          "\{entry.behavior_id}: unsupported observation '\{observation}'",
        )
      }
    }
    if entry.is_case() {
      if entry.case_id == "" {
        failures.push("\{entry.behavior_id}: JSON cases require case_id")
      }
      if entry.command == "" {
        failures.push("\{entry.behavior_id}: JSON cases require command")
      }
      if !entry.source.has_suffix(".json") {
        failures.push("\{entry.behavior_id}: JSON case source must be .json")
      }
    } else if entry.case_id != "" {
      failures.push("\{entry.behavior_id}: only JSON cases may set case_id")
    }
    if entry.status == "boundary" &&
      !entry.required_evidence.contains("boundary") {
      failures.push(
        "\{entry.behavior_id}: boundary status requires boundary evidence",
      )
    }
    if entry.is_oracle_bound() && entry.oracle_profile == "" {
      failures.push(
        "\{entry.behavior_id}: oracle-bound entry requires oracle_profile",
      )
    }
    if entry.required_evidence.contains("backend-pair") &&
      !contains_all(entry.required_backends, ["native", "wasm"]) {
      failures.push(
        "\{entry.behavior_id}: backend-pair evidence requires native and wasm",
      )
    }
    if require_pair &&
      entry.requires_backend_pair() &&
      !entry.required_evidence.contains("backend-pair") {
      failures.push(
        "\{entry.behavior_id}: supported dual-backend contract requires backend-pair evidence",
      )
    }
  }
  failures.append(validate_release_commands(registry))
  failures
}

///|
/// Canonical workspace corpus paths, in stable order. Paths are relative to
/// the repository root, independently of a runner's compatibility manifest.
pub fn case_sources(registry : Registry) -> Array[String] {
  let paths : Array[String] = []
  for entry in registry.entries {
    if entry.is_case() && !paths.contains(entry.source) {
      paths.push(entry.source)
    }
  }
  paths.sort_by((left, right) => left.lexical_compare(right))
  paths
}

///|
/// Return the named implementation references registered for an executor.
pub fn implementation_ids(registry : Registry, kind : String) -> Array[String] {
  registry.entries
  .filter(entry => entry.implementation == kind)
  .map(entry => {
    let components = entry.source.split("::").collect()
    if components.length() == 2 {
      components[1].to_owned()
    } else {
      entry.case_id
    }
  })
}

///|
/// Check the registry against the case IDs discovered from the active case
/// corpus. This catches both directions of drift:
///
/// * an entry points at a removed or renamed JSON case (orphan registry row);
/// * a new JSON case has no registry row (orphan source behavior).
///
/// The input is intentionally an `ArrayView` so callers can obtain IDs from
/// any case loader, including the workspace and release runners.
pub fn validate_case_bindings(
  registry : Registry,
  case_ids : ArrayView[String],
) -> Array[String] {
  let failures : Array[String] = []
  let source_ids : Map[String, Bool] = Map([])
  for id in case_ids {
    if id == "" {
      failures.push("case corpus: empty case ID")
    } else if source_ids.contains(id) {
      failures.push("case corpus: duplicate case ID '\{id}'")
    }
    source_ids[id] = true
  }
  let registered_ids : Map[String, Bool] = Map([])
  for entry in registry.entries {
    if entry.is_case() {
      if registered_ids.contains(entry.case_id) {
        failures.push("registry: duplicate case binding '\{entry.case_id}'")
      }
      registered_ids[entry.case_id] = true
      for legacy_id in entry.aliases {
        if registered_ids.contains(legacy_id) {
          failures.push("registry: duplicate case binding '\{legacy_id}'")
        }
        registered_ids[legacy_id] = true
      }
      if !source_ids.contains(entry.case_id) {
        failures.push("registry: orphan JSON case binding '\{entry.case_id}'")
      }
    }
  }
  for id in case_ids {
    if !registered_ids.contains(id) {
      failures.push("registry: unregistered JSON case '\{id}'")
    }
  }
  failures
}

///|
pub fn behavior_ids(registry : Registry) -> Array[String] {
  registry.entries.map(entry => entry.behavior_id)
}

///|
pub extend RegistryEntry with @json.FromJson::{from_json}

///|
pub extend RegistryEntry with ToJson::{to_json}

///|
pub extend RegistryEntry with @debug.Debug::{to_repr}

///|
pub extend Registry with @json.FromJson::{from_json}

///|
pub extend Registry with ToJson::{to_json}

///|
pub extend Registry with @debug.Debug::{to_repr}
