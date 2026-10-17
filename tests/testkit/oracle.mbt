///|
pub(all) struct OracleSource {
  project : String
  version : String
  sha256 : String
} derive(FromJson, ToJson)

///|
pub(all) struct OracleProfile {
  schema : Int32
  id : String
  profile_version : Int32
  image : String
  base_image_digest : String
  image_digest : String
  versions : String
  versions_sha256 : String
  dockerfile_sha256 : String
  versions_script_sha256 : String
  sources : Array[OracleSource]
} derive(FromJson, ToJson)

///|
pub(all) struct OracleIdentity {
  image : String
  digest : String
  versions : String
  profile_id : String
}

///|
pub(all) struct OracleOptions {
  arguments : Array[String]
  profile_path : String
  seal_digest : String?
}

///|
/// Extract shared oracle options before a runner parses its own arguments.
pub fn parse_oracle_options(
  args : ArrayView[String],
) -> OracleOptions raise Failure {
  let arguments : Array[String] = []
  let mut profile_path = "tests/runner/image/profile.json"
  let mut profile_seen = false
  let mut seal_digest : String? = None
  let mut index = 0
  while index < args.length() {
    let flag = args[index]
    if flag == "--oracle-profile" || flag == "--seal-oracle" {
      guard args.get(index + 1) is Some(value) &&
        value != "" &&
        !value.has_prefix("--") else {
        fail(flag + " requires a value")
      }
      if flag == "--oracle-profile" {
        guard !profile_seen else { fail("duplicate --oracle-profile") }
        profile_seen = true
        profile_path = value
      } else {
        guard seal_digest is None && valid_image_digest(value) else {
          fail("--seal-oracle requires one sha256 image ID")
        }
        seal_digest = Some(value)
      }
      index += 2
    } else {
      arguments.push(flag)
      index += 1
    }
  }
  guard seal_digest is None || arguments.is_empty() else {
    fail("--seal-oracle cannot be combined with execution options")
  }
  { arguments, profile_path, seal_digest, }
}

///|
/// An override may seal the reviewed recipe, but cannot redefine its identity.
pub fn oracle_profile_binding_errors(
  profile : OracleProfile,
  expected : OracleProfile,
  required_profile_ids~ : Array[String] = [],
) -> Array[String] {
  let errors : Array[String] = []
  if profile.schema != expected.schema ||
    profile.id != expected.id ||
    profile.profile_version != expected.profile_version ||
    profile.image != expected.image ||
    profile.base_image_digest != expected.base_image_digest ||
    profile.dockerfile_sha256 != expected.dockerfile_sha256 ||
    profile.versions_script_sha256 != expected.versions_script_sha256 {
    errors.push(
      "oracle profile override does not match the reviewed profile binding",
    )
  }
  if expected.image_digest != "" &&
    (
      profile.image_digest != expected.image_digest ||
      profile.versions != expected.versions ||
      profile.versions_sha256 != expected.versions_sha256
    ) {
    errors.push("oracle profile override changes a sealed identity")
  }
  if required_profile_ids.any(id => id != profile.id) {
    errors.push(
      "oracle profile does not satisfy the selected registry bindings",
    )
  }
  errors
}

///|
fn valid_sha256(value : String) -> Bool {
  value.length() == 64 && value.iter().all(c => c is ('0'..<='9' | 'a'..<='f'))
}

///|
fn valid_image_digest(value : String) -> Bool {
  match value.strip_prefix("sha256:") {
    Some(value) => valid_sha256(value.to_owned())
    None => false
  }
}

///|
pub fn oracle_profile_errors(profile : OracleProfile) -> Array[String] {
  let errors : Array[String] = []
  if profile.schema != 1 || profile.profile_version < 1 || profile.id == "" {
    errors.push("invalid oracle profile identity")
  }
  if profile.image == "" || !valid_image_digest(profile.image_digest) {
    errors.push("oracle profile is unsealed: immutable image digest required")
  }
  if !valid_image_digest(profile.base_image_digest) {
    errors.push("oracle base image digest required")
  }
  if profile.versions == "" ||
    !valid_sha256(profile.versions_sha256) ||
    sha256_text(profile.versions) != profile.versions_sha256 {
    errors.push("oracle version inventory and matching checksum required")
  }
  if !valid_sha256(profile.dockerfile_sha256) ||
    !valid_sha256(profile.versions_script_sha256) {
    errors.push("oracle build recipe checksums required")
  }
  if profile.sources.is_empty() {
    errors.push("oracle upstream source inventory required")
  }
  let projects : Set[String] = Set([])
  for source in profile.sources {
    if source.project == "" ||
      source.version == "" ||
      !valid_sha256(source.sha256) ||
      projects.contains(source.project) {
      errors.push(
        "invalid or duplicate oracle upstream source: " + source.project,
      )
    }
    projects.add(source.project)
  }
  errors
}

///|
pub fn check_oracle_identity(
  profile : OracleProfile,
  digest : String,
  inventory : String,
) -> Array[String] {
  let errors = oracle_profile_errors(profile)
  if digest != profile.image_digest {
    errors.push("oracle image digest mismatch")
  }
  if inventory != profile.versions ||
    sha256_text(inventory) != profile.versions_sha256 {
    errors.push("oracle version inventory mismatch")
  }
  errors
}

///|
pub async fn read_oracle_profile(path : String) -> OracleProfile {
  @json.from_json(@json.parse(@fs.read_file(path).text()))
}

///|
fn recipe_sources(text : String) -> Array[OracleSource] raise {
  let versions : Map[String, String] = Map([])
  let hashes : Map[String, String] = Map([])
  for line in text.split("\n") {
    if line.strip_prefix("ARG ") is Some(arg) {
      let parts = arg.split("=").collect()
      if parts.length() != 2 {
        continue
      }
      if parts[0].strip_suffix("_VERSION") is Some(project) {
        versions[project.to_owned()] = parts[1].to_owned()
      }
      if parts[0].strip_suffix("_SHA256") is Some(project) {
        hashes[project.to_owned()] = parts[1].to_owned()
      }
    }
  }
  let names = versions.keys().collect()
  names.sort()
  names.map(name => {
    guard hashes.get(name) is Some(sha256) else {
      fail("missing upstream checksum: " + name)
    }
    { project: name, version: versions[name], sha256, }
  })
}

///|
/// Seal an explicitly selected immutable image for review. No publication is
/// performed and the image inventory is captured from that exact ID.
pub async fn seal_oracle_profile(
  profile_path : String,
  expected_digest : String,
  expected_profile_path? : String,
) -> Unit {
  let expected_profile = match expected_profile_path {
    Some(path) => Some(read_oracle_profile(path))
    None => None
  }
  seal_oracle_profile_with(
    profile_path,
    expected_digest,
    args => run("docker", args),
    expected_profile?,
  )
}

///|
async fn seal_oracle_profile_with(
  profile_path : String,
  expected_digest : String,
  execute : async (Array[String]) -> RunResult,
  expected_profile? : OracleProfile,
) -> Unit {
  guard valid_image_digest(expected_digest) else {
    fail("expected sha256 image ID")
  }
  let profile = read_oracle_profile(profile_path)
  if expected_profile is Some(expected) {
    let errors = oracle_profile_binding_errors(profile, expected)
    guard errors.is_empty() else { fail(errors.join("; ")) }
  }
  let directory = @path.Path(profile_path).dirname().to_string()
  guard file_digest(directory + "/Dockerfile") == profile.dockerfile_sha256 &&
    file_digest(directory + "/versions.sh") == profile.versions_script_sha256 else {
    fail("review build recipe checksums before sealing")
  }
  let inspected = execute([
    "image", "inspect", "--format={{.Id}}", expected_digest,
  ])
  guard inspected.status == 0 &&
    @utf8.decode(inspected.stdout).trim() == expected_digest[:] else {
    fail("expected immutable oracle image is unavailable")
  }
  let observed = execute([
    "run", "--rm", expected_digest, "/usr/local/bin/versions.sh",
  ])
  guard observed.status == 0 else { fail("oracle version inventory failed") }
  let versions = @utf8.decode(observed.stdout)
  let profile_with_identity = {
    ..profile,
    sources: recipe_sources(@fs.read_file(directory + "/Dockerfile").text()),
    image_digest: expected_digest,
    versions,
    versions_sha256: sha256_text(versions),
  }
  let errors = oracle_profile_errors(profile_with_identity)
  guard errors.is_empty() else { fail(errors.join("; ")) }
  if expected_profile is Some(expected) {
    let errors = oracle_profile_binding_errors(profile_with_identity, expected)
    guard errors.is_empty() else { fail(errors.join("; ")) }
  }
  @fs.write_file(
    profile_path,
    canonical_json(ToJson::to_json(profile_with_identity)) + "\n",
  )
}

///|
/// Verify the reviewed profile before launching any comparison. All later
/// execution uses the returned immutable ID, so a tag update cannot change
/// the oracle between preflight and a case.
pub async fn verify_oracle_image(
  image : String,
  docker_path~ : String = "docker",
  profile_path~ : String = "tests/runner/image/profile.json",
  expected_profile_path? : String,
  required_profile_ids~ : Array[String] = [],
) -> OracleIdentity {
  let expected_profile = match expected_profile_path {
    Some(path) => Some(read_oracle_profile(path))
    None => None
  }
  verify_oracle_image_with(
    image,
    profile_path,
    args => run(docker_path, args),
    expected_profile?,
    required_profile_ids~,
  )
}

///|
// The command boundary is injectable for deterministic lifecycle failures.
// Production verification always uses the real process runner above.
async fn verify_oracle_image_with(
  image : String,
  profile_path : String,
  execute : async (Array[String]) -> RunResult,
  expected_profile? : OracleProfile,
  required_profile_ids~ : Array[String] = [],
) -> OracleIdentity {
  let profile = read_oracle_profile(profile_path)
  let errors = oracle_profile_errors(profile)
  guard errors.is_empty() else { fail(errors.join("; ")) }
  if expected_profile is Some(expected) {
    let binding_errors = oracle_profile_binding_errors(
      profile,
      expected,
      required_profile_ids~,
    )
    guard binding_errors.is_empty() else { fail(binding_errors.join("; ")) }
  }
  guard image == profile.image || image == profile.image_digest else {
    fail("oracle image is not bound to the selected profile")
  }
  let directory = @path.Path(profile_path).dirname().to_string()
  guard file_digest(directory + "/Dockerfile") == profile.dockerfile_sha256 &&
    file_digest(directory + "/versions.sh") == profile.versions_script_sha256 else {
    fail("oracle build recipe checksum mismatch")
  }
  if expected_profile is Some(_) {
    let sources = recipe_sources(
      @fs.read_file(directory + "/Dockerfile").text(),
    )
    guard canonical_json(ToJson::to_json(sources)) ==
      canonical_json(ToJson::to_json(profile.sources)) else {
      fail("oracle source inventory does not match the reviewed recipe")
    }
  }
  let inspected = execute(["image", "inspect", "--format={{.Id}}", image]) catch {
    error => fail("oracle image inspect unavailable: \{error}")
  }
  guard inspected.status == 0 else {
    fail("oracle image inspect failed: " + @utf8.decode(inspected.stderr))
  }
  let digest = @utf8.decode(inspected.stdout).trim().to_owned()
  guard digest == profile.image_digest else {
    fail("oracle image digest mismatch")
  }
  let versions = execute(["run", "--rm", digest, "/usr/local/bin/versions.sh"]) catch {
    error => fail("oracle inventory unavailable: \{error}")
  }
  guard versions.status == 0 else {
    fail("oracle inventory failed: " + @utf8.decode(versions.stderr))
  }
  let inventory = @utf8.decode(versions.stdout)
  let errors = check_oracle_identity(profile, digest, inventory)
  guard errors.is_empty() else { fail(errors.join("; ")) }
  { image: digest, digest, versions: inventory, profile_id: profile.id, }
}

///|
pub extend OracleSource with @json.FromJson::{from_json}

///|
pub extend OracleSource with ToJson::{to_json}

///|
pub extend OracleProfile with @json.FromJson::{from_json}

///|
pub extend OracleProfile with ToJson::{to_json}
