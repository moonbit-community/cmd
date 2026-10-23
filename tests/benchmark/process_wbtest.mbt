///|
async test "benchmark file comparison checks later chunks length and empty output" {
  let root = @fs.tmpdir(prefix="mooncmd-benchmark-files")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let left = root + "/left"
  let right = root + "/right"
  let contents = @buffer.Buffer()
  for _ in 0..<65536 {
    contents.write_byte(b'a')
  }
  contents.write_bytes(b"tail\x00\n")
  let original = contents.to_bytes()
  @fs.write_file(left, original)
  @fs.write_file(right, original)
  assert_true(files_equal(left, right))
  contents.write_byte(b'x')
  @fs.write_file(right, contents.to_bytes())
  assert_false(files_equal(left, right))
  @fs.write_file(right, b"")
  assert_false(files_equal(left, right))
  @fs.write_file(left, b"")
  assert_true(files_equal(left, right))
  let changed = @buffer.Buffer()
  for _ in 0..<65536 {
    changed.write_byte(b'a')
  }
  changed.write_bytes(b"fail\x00\n")
  @fs.write_file(left, original)
  @fs.write_file(right, changed.to_bytes())
  assert_false(files_equal(left, right))
}
