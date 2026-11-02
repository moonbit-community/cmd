///|
async test "resource comparisons reject changed tail bytes and extra fragments" {
  let root = @fs.tmpdir(prefix="cmd-resource-relations-")
  defer @fs.rmdir(root, recursive=true)
  let source = root + "/source"
  let copy = root + "/copy"
  let payload = "x".repeat(65536) + "tail\n"
  @fs.write_file(source, payload)
  @fs.write_file(copy, payload)
  assert_true(equal_files(source, copy))
  @fs.write_file(copy, "x".repeat(65536) + "fail\n")
  assert_false(equal_files(source, copy))
  @fs.write_file(copy, payload + "extra")
  assert_false(equal_files(source, copy))
  let effects = root + "/effects"
  @fs.mkdir(effects)
  @fs.write_file(effects + "/part-00", b"")
  @fs.write_file(effects + "/part-01", payload)
  assert_true(single_record_fragments_match(source, effects))
  @fs.write_file(effects + "/part-02", b"")
  assert_false(single_record_fragments_match(source, effects))
  @fs.remove(effects + "/part-02")
  @fs.write_file(effects + "/part-00", b"unexpected")
  assert_false(single_record_fragments_match(source, effects))
}

///|
async test "resource input preserves exact requested size and complete fragment coverage" {
  let root = @fs.tmpdir(prefix="cmd-resource-input-")
  defer @fs.rmdir(root, recursive=true)
  let input = root + "/input"
  write_input(input, 65539L, 80L, false, true)
  let bytes = @fs.read_file(input).binary()
  assert_eq(bytes.length(), 65539)
  assert_eq(bytes[bytes.length() - 1], b'\n')
  assert_true(bytes.iter().any(byte => byte == b'\x00'))
  assert_true(bytes.iter().any(byte => byte == b'\xff'))
  let repeat = root + "/repeat"
  write_input(repeat, 65539L, 80L, false, true)
  assert_true(equal_files(input, repeat))
  let effects = root + "/effects"
  @fs.mkdir(effects)
  let features : ContentInput = {
    bytes: 65539L,
    rows: 3L,
    short_record_bytes: 0L,
    mixed: false,
    section_offsets: [2L, 65536L],
  }
  @fs.write_file(effects + "/part-000000", bytes[:2].to_owned())
  @fs.write_file(effects + "/part-000001", bytes[2:65536].to_owned())
  @fs.write_file(effects + "/part-000002", bytes[65536:].to_owned())
  assert_true(content_fragments_match(input, effects, features))
  @fs.write_file(effects + "/part-000002", b"")
  assert_false(content_fragments_match(input, effects, features))
}
