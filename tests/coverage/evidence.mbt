///|
type AuditRunMetadata = @testkit.RunMetadata

///|
struct EvidenceRow {
  id : String
  result : String
  verification : String
  backend : String
  platform : String
  source_version : String
  observations : Array[String]
  missing_observations : Array[String]
  run_id : String
  reproducibility_status : String
  registry_revision : String
  oracle_profile_id : String
  artifact_id : String
} derive(FromJson)

///|
priv struct EvidenceBundle {
  report_path : String
  metadata : AuditRunMetadata
  rows : Array[EvidenceRow]
  selected_ids : Array[String]
  oracle_verified : Bool
  published_coordinates : Array[String]
}

///|
fn valid_sha256(value : String) -> Bool {
  value.length() == 64 &&
  value.iter().all(char => char is ('0'..<='9') || char is ('a'..<='f'))
}

///|
fn immutable_digest(value : String) -> Bool {
  value.has_prefix("sha256:") &&
  valid_sha256(value.strip_prefix("sha256:").unwrap().to_owned())
}

///|
fn evidence_id_matches(entry : @registry.RegistryEntry, id : String) -> Bool {
  let ids = entry.evidence_ids() catch { _ => return false }
  ids.contains(id)
}

///|
fn platform_applies(entry : @registry.RegistryEntry, platform : String) -> Bool {
  entry.platforms.is_empty() ||
  entry.platforms.contains(platform) ||
  (entry.platforms.contains("posix") && ["linux", "macos"].contains(platform))
}

///|
fn observation_matches(
  observations : ArrayView[String],
  required : String,
) -> Bool {
  observations.contains(required) ||
  (match required {
    "file-content" => observations.contains("content")
    "file-type" => observations.contains("type")
    "file-mode" => observations.contains("mode")
    "file-identity" => observations.contains("identity")
    _ => false
  })
}

///|
fn verification_supports(row : EvidenceRow, evidence : String) -> Bool {
  let published = row.backend == "published-wasm"
  match evidence {
    "contract" =>
      !published &&
      ["contract", "backend-pair", "differential"].contains(row.verification)
    "backend-pair" =>
      row.verification == "backend-pair" && row.backend == "native+wasm"
    "upstream-differential" => !published && row.verification == "differential"
    "published-differential" => published && row.verification == "differential"
    "boundary" => !published && row.verification == "boundary"
    // This proves execution of a retained diagnostic only. It cannot satisfy
    // any contract, pair, boundary or immutable differential requirement.
    "supplementary" => !published && row.verification == "supplementary"
    _ => false
  }
}

///|
fn validate_metadata(
  metadata : AuditRunMetadata,
  registry_hash : String,
  corpus_hashes : ArrayView[String],
  manifest_hashes : ArrayView[String],
  head : String,
) -> Array[String] {
  let failures = @testkit.run_metadata_errors(metadata).map(problem => {
    "metadata: " + problem
  })
  if metadata.git_dirty != "false" {
    failures.push(
      "metadata: explicit committed head requires a clean source revision; dirty runs cannot prove the committed range",
    )
  }
  if metadata.git_revision != head {
    failures.push("metadata: git_revision does not match resolved head")
  }
  if metadata.reproducibility_status != "complete" {
    failures.push("metadata: reproducibility_status must be complete")
  }
  if registry_hash == "" || metadata.registry_hash != registry_hash {
    failures.push("metadata: registry_hash does not match registry")
  }
  if metadata.case_corpus_hash == "" ||
    !corpus_hashes.contains(metadata.case_corpus_hash) {
    failures.push(
      "metadata: case_corpus_hash does not match a supplied current corpus",
    )
  }
  if metadata.manifest_hash == "" ||
    !manifest_hashes.contains(metadata.manifest_hash) {
    failures.push(
      "metadata: manifest_hash does not match a supplied current manifest",
    )
  }
  failures
}

///|
fn validate_row_identity(
  row : EvidenceRow,
  metadata : AuditRunMetadata,
) -> Array[String] {
  let failures : Array[String] = []
  if !["native", "wasm", "native+wasm", "published-wasm"].contains(row.backend) {
    failures.push("unknown backend identity")
  }
  if row.backend == "native+wasm" && row.verification != "backend-pair" {
    failures.push(
      "combined backend identity requires backend-pair verification",
    )
  }
  if row.run_id != metadata.run_id {
    failures.push("mismatched run_id")
  }
  if row.registry_revision != metadata.registry_hash {
    failures.push("mismatched registry_revision")
  }
  if row.reproducibility_status != "complete" {
    failures.push("incomplete reproducibility")
  }
  if row.platform != metadata.platform {
    failures.push("mismatched platform")
  }
  if row.oracle_profile_id != metadata.oracle_profile_id {
    failures.push("mismatched oracle_profile_id")
  }
  let artifacts : Array[String] = []
  if metadata.native_artifact_hash != "" {
    artifacts.push("native:" + metadata.native_artifact_hash)
  }
  if metadata.wasm_artifact_hash != "" {
    artifacts.push("wasm:" + metadata.wasm_artifact_hash)
  }
  if row.artifact_id != artifacts.join(",") {
    failures.push("mismatched artifact_id")
  }
  let native = row.backend == "native" || row.backend == "native+wasm"
  let wasm = row.backend == "wasm" || row.backend == "native+wasm"
  if native && !valid_sha256(metadata.native_artifact_hash) {
    failures.push("missing Native artifact hash")
  }
  if wasm && !valid_sha256(metadata.wasm_artifact_hash) {
    failures.push("missing Wasm artifact hash")
  }
  if row.backend == "published-wasm" &&
    (
      !row.source_version.has_prefix("cli/") ||
      !metadata.moonx_coordinates.contains(row.source_version)
    ) {
    failures.push("published row does not match an exact MoonX coordinate")
  }
  failures
}

///|
fn row_proves(
  row : EvidenceRow,
  metadata : AuditRunMetadata,
  entry : @registry.RegistryEntry,
  evidence : String,
  backend : String,
  observations : ArrayView[String],
) -> Bool {
  guard row.result == "pass" &&
    row.missing_observations.is_empty() &&
    platform_applies(entry, row.platform) &&
    validate_row_identity(row, metadata).is_empty() &&
    verification_supports(row, evidence) &&
    observations.all(observation => {
      observation_matches(row.observations, observation)
    }) else {
    return false
  }
  if evidence != "published-differential" &&
    row.backend != backend &&
    row.backend != "native+wasm" {
    return false
  }
  if row.verification == "differential" {
    guard entry.oracle_profile != "" &&
      metadata.oracle_profile_id == entry.oracle_profile &&
      immutable_digest(metadata.oracle_image_digest) &&
      valid_sha256(metadata.oracle_versions_hash) else {
      return false
    }
  }
  true
}

///|
fn validate_report_evidence(
  declaration : ChangeDeclaration,
  registry : @registry.Registry,
  bundles : ArrayView[EvidenceBundle],
  platforms~ : Array[String] = [],
) -> Array[String] {
  let failures : Array[String] = []
  for record in declaration.coverage {
    guard find_entry(registry, record.behavior_id) is Some(entry) else {
      continue
    }
    let references = report_references(record)
    let selected = bundles.filter(bundle => {
      references.contains(bundle.report_path)
    })
    for reference in references {
      if !selected.any(bundle => bundle.report_path == reference) {
        failures.push(
          "evidence: '\{entry.behavior_id}' report has no supplied run metadata '\{reference}'",
        )
      }
    }
    for bundle in selected {
      for row in bundle.rows.filter(row => evidence_id_matches(entry, row.id)) {
        if row.backend == "published-wasm" &&
          !bundle.published_coordinates.contains(row.source_version) {
          failures.push(
            "evidence: '\{entry.behavior_id}' MoonX coordinate is not declared by the run manifest",
          )
        }
        if entry.implementation == "json-case" &&
          !bundle.selected_ids.any(id => evidence_id_matches(entry, id)) {
          failures.push(
            "evidence: '\{entry.behavior_id}' is not selected by the run manifest",
          )
        }
        for problem in validate_row_identity(row, bundle.metadata) {
          failures.push(
            "evidence: '\{entry.behavior_id}' \{problem} in \{bundle.metadata.run_id}",
          )
        }
        if platform_applies(entry, row.platform) &&
          (row.result != "pass" || !row.missing_observations.is_empty()) {
          failures.push(
            "evidence: '\{entry.behavior_id}' did not pass all required observations in \{bundle.metadata.run_id}",
          )
        }
      }
    }
    let backends = sorted_unique(
      [
        ..entry.required_backends,
        ..declaration.required_backends,
        ..record.backends,
      ],
    )
    let observations = sorted_unique(
      [
        ..entry.observations,
        ..declaration.required_observations,
        ..record.observations,
      ],
    )
    let evidence = sorted_unique(
      [..required_evidence(declaration, registry, entry), ..record.evidence],
    )
    for requirement in evidence {
      let targets = if requirement == "published-differential" {
        ["published-wasm"]
      } else {
        backends
      }
      if targets.is_empty() {
        failures.push(
          "evidence: '\{entry.behavior_id}' has no required backend",
        )
      }
      for backend in targets {
        let required_platforms = evidence_platforms(
          entry, requirement, platforms,
        )
        if required_platforms.is_empty() {
          failures.push(
            "evidence: '\{entry.behavior_id}' has no applicable platform for '\{requirement}'",
          )
        }
        for platform in required_platforms {
          if !selected.any(bundle => {
              (platform == "" || bundle.metadata.platform == platform) &&
              (
                entry.implementation != "json-case" ||
                bundle.selected_ids.any(id => evidence_id_matches(entry, id))
              ) &&
              bundle.rows.any(row => {
                evidence_id_matches(entry, row.id) &&
                (row.verification != "differential" || bundle.oracle_verified) &&
                (
                  row.backend != "published-wasm" ||
                  bundle.published_coordinates.contains(row.source_version)
                ) &&
                row_proves(
                  row,
                  bundle.metadata,
                  entry,
                  requirement,
                  backend,
                  observations,
                )
              })
            }) {
            failures.push(
              "evidence: '\{entry.behavior_id}' lacks '\{requirement}' on '\{backend}' with every required observation" +
              (if platform == "" {
                ""
              } else {
                " on platform '" + platform + "'"
              }),
            )
          }
        }
      }
    }
  }
  failures
}

///|
fn evidence_platforms(
  entry : @registry.RegistryEntry,
  requirement : String,
  platforms : ArrayView[String],
) -> Array[String] {
  if platforms.is_empty() {
    return [""]
  }
  platforms.filter(platform => {
    platform_applies(entry, platform) &&
    (if ["upstream-differential", "published-differential"].contains(
        requirement,
      ) {
      platform == "linux"
    } else {
      true
    })
  })
}

///|
pub extend EvidenceRow with @json.FromJson::{from_json}
