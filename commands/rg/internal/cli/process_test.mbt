///|
async test "CommandReader stops a command early without error" {
  let root = @fs.tmpdir(prefix="rg-command-reader-")
  defer @fs.rmdir(root, recursive=true)
  let rdr = @cli.CommandReader::new("moon", [
    "run",
    "internal/sys/testdata/process_fixture.mbtx",
    "--warn-list=-a",
    "--target-dir",
    root + "/build",
    "--",
    "stream",
  ])
  defer (rdr.close() catch { _ => () })
  let buf = FixedArray::make(4, b'\x00')
  let mut have = 0
  while have < 4 {
    let n = rdr.read(buf, have, 4 - have)
    assert_true(n > 0)
    have += n
  }
  assert_eq(Bytes::from_array(buf[:]), b"foo\n")
  rdr.close()
}
