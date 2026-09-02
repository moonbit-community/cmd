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
test "shared command launch statuses preserve upstream shell convention" {
  assert_eq(launch_failure_status(CommandNotFound), 127)
  assert_eq(launch_failure_status(CommandNotInvokable), 126)
}

///|
test "native-compatible environment preserves ordinary variables" {
  let source : Map[String, String] = {
    "PATH": "/bin",
    "HOME": "/home/test",
    "SECRET_TOKEN": "ordinary-parent-value",
    "LC_ALL": "zh_CN.UTF-8",
  }
  let inherited = environment_with_policy(source, NativeCompatible)
  assert_eq(inherited.get("PATH"), Some("/bin"))
  assert_eq(inherited.get("HOME"), Some("/home/test"))
  assert_eq(inherited.get("SECRET_TOKEN"), Some("ordinary-parent-value"))
  assert_eq(inherited.get("LC_ALL"), Some("zh_CN.UTF-8"))
}

///|
test "Wasm policy environment remains allowlisted and deterministic" {
  let source : Map[String, String] = {
    "PATH": "/bin",
    "HOME": "/home/test",
    "SECRET_TOKEN": "ordinary-parent-value",
    "LC_ALL": "zh_CN.UTF-8",
  }
  let filtered = environment_with_policy(source, WasmRestricted)
  assert_eq(filtered.get("PATH"), Some("/bin"))
  assert_eq(filtered.get("HOME"), Some("/home/test"))
  assert_eq(filtered.get("SECRET_TOKEN"), None)
  assert_eq(filtered.get("LC_ALL"), Some("C"))
  assert_eq(filtered.get("LANG"), Some("C"))
  assert_true(allowed_environment_name("Path", true))
  assert_true(allowed_environment_name("SystemRoot", true))
  assert_false(allowed_environment_name("SystemRoot", false))
  assert_false(allowed_environment_name("SECRET_TOKEN", true))
}
