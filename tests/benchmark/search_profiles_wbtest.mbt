///|
async test "gzip benchmark semantics accept distinct valid encodings but reject changed decoded bytes" {
  let directory = @fs.tmpdir(prefix="cmd-gzip-relation-")
  defer @fs.rmdir(directory, recursive=true)
  // Same payload, different DEFLATE block type: fixed Huffman and stored.
  let fixed = b"\x1f\x8b\x08\x00\x00\x00\x00\x00\x00\x03\x4b\x4c\x4a\x06\x00\xc2\x41\x24\x35\x03\x00\x00\x00"
  let stored = b"\x1f\x8b\x08\x00\x00\x00\x00\x00\x00\x03\x01\x03\x00\xfc\xffabc\xc2\x41\x24\x35\x03\x00\x00\x00"
  assert_true(fixed != stored)
  @fs.write_file(directory + "/source", b"abc")
  for (name, encoded) in [("fixed", fixed), ("stored", stored)] {
    @fs.write_file(directory + "/" + name, encoded)
    assert_true(
      gzip_roundtrip(
        directory + "/" + name,
        directory + "/source",
        directory + "/decoded",
      ),
    )
  }
  @fs.write_file(directory + "/source", b"abd")
  assert_false(
    gzip_roundtrip(
      directory + "/stored",
      directory + "/source",
      directory + "/decoded",
    ),
  )
}
