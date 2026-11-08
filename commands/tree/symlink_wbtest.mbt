///|
async test "tree links are leaves even for dangling and cyclic targets" {
  let root = @fs.tmpdir(prefix="mooncmd-tree-links-")
  defer @fs.rmdir(root, recursive=true)
  @fs.write_file(root + "/README.mbt.md", "documentation")
  @fs.mkdir(root + "/sub")
  @fs.write_file(root + "/sub/child", "retained")
  for
    (name, target) in [
      ("README.md", "README.mbt.md"),
      ("broken", "missing"),
      ("cycle", "cycle"),
      ("directory-link", "sub"),
    ] {
    @fs.symlink(
      root + "/" + name,
      target=root + "/" + target,
      force_symlink=true,
    )
  }
  let options = parse_arguments([]).options
  let node = collect_node(root, "root", 0, options)
  assert_eq(node.children.map(child => child.name), [
    "README.mbt.md", "README.md", "broken", "cycle", "directory-link", "sub",
  ])
  for child in node.children {
    if child.kind == SymLink {
      assert_eq(child.children.length(), 0)
      assert_eq(child.size, None)
      assert_eq(child.note, None)
    }
  }
  let counts = node_counts(node, root=true)
  assert_eq((counts.directories, counts.files), (2, 6))
  let dirs = collect_node(root, "root", 0, parse_arguments(["-d"]).options)
  assert_eq(dirs.children.map(child => child.name), ["sub"])
  let pruned = collect_node(
    root,
    "root",
    0,
    parse_arguments(["--prune", "-P", "README.md"]).options,
  )
  assert_eq(pruned.children.map(child => child.name), ["README.md"])
  assert_eq(@fs.read_file(root + "/sub/child").text(), "retained")
  for name in ["README.md", "broken", "cycle", "directory-link"] {
    assert_true(@fs.kind(root + "/" + name, follow_symlink=false) == SymLink)
  }
}

///|
async test "tree link sizes reject without measuring or reading referents" {
  let root = @fs.tmpdir(prefix="mooncmd-tree-link-size-")
  defer @fs.rmdir(root, recursive=true)
  @fs.symlink(root + "/broken", target=root + "/missing", force_symlink=true)
  for flag in ["-s", "-h", "--si", "--du"] {
    try
      collect_node(
        root + "/broken",
        "broken",
        0,
        parse_arguments([flag]).options,
      )
    catch {
      TreeError(message) =>
        assert_eq(
          message,
          "symbolic-link sizes require unavailable public metadata: '" +
          root +
          "/broken'",
        )
    } noraise {
      _ => fail("link size must not be fabricated")
    }
  }
  let leaf = collect_node(
    root + "/broken",
    "broken",
    0,
    parse_arguments([]).options,
  )
  assert_true(leaf.kind == SymLink)
  assert_eq(leaf.note, None)
  assert_eq(leaf.children.length(), 0)
}

///|
test "tree trims operand separators without turning Windows drive roots into relative paths" {
  for
    root in [
      "C:\\", "C:/", "\\\\?\\C:\\", "\\\\.\\C:\\", "\\\\?\\Volume{123}\\", "\\\\host\\share\\",
      "\\\\?\\UNC\\host\\share\\",
    ] {
    assert_eq(windows_root_length(root.iter().collect()), root.length())
    assert_eq(
      windows_root_length((root + "child\\").iter().collect()),
      root.length(),
    )
    if @async.platform is Windows {
      assert_eq(trim_trailing_slashes(root), root)
    }
  }
  assert_eq(trim_trailing_slashes("link///"), "link")
  assert_eq(trim_trailing_slashes("/"), "/")
  if @async.platform is Windows {
    assert_eq(trim_trailing_slashes("link\\\\"), "link")
    assert_eq(trim_trailing_slashes("C:\\"), "C:\\")
    assert_eq(trim_trailing_slashes("C:/"), "C:/")
  } else {
    assert_eq(trim_trailing_slashes("link\\"), "link\\")
  }
}

///|
async test "tree link representations preserve type name escaping and link color" {
  let node : TreeNode = {
    name: "a<&",
    path: "./a<&",
    kind: SymLink,
    children: [],
    size: None,
    note: None,
    limited: false,
  }
  let options = parse_arguments(["--noreport"]).options
  let bytes = @buffer.Buffer()
  let output = TreeOutput::new(chunk => bytes.write_bytes(chunk[:]))
  render_json([node], options, node_counts(node), output)
  output.flush()
  assert_eq(
    @utf8.decode(bytes.to_bytes()),
    "[\n  {\"type\":\"link\",\"name\":\"./a<&\"}\n\n]\n",
  )
  let html_options = { ..options, html_colors: true, }
  assert_eq(
    html_node_line(
      node, html_options, "https://example.invalid/", ".", "", true, false,
    ),
    "\t`-- <a class=\"LINK\" href=\"https://example.invalid/./a%3C%26\">a&lt;&amp;</a><br>\n",
  )
  let colors : TreeColors = { codes: Map([("ln", "36")]), suffixes: [], }
  require_color_kind(SymLink, colors)
  assert_eq(tree_color(SymLink, "a<&", colors), Some("36"))
  colors.codes["ln"] = "target"
  try require_color_kind(SymLink, colors) catch {
    TreeError(message) =>
      assert_eq(
        message, "TREE_COLORS ln=target requires following symbolic links",
      )
  } noraise {
    _ => fail("target color must not pretend to inspect the referent")
  }
}
