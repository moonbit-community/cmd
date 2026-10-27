///|
test "help describes the MoonX implementation rather than upstream capabilities" {
  for help in [generate_help_short(), generate_help_long()] {
    let help = help
      .split("\n")
      .map(line => line.trim().to_owned())
      .collect()
      .join(" ")
    assert_true(help.has_prefix("Usage: rg"))
    assert_true(help.contains("for MoonX"))
    assert_true(help.contains("explicit paths"))
    assert_true(help.contains("not memory maps"))
    assert_true(help.contains("one thread"))
    assert_true(help.contains("Creation-time sorting"))
    assert_true(help.contains("terminal detection is unavailable"))
    assert_true(!help.contains("choose the thread count using"))
    assert_true(!help.contains("search using memory maps when possible"))
  }
  assert_eq(generate_version_short(), "rg 0.1.0")
}
