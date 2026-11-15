///|
test "directory headers quote operands and retain original option spelling" {
  assert_eq(
    command_prefix([
      "-rN", "--label", "old file", "--label=new", "left", "right",
    ]),
    "diff -rN --label 'old file' --label=new",
  )
  assert_eq(quoted("a'b"), "'a'\\''b'")
  assert_eq(directory_operand("left space/a file"), "\"left space/a file\"")
  assert_eq(directory_operand("a\tb"), "\"a\\tb\"")
  assert_eq(directory_operand("caf\u00e9"), "\"caf\\303\\251\"")
  assert_eq(path_parts("left/name"), ("left", "name"))
}

///|
test "diagnostic paths use GNU C shell escaping" {
  assert_eq(diagnostic_path("plain/name"), "plain/name")
  assert_eq(diagnostic_path("missing left"), "'missing left'")
  assert_eq(diagnostic_path("missing'quote"), "\"missing'quote\"")
  assert_eq(
    diagnostic_path("missing'quote=complex"),
    "'missing'\\''quote=complex'",
  )
  assert_eq(diagnostic_path("tab\there"), "'tab'$'\\t''here'")
  assert_eq(diagnostic_path("line\nhere"), "'line'$'\\n''here'")
  assert_eq(diagnostic_path("é"), "''$'\\303\\251'")
  assert_eq(diagnostic_path("#missing"), "'#missing'")
  assert_eq(directory_operand("has space"), "\"has space\"")
}
