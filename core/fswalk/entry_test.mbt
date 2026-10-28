///|
async test "directory enumeration owns its handle and leaves ordering to callers" {
  let root = @fs.tmpdir(prefix="cmd-fswalk-")
  defer @fs.rmdir(root, recursive=true)
  @fs.write_file(root + "/visible", b"abc")
  @fs.write_file(root + "/.hidden", b"")
  let names = @fswalk.read_directory(root)
  names.sort()
  assert_eq(names, [".hidden", "visible"])
  assert_eq(@fswalk.read_directory(root, include_hidden=false), ["visible"])
  let entry = @fswalk.Entry::read(root + "/visible")
  assert_eq(entry.kind, @fs.Regular)
  assert_eq(entry.regular_size(OpenFile), Some(3L))
  assert_eq(entry.regular_size(ResolvedPath), Some(3L))
  let directory = @fswalk.Entry::read(root)
  assert_eq(directory.regular_size(OpenFile), None)
  assert_eq(directory.regular_size(ResolvedPath), None)
}

///|
async test "known kinds do not query paths and size failures remain observable" {
  let root = @fs.tmpdir(prefix="cmd-fswalk-lazy-")
  defer @fs.rmdir(root, recursive=true)
  let absent = @fswalk.Entry::known(root + "/absent", @fs.Regular)
  assert_eq(absent.kind, @fs.Regular)
  for source in [@fswalk.OpenFile, @fswalk.ResolvedPath] {
    try absent.regular_size(source) catch {
      _ => ()
    } noraise {
      _ => fail("requested metadata must not hide a missing file")
    }
  }
  assert_eq(@fswalk.read_directory(root), [])
}

///|
async test "kind and size preserve explicit link-following policy" {
  if @async.platform is Windows {
    return
  }
  let root = @fs.tmpdir(prefix="cmd-fswalk-links-")
  defer @fs.rmdir(root, recursive=true)
  @fs.write_file(root + "/target", b"payload")
  @fs.symlink(root + "/link", target="target")
  let link = @fswalk.Entry::read(root + "/link")
  assert_eq(link.kind, @fs.SymLink)
  assert_eq(link.regular_size(ResolvedPath), None)
  let followed = @fswalk.Entry::read(root + "/link", follow_symlink=true)
  assert_eq(followed.kind, @fs.Regular)
  assert_eq(followed.regular_size(ResolvedPath), Some(7L))
  assert_eq(followed.regular_size(OpenFile), Some(7L))
}
