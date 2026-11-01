///|
async test "transfer file checks retain independent failures" {
  let work = @fs.tmpdir(prefix="mooncmd-transfer-observation-")
  defer @fs.rmdir(work, recursive=true)
  @fs.write_file(work + "/wrong.bin", "actual")
  @fs.write_file(work + "/extra.bin", "unexpected")
  let error = try {
    check_transfer_files(
      work,
      [("missing.bin", Some("required")), ("wrong.bin", Some("expected"))],
      @fs.readdir(work),
    )
    ""
  } catch {
    error => error.to_string()
  }
  assert_true(error.contains("transfer output file set differs"))
  assert_true(error.contains("missing.bin"))
  assert_true(error.contains("wrong.bin"))
}
