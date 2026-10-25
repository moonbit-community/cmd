///|
test "tree patterns preserve C byte ranges alternatives directory suffixes and malformed reachability" {
  let accepts = (pattern : String, name : String) => {
    matches_any([compile_pattern(pattern, false)], name, false, false)
  }
  assert_true(accepts("[ab].*", "a.txt"))
  assert_false(accepts("[^a]*", "a.txt"))
  assert_true(accepts("[!a]*", "a.txt"))
  assert_false(accepts("[!a]*", "b.txt"))
  assert_true(accepts("a.txt|b.log", "b.log"))
  assert_true(accepts("|bad", "anything"))
  assert_false(accepts("bad[", "different"))
  assert_true(accepts("bad[", "badx"))
  assert_true(matches_any([compile_pattern("sub/", false)], "sub", true, false))
  assert_false(accepts("sub/", "sub"))
  assert_true(accepts("keep/**", "keep/inner"))
  assert_true(
    matches_any([compile_pattern("*.TXT", true)], "z.txt", false, true),
  )
}

///|
async test "tree all never descends dot entries and prunes only selected empty branches" {
  let root = @fs.tmpdir(prefix="mooncmd-tree-options")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  @fs.write_file(root + "/.hidden", "h")
  @fs.mkdir(root + "/empty")
  @fs.mkdir(root + "/sub")
  @fs.write_file(root + "/sub/z.txt", "zz")
  let all = collect_node(root, "root", 0, parse_arguments(["-aL1"]).options)
  assert_eq(all.children.map(node => node.name), [".hidden", "empty", "sub"])
  let pruned = collect_node(
    root,
    "root",
    0,
    parse_arguments(["--prune", "-P", "*.txt"]).options,
  )
  assert_eq(pruned.children.map(node => node.name), ["sub"])
  let counts = node_counts(pruned, root=true, prune=true)
  assert_eq((counts.directories, counts.files), (2, 1))
  let limited = collect_node(
    root,
    "root",
    0,
    parse_arguments(["--filelimit", "1"]).options,
  )
  assert_true(limited.limited)
  assert_eq(limited.children.length(), 0)
  assert_eq(limited.note, Some("2 entries exceeds filelimit, not opening dir"))
}

///|
async test "structured tree escapes names title and URL bytes without ANSI color" {
  let leaf : TreeNode = {
    name: "a\"<&\n",
    path: "./a\"<&\n",
    kind: Regular,
    children: [],
    size: None,
    note: None,
    limited: false,
  }
  let root : TreeNode = {
    name: ".",
    path: ".",
    kind: Directory,
    children: [leaf],
    size: None,
    note: None,
    limited: false,
  }
  let options = parse_arguments(["-JC"]).options
  let bytes = @buffer.Buffer()
  let out = TreeOutput::new(chunk => bytes.write_bytes(chunk[:]))
  render_json([root], options, node_counts(root, root=true), out)
  out.flush()
  let text = @utf8.decode(bytes.to_bytes())
  let value = @json.parse(text)
  assert_true(value is Array(_))
  assert_false(text.contains("\u001b"))
  assert_true(text.contains("a\\\"<&\\n"))
  assert_eq(html_escape("A<&\"title"), "A&lt;&amp;&quot;title")
  assert_eq(url_path("a b\"<&/é"), "a%20b%22%3C%26/%C3%A9")
  let html_bytes = @buffer.Buffer()
  let html = TreeOutput::new(chunk => html_bytes.write_bytes(chunk[:]))
  let html_options = parse_arguments([
      "-H", "https://example.invalid/?q=\"&", "-T", "<script>",
    ]).options
  render_html(
    [root],
    html_options,
    "https://example.invalid/?q=\"&",
    node_counts(root, root=true),
    html,
  )
  html.flush()
  let rendered = @utf8.decode(html_bytes.to_bytes())
  assert_false(rendered.contains("<script>"))
  assert_true(rendered.contains("<title>&lt;script&gt;</title>"))
  assert_true(rendered.contains("?q=&quot;&amp;./"))
}

///|
async test "all tree formats batch output without retaining the complete rendered listing" {
  let leaf : TreeNode = {
    name: "abcdefghij",
    path: "./abcdefghij",
    kind: Regular,
    children: [],
    size: None,
    note: None,
    limited: false,
  }
  let root : TreeNode = {
    ..leaf,
    name: ".",
    path: ".",
    kind: Directory,
    children: Array::make(10000, leaf),
  }
  let counts = node_counts(root, root=true)
  assert_eq((counts.directories, counts.files), (1, 10000))
  for
    args in [
      ["--noreport"],
      ["-J", "--noreport"],
      ["-H", "https://example.invalid/", "--noreport"],
    ] {
    let options = parse_arguments(args).options
    let mut calls = 0
    let mut maximum = 0
    let mut total = 0
    let output = TreeOutput::new(chunk => {
      calls += 1
      maximum = maximum.max(chunk.length())
      total += chunk.length()
    })
    match options.format {
      Text => render_node(root, options, "", true, true, output)
      Json => render_json([root], options, counts, output)
      Html(base) => render_html([root], options, base, counts, output)
    }
    output.flush()
    assert_true(calls > 1)
    assert_true(maximum < 67584)
    assert_true(total > 100000)
  }
}

///|
test "tree sizes retain C float32 rounding and report widths" {
  assert_eq(size_text(3L, ExactSize), "           3")
  assert_eq(size_text(3L, HumanSize), "    3")
  assert_eq(size_text(1024L, HumanSize), " 1.0K")
  assert_eq(size_text(1024L, SiSize), " 1.0k")
  assert_eq(size_text(1048576L, HumanSize), " 1.0M")
  assert_eq(size_text(1000000L, SiSize), " 1.0M")
  assert_eq(size_text(1150L, SiSize), " 1.1k")
}

///|
async test "tree uses available public size and rejects unavailable mode predicates" {
  let root = @fs.tmpdir(prefix="mooncmd-tree-boundary")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let observed = try @fs.file_size(root) catch {
    _ => None
  } noraise {
    size => Some(size)
  }
  match observed {
    None =>
      try collect_node(root, "root", 0, parse_arguments(["-s"]).options) catch {
        TreeError(message) => assert_true(message.contains("cannot read size"))
      } noraise {
        _ => fail("an unavailable directory size must not be invented")
      }
    Some(size) => {
      let node = collect_node(root, "root", 0, parse_arguments(["-s"]).options)
      assert_eq(node.size, Some(size))
      @fs.mkdir(root + "/sub")
      @fs.write_file(root + "/a", "aaa")
      @fs.write_file(root + "/sub/b", "bb")
      let expected = @fs.file_size(root) + @fs.file_size(root + "/sub") + 5L
      let usage = collect_node(
        root,
        "root",
        0,
        parse_arguments(["--du"]).options,
      )
      assert_eq(usage.size, Some(expected))
      let counts = node_counts(usage, root=true, disk_usage=true)
      assert_eq(
        (counts.directories, counts.files, counts.size),
        (2, 2, expected),
      )
    }
  }
  let colors : TreeColors = { codes: { "ex": "0" }, suffixes: [], }
  try require_color_kind(Regular, colors) catch {
    TreeError(message) => assert_true(message.contains("ex"))
  } noraise {
    _ => fail("even ex=0 is an enabled tree predicate")
  }
  require_color_kind(Pipe, colors)
}

///|
test "disk usage report counts aggregate roots without counting descendants twice" {
  let leaf : TreeNode = {
    name: "b",
    path: "sub/b",
    kind: Regular,
    children: [],
    size: Some(13L),
    note: None,
    limited: false,
  }
  let sub : TreeNode = {
    ..leaf,
    name: "sub",
    path: "sub",
    kind: Directory,
    children: [leaf],
    size: Some(18L),
  }
  let root : TreeNode = {
    ..sub,
    name: ".",
    path: ".",
    children: [sub, { ..leaf, name: "a", size: Some(5L), }],
    size: Some(28L),
  }
  let counts = node_counts(root, root=true, disk_usage=true)
  assert_eq((counts.directories, counts.files, counts.size), (2, 2, 28L))
}
