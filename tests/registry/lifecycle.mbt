///|
struct LifecycleCase {
  id : String
  status : String
  test_ref : String
  proves : Array[String]
  limitations : Array[String]
} derive(FromJson)

///|
pub extend LifecycleCase with @json.FromJson::{from_json}

///|
struct LifecycleRegistry {
  schema : Int32
  cases : Array[LifecycleCase]
} derive(FromJson)

///|
pub extend LifecycleRegistry with @json.FromJson::{from_json}

///|
fn validate_lifecycle_bindings(
  lifecycle : LifecycleRegistry,
  registry : Registry,
  discovered : ArrayView[String],
) -> Array[String] {
  let failures : Array[String] = []
  if lifecycle.schema != 1 {
    failures.push("lifecycle: unsupported schema")
  }
  let seen : Map[String, Bool] = Map([])
  for item in lifecycle.cases {
    if item.id.trim() == "" || seen.contains(item.id) {
      failures.push("lifecycle: empty or duplicate ID '\{item.id}'")
    }
    seen[item.id] = true
    if !["proven", "deferred"].contains(item.status) {
      failures.push("lifecycle: invalid status '\{item.id}'")
    }
    if item.status == "proven" &&
      (item.test_ref == "" || item.proves.is_empty()) {
      failures.push(
        "lifecycle: proven case requires a test and assertions '\{item.id}'",
      )
    }
    if item.status == "deferred" && item.limitations.is_empty() {
      failures.push(
        "lifecycle: deferred case requires a limitation '\{item.id}'",
      )
    }
    if item.proves.any(value => value.trim() == "") ||
      item.limitations.any(value => value.trim() == "") {
      failures.push("lifecycle: blank assertion or limitation '\{item.id}'")
    }
    if item.test_ref != "" {
      if !discovered.contains(item.test_ref) {
        failures.push("lifecycle: orphan test reference '\{item.test_ref}'")
      }
      if !registry.entries.any(entry => {
          entry.implementation == "package-test" &&
          entry.source == item.test_ref
        }) {
        failures.push(
          "lifecycle: test reference is not registered '\{item.test_ref}'",
        )
      }
    }
  }
  failures
}
