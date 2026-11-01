///|
async test "directory entries retain known directories and query unknown kinds" {
  let root = @fs.tmpdir(prefix="rg-directory-observation-")
  defer @fs.rmdir(root, recursive=true)
  @fs.mkdir(root + "/nested")
  @fs.write_file(root + "/regular", b"contents")
  @fs.write_file(root + "/.hidden", b"")
  let entries = @sys.read_dir(root)
  assert_eq(entries.length(), 3)
  for entry in entries {
    let path = root + "/" + entry.name
    if entry.name == "nested" {
      // A listing carries a kind observation, not a later stat of the path.
      @fs.rmdir(path)
      assert_eq(entry.file_type(path), Dir)
    } else {
      assert_eq(entry.file_type(path), File)
      @fs.remove(path)
      assert_true(
        try {
          ignore(entry.file_type(path))
          false
        } catch {
          @sys.IOError(kind=NotFound, ..) => true
          _ => false
        },
      )
    }
  }
}

///|
async test "directory kind queries do not follow live or dangling links" {
  if @async.platform is Windows {
    return
  }
  let root = @fs.tmpdir(prefix="rg-directory-links-")
  defer @fs.rmdir(root, recursive=true)
  @fs.mkdir(root + "/nested")
  @fs.symlink(target="nested", root + "/directory-link")
  @fs.symlink(target="missing", root + "/dangling-link")
  for entry in @sys.read_dir(root) {
    assert_eq(
      entry.file_type(root + "/" + entry.name),
      if entry.name == "nested" {
        Dir
      } else {
        Symlink
      },
    )
  }
}
