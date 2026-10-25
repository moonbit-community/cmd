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
    TreeError(message) => assert_true(message.contains("Invalid level"))
  } noraise {
    _ => fail("negative level must be rejected")
  }
}

///|
async test "tree rendering uses deterministic C locale branches" {
  let root : TreeNode = {
    name: ".",
    path: ".",
    kind: Directory,
    children: [
      {
        name: "a",
        path: "./a",
        kind: Directory,
        children: [],
        size: None,
        note: None,
        limited: false,
      },
      {
        name: "b",
        path: "./b",
        kind: Regular,
        children: [],
        size: None,
        note: None,
        limited: false,
      },
    ],
    size: None,
    note: None,
    limited: false,
  }
  let bytes = @buffer.Buffer()
  let output = TreeOutput::new(chunk => bytes.write_bytes(chunk[:]))
  render_node(
    root,
    parse_arguments(["--noreport"]).options,
    "",
    true,
    true,
    output,
  )
  output.flush()
  assert_eq(@utf8.decode(bytes.to_bytes()), ".\n|-- a\n`-- b\n")
}
