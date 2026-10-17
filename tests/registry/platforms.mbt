///|
struct PlatformException {
  source : String
  platforms : Array[String]
  reason : String
} derive(FromJson)

///|
pub extend PlatformException with @json.FromJson::{from_json}

///|
struct PlatformExceptions {
  schema : Int32
  exceptions : Array[PlatformException]
} derive(FromJson)

///|
pub extend PlatformExceptions with @json.FromJson::{from_json}

///|
fn package_backends(config : String) -> Array[String] raise {
  for line in config.split("\n") {
    let parts = line.split("=").collect()
    if parts.length() == 2 && parts[0].trim() == "supported_targets" {
      guard @json.parse(parts[1].trim().to_owned()) is String(targets) else {
        fail("package supported_targets must be an explicit string")
      }
      return ["native", "wasm"].filter(target => {
        targets.split("+").any(value => value == target)
      })
    }
  }
  // An unrestricted package supports both command execution backends.
  ["native", "wasm"]
}

///|
fn validate_platform_exceptions(
  exceptions : PlatformExceptions,
  registry : Registry,
  discovered : ArrayView[String],
) -> Array[String] {
  let failures : Array[String] = []
  if exceptions.schema != 1 {
    failures.push("platform exceptions: unsupported schema")
  }
  let seen : Map[String, Bool] = Map([])
  for item in exceptions.exceptions {
    if seen.contains(item.source) || !discovered.contains(item.source) {
      failures.push(
        "platform exceptions: duplicate or orphan test '\{item.source}'",
      )
    }
    seen[item.source] = true
    if item.reason.trim() == "" ||
      item.platforms.is_empty() ||
      !item.platforms.all(platform => {
        ["linux", "macos", "windows", "posix"].contains(platform)
      }) {
      failures.push(
        "platform exceptions: explicit platforms and reason required '\{item.source}'",
      )
    }
  }
  for
    entry in registry.entries.filter(entry => {
      entry.implementation == "package-test"
    }) {
    let expected = exceptions.exceptions
      .filter(item => item.source == entry.source)
      .get(0)
      .map(item => item.platforms)
      .unwrap_or([])
    if !entry.platforms.all(platform => expected.contains(platform)) ||
      !expected.all(platform => entry.platforms.contains(platform)) {
      failures.push(
        "registry: package platform exception mismatch '\{entry.source}'",
      )
    }
  }
  failures
}
