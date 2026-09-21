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
test "default environment preserves host values and locale" {
  let name = "CMD_ENVIRONMENT_REGRESSION"
  let previous = @env.get_env_var(name)
  let locale = @env.get_env_var("LC_ALL")
  defer {
    match previous {
      Some(value) => @env.set_env_var(name, value)
      None => @env.unset_env_var(name)
    }
    match locale {
      Some(value) => @env.set_env_var("LC_ALL", value)
      None => @env.unset_env_var("LC_ALL")
    }
  }
  @env.set_env_var(name, "preserved")
  @env.set_env_var("LC_ALL", "zh_CN.UTF-8")
  let inherited = default_environment()
  assert_eq(inherited.get(name), Some("preserved"))
  assert_eq(inherited.get("LC_ALL"), Some("zh_CN.UTF-8"))
}
