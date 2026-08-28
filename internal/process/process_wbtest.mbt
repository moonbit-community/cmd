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
