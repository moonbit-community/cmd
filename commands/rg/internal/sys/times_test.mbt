///|
async test "file times" {
  let root = @fs.tmpdir(prefix="rg-original-times-")
  defer @fs.rmdir(root, recursive=true)
  @sys.write_file(root + "/file", b"data")
  let times = @sys.file_times(root + "/file")
  assert_true(times.modified is Some(_))
  assert_true(times.accessed is Some(_))
  assert_eq(times.created, None)
}
