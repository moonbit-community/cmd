///|
test "child context is explicit" {
  let context : ExecutionContext = {
    cwd: "workspace",
    env: { "ONLY": "value" },
  }
  let spec = child("echo", ["hello"], context~)
  assert_eq(spec.program, "echo")
  assert_eq(spec.args, ["hello"])
  assert_eq(spec.context.cwd, "workspace")
  assert_eq(spec.context.env.get("ONLY"), Some("value"))
}

///|
test "default environment removes unrelated host variables" {
  let source : Map[String, String] = {
    "PATH": "/bin",
    "HOME": "/home/test",
    "SECRET_TOKEN": "must-not-cross-boundary",
    "LC_ALL": "zh_CN.UTF-8",
  }
  let filtered = sanitize_environment(source)
  assert_eq(filtered.get("PATH"), Some("/bin"))
  assert_eq(filtered.get("HOME"), Some("/home/test"))
  assert_eq(filtered.get("SECRET_TOKEN"), None)
  assert_eq(filtered.get("LC_ALL"), Some("C"))
  assert_eq(filtered.get("LANG"), Some("C"))
  assert_true(allowed_environment_name("Path", true))
  assert_true(allowed_environment_name("SystemRoot", true))
  assert_false(allowed_environment_name("SECRET_TOKEN", true))
}
