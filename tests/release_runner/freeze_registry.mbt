///|
/// These endpoints follow moon's RegistryClient::module_manifest and
/// RegistryEndpoints::package_archive. They are deliberately fixed, so a
/// local receipt or environment override cannot select a substitute registry.
fn freeze_registry_urls(
  name : String,
  version : String,
) -> (String, String) raise Failure {
  let parts = name.split("/").collect()
  guard parts.length() == 2 &&
    parts[0] == "cli" &&
    !parts[1].is_empty() &&
    parts[1].iter().all(char => char is ('a'..<='z' | '0'..<='9' | '-' | '_')) &&
    valid_version(version) else {
    fail("invalid official registry coordinate: " + name + "@" + version)
  }
  (
    "https://mooncakes.io/api/v0/manifest/" + name + "@" + version,
    "https://download.mooncakes.io/user/" + name + "/" + version + ".zip",
  )
}

///|
fn live_registry_checksum(
  value : Json,
  name : String,
  version : String,
) -> String raise Failure {
  guard value
    is {
      "module": String(module_name),
      "version": String(actual_version),
      "yanked": False,
      "metadata": {
        "name": String(metadata_name),
        "version": String(metadata_version),
        "checksum": String(checksum),
        ..
      },
      ..
    } &&
    module_name == name &&
    actual_version == version &&
    metadata_name == name &&
    metadata_version == version &&
    sha256_identity(checksum) else {
    fail(
      "live registry did not return the exact non-yanked checksummed release",
    )
  }
  checksum
}

///|
async fn fetch_official_registry(url : String) -> (Int32, Bytes) {
  @async.with_timeout(30000, () => {
    // async/http uses system-root TLS validation and does not follow redirects.
    let (response, body) = @http.get(url)
    (response.code, body.binary())
  })
}

///|
async fn verify_live_registry_release(
  name : String,
  version : String,
  retained_index : String,
) -> Json {
  verify_live_registry_release_with(
    name, version, retained_index, fetch_official_registry,
  )
}

///|
// Deterministic transport injection is private to harness regression tests.
async fn verify_live_registry_release_with(
  name : String,
  version : String,
  retained_index : String,
  fetch : async (String) -> (Int32, Bytes),
) -> Json {
  let (manifest_url, archive_url) = freeze_registry_urls(name, version)
  let (manifest_status, response) = fetch(manifest_url)
  guard manifest_status == 200 else {
    fail("live registry manifest request failed")
  }
  let value = @json.parse(@utf8.decode(response))
  let checksum = live_registry_checksum(value, name, version)
  guard registry_response_checksum(retained_index, name, version) ==
    Some(checksum) else {
    fail("retained registry receipt differs from the live exact release")
  }
  let (archive_status, archive) = fetch(archive_url)
  guard archive_status == 200 && @testkit.sha256_bytes(archive) == checksum else {
    fail("official source archive checksum mismatch")
  }
  {
    "schema": 1,
    "coordinate": Json(name + "@" + version),
    "manifest_url": Json(manifest_url),
    "manifest_status": Json(manifest_status),
    "manifest_response_sha256": Json(@testkit.sha256_bytes(response)),
    "manifest_response": value,
    "archive_url": Json(archive_url),
    "archive_status": Json(archive_status),
    "archive_sha256": Json(checksum),
  }
}
