///|
priv struct CiFileReceipt {
  path : String
  sha256 : String
} derive(FromJson, ToJson)

///|
priv struct CiPlatformReceipt {
  schema : Int32
  context : CiContext
  platform : String
  files : Array[CiFileReceipt]
} derive(FromJson, ToJson)

///|
fn ci_report_roles(
  platform : String,
  published~ : Bool = false,
) -> Array[String] {
  let roles = [
    "metadata-pair", "compat-native", "contract-native", "contract-wasm", "scenarios-native",
    "scenarios-wasm", "backend-pair", "package-pair", "package-native-only", "policy-wasm",
    "stress-native",
  ]
  if platform == "linux" {
    roles.append(["gnu-native", "oracle-native", "oracle-wasm"])
    if published {
      roles.push("published-differential")
    }
  }
  roles
}

///|
fn ci_receipt_paths(
  platform : String,
  published~ : Bool = false,
) -> Array[String] {
  let paths : Array[String] = ["scope-shadow.json"]
  for role in ci_report_roles(platform, published~) {
    paths.append([role + "/summary.jsonl", role + "/run-metadata.json"])
    if role.has_prefix("package-") {
      paths.push(role + "/source-corpus.json")
    }
  }
  if platform == "linux" {
    paths.append([
      "oracle-profile/profile.json", "oracle-profile/Dockerfile", "oracle-profile/versions.sh",
    ])
    if published {
      paths.append([
        "published-inputs/manifest.json", "published-inputs/corpus.json", "published-inputs/registry.json",
        "published-inputs/provenance.json",
      ])
    }
  }
  sorted_unique(paths)
}

///|
fn ci_bundle_errors(
  metadata : AuditRunMetadata,
  context : CiContext,
  platform : String,
) -> Array[String] {
  let failures = @testkit.run_metadata_errors(metadata)
  if metadata.git_revision != context.head ||
    metadata.git_dirty != "false" ||
    metadata.reproducibility_status != "complete" ||
    metadata.platform != platform {
    failures.push(
      "CI report is stale, dirty, incomplete or from another platform",
    )
  }
  failures
}

///|
async fn ci_check_bundle_inputs(
  metadata : AuditRunMetadata,
  role : String,
  directory : String,
  frozen~ : CiFrozenBinding? = None,
) -> Unit {
  if role == "published-differential" {
    guard frozen is Some(binding) &&
      ci_frozen_metadata_matches(metadata, binding) else {
      fail("published report does not match the validated frozen publication")
    }
    return
  }
  let registry_hash = @testkit.manifest_digest("tests/registry/registry.json")
  let manifest_path = if role == "metadata-pair" || role.has_prefix("package-") {
    "tests/registry/registry.json"
  } else {
    "tests/fixtures/runner/cases.json"
  }
  let corpus_path = if role.has_prefix("package-") {
    directory + "/" + role + "/source-corpus.json"
  } else {
    manifest_path
  }
  guard metadata.registry_hash == registry_hash &&
    metadata.manifest_hash == @testkit.manifest_digest(manifest_path) &&
    metadata.case_corpus_hash == @testkit.manifest_digest(corpus_path) else {
    fail("CI report fingerprints do not match the current inputs: " + role)
  }
}

///|
async fn ci_stamp(context : CiContext, directory : String) -> Unit {
  let platform = @testkit.host_platform()
  guard ["linux", "macos", "windows"].contains(platform) else {
    fail("unsupported CI platform")
  }
  let intent = ci_scope_preflight(context)
  ci_write_scope_shadow(context, directory, intent)
  let published = ci_published_enabled(context, intent)
  let frozen = if platform == "linux" && published {
    Some(ci_frozen_binding())
  } else {
    None
  }
  if frozen is Some(_) {
    @fs.mkdir(directory + "/published-inputs", recursive=true)
    for
      (name, suffix) in [
        ("manifest", ""),
        ("corpus", ".cases.json"),
        ("registry", ".registry.json"),
        ("provenance", ".provenance.json"),
      ] {
      @fs.write_file(
        directory + "/published-inputs/" + name + ".json",
        @fs.read_file("tests/release_runner/current/published.json" + suffix).binary(),
        create_mode=CreateNew,
      )
    }
  }
  let files : Array[CiFileReceipt] = []
  for path in ci_receipt_paths(platform, published~) {
    let sha256 = @testkit.file_digest(directory + "/" + path)
    guard valid_sha256(sha256) else {
      fail("missing CI evidence file: " + path)
    }
    files.push({ path, sha256, })
  }
  for role in ci_report_roles(platform, published~) {
    let metadata : AuditRunMetadata = parse_json_file(
      directory + "/" + role + "/run-metadata.json",
    )
    let errors = ci_bundle_errors(metadata, context, platform)
    guard errors.is_empty() else { fail(role + ": " + errors.join("; ")) }
    ci_check_bundle_inputs(metadata, role, directory, frozen~)
  }
  let receipt : CiPlatformReceipt = { schema: 1, context, platform, files, }
  @fs.write_file(
    directory + "/ci-receipt.json",
    @testkit.canonical_json(ToJson::to_json(receipt)) + "\n",
    create_mode=@fs.CreateNew,
  )
}

///|
async fn ci_verified_reports(
  context : CiContext,
  directory : String,
  intent : @scope.ScopeIntent?,
) -> (Array[String], Array[String], Array[String], CiFrozenBinding?) {
  let metadata_paths : Array[String] = []
  let corpora = [
    "tests/fixtures/runner/cases.json", "tests/registry/registry.json",
  ]
  let profiles : Array[String] = []
  let published = ci_published_enabled(context, intent)
  let frozen = if published { Some(ci_frozen_binding()) } else { None }
  for
    (platform, host) in [
      ("linux", "ubuntu-24.04"),
      ("macos", "macos-15"),
      ("windows", "windows-2025"),
    ] {
    let root = directory + "/cmd-test-reports-" + host
    let receipt : CiPlatformReceipt = parse_json_file(root + "/ci-receipt.json")
    guard receipt.schema == 1 && receipt.platform == platform else {
      fail("CI receipt schema or platform mismatch: " + root)
    }
    let errors = ci_receipt_context_errors(receipt.context, context)
    guard errors.is_empty() else { fail(errors.join("; ")) }
    ci_verify_scope_shadow(context, root, platform, intent)
    let expected = ci_receipt_paths(platform, published~)
    let actual = receipt.files.map(file => file.path)
    guard actual.length() == expected.length() &&
      sorted_unique(actual) == expected else {
      fail(
        "CI receipt has missing, duplicate or unexpected evidence paths: " +
        root,
      )
    }
    for file in receipt.files {
      guard valid_sha256(file.sha256) &&
        @testkit.file_digest(root + "/" + file.path) == file.sha256 else {
        fail("CI evidence checksum differs from platform receipt: " + file.path)
      }
    }
    if platform == "linux" && published {
      for
        (name, suffix) in [
          ("manifest", ""),
          ("corpus", ".cases.json"),
          ("registry", ".registry.json"),
          ("provenance", ".provenance.json"),
        ] {
        guard @testkit.file_digest(root + "/published-inputs/" + name + ".json") ==
          @testkit.file_digest(
            "tests/release_runner/current/published.json" + suffix,
          ) else {
          fail(
            "published input snapshot differs from the validated checkout: " +
            name,
          )
        }
      }
    }
    for role in ci_report_roles(platform, published~) {
      let metadata_path = root + "/" + role + "/run-metadata.json"
      let metadata : AuditRunMetadata = parse_json_file(metadata_path)
      let errors = ci_bundle_errors(metadata, context, platform)
      guard errors.is_empty() else {
        fail(metadata_path + ": " + errors.join("; "))
      }
      ci_check_bundle_inputs(metadata, role, root, frozen~)
      metadata_paths.push(metadata_path)
      if role.has_prefix("package-") {
        corpora.push(root + "/" + role + "/source-corpus.json")
      }
    }
    if platform == "linux" {
      profiles.push(root + "/oracle-profile/profile.json")
    }
  }
  (metadata_paths, corpora, profiles, frozen)
}
