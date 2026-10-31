///|
async test "independent record reversal distinguishes native boundary reordering and binary domain" {
  let root = @fs.tmpdir(prefix="cmd-reversal-relation-")
  defer @fs.rmdir(root, recursive=true)
  let input = "ab" + "x".repeat(1021) + "\ncd\ntail"
  @fs.write_file(root + "/input", input)
  assert_true(ascii_reversal_expected(root + "/input", root + "/expected"))
  assert_eq(
    @fs.read_file(root + "/expected").text(),
    "x".repeat(1021) + "ba\ndc\nliat",
  )
  @fs.write_file(root + "/unicode", b"\xc3\xa9\n")
  assert_false(ascii_reversal_expected(root + "/unicode", root + "/rejected"))
  assert_false(@fs.exists(root + "/rejected"))
}
