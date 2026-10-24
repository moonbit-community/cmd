///|
async test "realpath missing and strip modes preserve physical link semantics" {
  let root = @fs.tmpdir(prefix="mooncmd-realpath-o10")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  @fs.mkdir(root + "/existing/child", recursive=true)
  @fs.write_file(root + "/file", b"data")
  let canonical_root = @fs.realpath(root)
  let lexical_root = @path.Path(root).resolve().to_string()
  assert_eq(
    resolve_path(root + "/missing/../new", Missing, true),
    lexical_root + @path.sep.to_string() + "new",
  )
  assert_eq(
    resolve_path(root + "/file/../new", Missing, false),
    canonical_root + @path.sep.to_string() + "new",
  )
  try resolve_path(root + "/file/../new", AllButLast, true) catch {
    error => assert_eq(error_text(error), "Not a directory")
  } noraise {
    _ => fail("non-directory components require -m")
  }
  if @platform.symbolic_links_supported() {
    @fs.symlink(target="existing/child", root + "/link")
    assert_eq(
      resolve_path(root + "/link/../new", Missing, false),
      @platform.normalize_input_separators(canonical_root + "/existing/new"),
    )
    assert_eq(
      resolve_path(root + "/link/../new", Missing, true),
      @platform.normalize_input_separators(lexical_root + "/new"),
    )
    @fs.symlink(target="missing", root + "/dangling")
    try resolve_path(root + "/dangling/new", Missing, false) catch {
      error => assert_true(error is ReadlinkBoundary(_))
    } noraise {
      _ => fail("unresolved physical links require readlink")
    }
  }
}

///|
test "relative realpath output respects whole component boundaries" {
  let root = if @platform.is_windows() { "C:\\base" } else { "/base" }
  let child = root + @path.sep.to_string() + "child"
  assert_true(inside(child, root))
  assert_false(inside(root + "ish", root))
  assert_eq(relative_path(root, root), ".")
  assert_eq(relative_path(child, root), "child")
}
