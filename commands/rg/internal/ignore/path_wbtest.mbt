// Tests for the Rust `Path`-like helpers and `pathutil` port.

///|
test "pathutil/file_name" {
  debug_inspect(file_name(""), content="None")
  debug_inspect(file_name("."), content="None")
  debug_inspect(file_name("foo."), content="None")
  debug_inspect(file_name("foo/.."), content="None")
  debug_inspect(
    file_name("foo/bar"),
    content=(
      #|Some("bar")
    ),
  )
  debug_inspect(
    file_name("bar"),
    content=(
      #|Some("bar")
    ),
  )
  debug_inspect(
    file_name("foo/"),
    content=(
      #|Some("")
    ),
  )
}

///|
test "pathutil/hidden_and_prefix" {
  assert_true(is_hidden_path("./.foo"))
  assert_true(is_hidden_path(".git"))
  assert_true(!is_hidden_path("."))
  assert_true(!is_hidden_path("a/b"))
  assert_true(is_file_name("foo"))
  assert_true(!is_file_name("a/foo"))
  debug_inspect(
    strip_prefix("./", "./foo"),
    content=(
      #|Some("foo")
    ),
  )
  debug_inspect(strip_prefix("./", "foo"), content="None")
}

///|
test "path/parent" {
  debug_inspect(
    path_parent("foo/bar"),
    content=(
      #|Some("foo")
    ),
  )
  debug_inspect(
    path_parent("foo"),
    content=(
      #|Some("")
    ),
  )
  debug_inspect(
    path_parent("/foo"),
    content=(
      #|Some("/")
    ),
  )
  debug_inspect(path_parent("/"), content="None")
  debug_inspect(path_parent(""), content="None")
  debug_inspect(
    path_parent("./foo"),
    content=(
      #|Some(".")
    ),
  )
  debug_inspect(
    path_parent("a//b/"),
    content=(
      #|Some("a")
    ),
  )
  debug_inspect(
    path_parent("a/./b"),
    content=(
      #|Some("a")
    ),
  )
}

///|
test "path/file_name_join_strip" {
  debug_inspect(
    path_file_name("a/b/"),
    content=(
      #|Some("b")
    ),
  )
  debug_inspect(path_file_name("a/.."), content="None")
  debug_inspect(path_file_name("/"), content="None")
  inspect(path_join("a", "b"), content="a/b")
  inspect(path_join("a/", "b"), content="a/b")
  inspect(path_join("", "b"), content="b")
  inspect(path_join("a", "/b"), content="/b")
  debug_inspect(
    path_strip_prefix("/a/b/c", "/a"),
    content=(
      #|Some("b/c")
    ),
  )
  debug_inspect(
    path_strip_prefix("/a/b", "/a/b/"),
    content=(
      #|Some("")
    ),
  )
  debug_inspect(path_strip_prefix("/ab/c", "/a"), content="None")
  assert_true(path_eq("./", "."))
  assert_true(!path_eq("", "."))
}

///|
test "path/compare_utf8" {
  assert_true(compare_utf8("a", "b") < 0)
  assert_true(compare_utf8("b", "aa") > 0)
  assert_true(compare_utf8("Z", "a") < 0)
  assert_true(compare_utf8("ab", "ab") == 0)
  // U+FF61 encodes as EF BD A1 in UTF-8, U+10000 as F0 90 80 80, so the
  // supplementary character sorts last (unlike UTF-16 code unit order).
  assert_true(compare_utf8("\u{FF61}", "\u{10000}") < 0)
}

///|
test "error/display" {
  let io = @sys.IOError::from_errno(2)
  let e = IgnoreError::Io(io).tagged("/a/.gitignore", 3)
  inspect(
    e,
    content="/a/.gitignore: line 3: No such file or directory (os error 2)",
  )
  assert_true(e.is_io())
  assert_true(!e.is_partial())
  let e = IgnoreError::Glob(glob=Some("{a"), err="oops").tagged("", 1)
  inspect(e, content="line 1: error parsing glob '{a': oops")
  let p = IgnoreError::Partial([
    Glob(glob=None, err="x"),
    UnrecognizedFileType("foo"),
  ])
  inspect(
    p,
    content=(
      #|x
      #|unrecognized file type: foo
    ),
  )
  assert_true(p.is_partial())
  let l = IgnoreError::Loop(ancestor="a", child="a/b/c").with_depth(3)
  inspect(l, content="File system loop found: a/b/c points to an ancestor a")
  debug_inspect(l.depth(), content="Some(3)")
  debug_inspect(l.with_path("x").depth(), content="Some(3)")
  assert_true(IgnoreError::Partial([Io(io)]).io_error() is Some(_))
}

///|
test "match/methods" {
  let m : Match[Int32] = Ignore(1)
  assert_true(m.is_ignore())
  assert_true(m.invert().is_whitelist())
  debug_inspect(m.inner(), content="Some(1)")
  debug_inspect(m.map(x => x + 1), content="Ignore(2)")
  let n : Match[Int32] = None
  debug_inspect(n.or(m), content="Ignore(1)")
  debug_inspect(m.or(Whitelist(5)), content="Ignore(1)")
  assert_true(n.inner() is None)
}
