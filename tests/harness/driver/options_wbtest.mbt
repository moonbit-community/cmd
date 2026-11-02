///|
test "driver options reject retired modes and empty or unknown selections" {
  for
    args in [
      ["--backend", "wasm"],
      ["--stress"],
      ["--suite", "smoke"],
      ["--suite", "differential"],
      ["--jobs", "0"],
      ["--manifest"],
    ] {
    try
      parse_driver_options(
        args, "/workspace", "/workspace/tests/cases/manifest.json",
      )
    catch {
      _ => ()
    } noraise {
      _ => fail("invalid driver invocation accepted")
    }
  }
  let options = parse_driver_options(
    ["--suite", "all", "--command", "cat", "--jobs", "2"],
    "/workspace",
    "/workspace/tests/cases/manifest.json",
  )
  assert_true(options.suites.contains("oracle"))
  assert_true(options.suites.contains("contract"))
  assert_eq(options.commands, ["cat"])
  assert_eq(options.jobs, 2)
}
