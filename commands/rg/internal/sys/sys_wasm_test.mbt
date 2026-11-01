///|
async test "wasm: unsupported operations" {
  // Removal and child processes are now public Wasm operations. Detection and
  // readlink remain explicit boundaries instead of the old fabricated false.
  let root = @fs.tmpdir(prefix="rg-wasm-capabilities-")
  defer @fs.rmdir(root, recursive=true)
  @sys.write_file(root + "/file", b"data")
  @sys.remove_file(root + "/file")
  assert_false(@sys.path_exists(root + "/file"))
  assert_true(@sys.stdin_is_readable() is Unavailable(_))
  assert_true(@sys.is_tty(1) is Unavailable(_))
  assert_true(
    try {
      ignore(@sys.read_link(root + "/link"))
      false
    } catch {
      @sys.IOError(kind=Unsupported, ..) => true
      _ => false
    },
  )
}

///|
async test "wasm: empty directory removal" {
  let root = @fs.tmpdir(prefix="rg-original-wasm-rmdir-")
  @sys.create_dir_all(root + "/x/y")
  @sys.remove_dir_all(root)
  assert_false(@sys.path_exists(root))
}
