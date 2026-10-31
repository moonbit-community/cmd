///|
async test "released filesystem operations preserve files links and error boundaries" {
  let dir = @fs.tmpdir(prefix="rg-system-filesystem-")
  defer @fs.rmdir(dir, recursive=true)
  @sys.create_dir_all(dir + "/sub/deeper")
  @sys.create_dir_all(dir + "/sub")
  @sys.write_file(dir + "/a.txt", b"hello\nworld\n")
  @sys.write_file(dir + "/sub/b.txt", b"")
  @sys.write_file(dir + "/sub/deeper/c.txt", b"c")
  @sys.write_file(dir + "/t.txt", b"long contents")
  @sys.write_file(dir + "/t.txt", b"short")
  assert_eq(@sys.read_file(dir + "/t.txt"), b"short")
  assert_eq(@sys.read_file(dir + "/a.txt"), b"hello\nworld\n")
  let file = @sys.File::open(dir + "/a.txt")
  assert_true(file.is_regular())
  let chunk = FixedArray::make(16, b'\x00')
  assert_eq(file.read(chunk, 2, 5), 5)
  assert_eq(Bytes::from_array(chunk[2:7]), b"hello")
  assert_eq(file.read(chunk, 0, 16), 7)
  assert_eq(file.read(chunk, 0, 16), 0)
  file.close()
  file.close()
  assert_eq(@sys.file_len(dir + "/a.txt"), 12L)
  assert_true(@sys.metadata(dir + "/a.txt").is_file())
  assert_eq(@sys.metadata(dir + "/sub").file_type, Dir)
  assert_eq(@sys.symlink_metadata(dir + "/a.txt").file_type, File)
  assert_eq(@sys.file_len(dir + "/./sub/../a.txt"), 12L)
  assert_true(@sys.path_exists(dir + "/sub/deeper/c.txt"))
  assert_false(@sys.path_exists(dir + "/nope"))
  let names = @sys.read_dir(dir).map(entry => entry.name)
  assert_true(
    names.contains("a.txt") && names.contains("sub") && names.contains("t.txt"),
  )
  for kind in ["read", "metadata", "directory"] {
    let rejected = try {
      match kind {
        "read" => ignore(@sys.read_file(dir + "/missing"))
        "metadata" => ignore(@sys.metadata(dir + "/missing"))
        _ => ignore(@sys.read_dir(dir + "/a.txt"))
      }
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
  // Link text/identity cannot be inferred from a successful canonical lookup.
  assert_true(
    try {
      ignore(@sys.read_link(dir + "/link"))
      false
    } catch {
      @sys.IOError(kind=Unsupported, ..) => true
      _ => false
    },
  )
  if !(@async.platform is Windows) {
    @sys.symlink("a.txt", dir + "/link")
    assert_eq(@sys.symlink_metadata(dir + "/link").file_type, Symlink)
    assert_eq(@sys.metadata(dir + "/link").len, 12L)
    assert_eq(@sys.read_file(dir + "/link"), b"hello\nworld\n")
  }
  @sys.remove_file(dir + "/t.txt")
  assert_false(@sys.path_exists(dir + "/t.txt"))
}

///|
fn fixture_args(root : String, mode : String) -> Array[String] {
  [
    "run",
    "internal/sys/testdata/process_fixture.mbtx",
    "--target-dir",
    root + "/build",
    "--",
    mode,
  ]
}
