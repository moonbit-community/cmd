///|
async test "two HTTP error responses cannot qualify as an equal successful transfer" {
  let root = @fs.tmpdir(prefix="real-http-output-")
  defer @fs.rmdir(root, recursive=true)
  @fs.write_file(root + "/source", b"real\x00payload\n")
  @fs.write_file(root + "/echo", b"real\x00payload\n")
  assert_eq(real_http_output_errors(root + "/source", root + "/echo"), [])
  // curl can return status0 for HTTP400/405: equality between two empty
  // responses must still fail this independent expected-content relation.
  for output in [b"", b"real\x00", b"other payload\n"] {
    @fs.write_file(root + "/rejected", output)
    assert_true(
      !real_http_output_errors(root + "/source", root + "/rejected").is_empty(),
    )
  }
}
