// Original system-test identities are retained against the released API adapter.
// Public-runtime diagnostic strings replace native-only errno translations.

///|
async fn fs_roundtrip(dir : String) -> Unit {
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
}

///|
fn fixture_args(root : String, mode : String) -> Array[String] {
  [
    "run",
    "internal/sys/testdata/process_fixture.mbtx",
    "--warn-list=-a",
    "--target-dir",
    root + "/build",
    "--",
    mode,
  ]
}
