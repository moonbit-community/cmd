///|
async fn check_chmod_policy(root : String, failures : Array[String]) -> Unit {
  let fixture_rel = "tests/fixtures/policy/chmod-runner-fixture"
  let fixture = root_path(root, fixture_rel)
  @fs.write_file(fixture, b"policy-mode\n")
  defer (@fs.remove(fixture) catch { _ => () })
  let result = moon_run(root, "read-workspace.json", "chmod", [
    "600", fixture_rel,
  ]) catch {
    err => {
      failures.push("chmod: policy invocation failed: \{err}")
      return
    }
  }
  record(
    result.status != 0,
    "chmod: read-only policy must deny mutation",
    failures,
  )
  record(
    @fs.read_file(fixture).text() == "policy-mode\n",
    "chmod: denial changed fixture contents",
    failures,
  )
  if !@platform.permission_mutation_supported() {
    record(
      @harness.contains_bytes(result.stderr, "unsupported capability"),
      "chmod: Windows must return stable unsupported capability",
      failures,
    )
  }
}
