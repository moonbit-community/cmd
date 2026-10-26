///|
test "command launchers preserve arguments and exact child coordinates" {
  defer configure_commands(Map([]), "moonrun")
  configure_commands(Map([]), "/runtime/moonrun")
  assert_eq(command_program(), "/runtime/moonrun")
  assert_eq(command_args("/artifacts", "echo", ["--", "a b", "中文"]), [
    wasm_path("/artifacts", "echo"),
    "--",
    "--",
    "a b",
    "中文",
  ])
  configure_commands(
    { "find": "cli/find@0.2.3", "printf": "cli/printf@0.1.3" },
    "/runtime/moonx",
  )
  assert_eq(command_line("unused", "printf", ["%s", "a b"]), [
    "/runtime/moonx", "cli/printf@0.1.3", "--", "%s", "a b",
  ])
  assert_eq(command_args("unused", "find", ["."], policy="/policy.json"), [
    "--experimental-policy", "/policy.json", "cli/find@0.2.3", "--", ".",
  ])
  assert_eq(command_args("unused", "printf", ["--", "-r"]), [
    "cli/printf@0.1.3", "--", "--", "-r",
  ])
  assert_eq(command_version("find"), Some("0.2.3"))
  assert_false(command_available("timeout"))
  try command_args("/artifacts", "timeout", []) catch {
    _ => ()
  } noraise {
    _ => fail("missing coordinate fell back to workspace")
  }
}
