///|
async test "reading a declared unreadable file preserves its observed mode and bytes" {
  if @async.platform is Windows {
    return
  }
  let root = @fs.tmpdir(prefix="cmd-unreadable-observation")
  defer @fs.rmdir(root, recursive=true)
  let path = root + "/locked"
  @fs.write_file(path, b"contents")
  @fs.chmod(path, 0)
  let before = snapshot(root, observe=["mode"], content=false)
  assert_eq(before[0].metadata.get("mode"), Some("0"))
  let result = snapshot(root, observe=["mode"], unreadable_inputs=["locked"])
  assert_eq(result[0].metadata.get("mode"), Some("0"))
  assert_eq(result[0].content, b"contents")
  let after = snapshot(root, observe=["mode"], content=false)
  assert_eq(after[0].metadata.get("mode"), Some("0"))
}
