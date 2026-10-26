///|
async test "brotli decompress large WOFF2 table data (306KB)" {
  let compressed = @fs.read_file("internal/codec/brotli/testdata/woff2_dejavu_tables.br").binary()
  let expected = @fs.read_file("internal/codec/brotli/testdata/woff2_dejavu_tables.bin").binary()
  assert_true(compressed.length() > 0)
  assert_true(expected.length() > 0)
  assert_eq(decompress(compressed), expected)
}
