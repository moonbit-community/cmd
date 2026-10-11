///|
test "tree option parsing defaults to current directory" {
  let invocation = parse_arguments([])
  assert_eq(invocation.roots, ["."])
  assert_false(invocation.options.all)
  assert_false(invocation.options.directories_only)
  assert_false(invocation.options.full_path)
  assert_eq(invocation.options.level, None)
  assert_false(invocation.options.no_report)
}

///|
test "tree option parsing keeps the last level and supports clusters" {
  let invocation = parse_arguments([
    "-adf", "-L2", "--level", "3", "--noreport", "root",
  ])
  assert_true(invocation.options.all)
  assert_true(invocation.options.directories_only)
  assert_true(invocation.options.full_path)
  assert_eq(invocation.options.level, Some(3))
  assert_true(invocation.options.no_report)
  assert_eq(invocation.roots, ["root"])
}

///|
test "tree rejects negative levels" {
  try parse_arguments(["-L", "-1"]) catch {
    TreeError(message) => assert_true(message.contains("invalid level"))
  } noraise {
    _ => fail("negative level must be rejected")
  }
}

///|
test "tree rendering uses deterministic branch glyphs" {
  let root : TreeNode = {
    name: ".",
    path: ".",
    kind: Directory,
    children: [
      { name: "a", path: "./a", kind: Directory, children: [], },
      { name: "b", path: "./b", kind: Regular, children: [], },
    ],
  }
  let output = StringBuilder()
  render_node(
    root,
    {
      all: false,
      directories_only: false,
      full_path: false,
      level: None,
      no_report: true,
      help: false,
      version: false,
    },
    "",
    true,
    true,
    output,
  )
  assert_eq(output.to_string(), ".\n├── a\n└── b\n")
}
