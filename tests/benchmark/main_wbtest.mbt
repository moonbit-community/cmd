///|
async test "benchmark trial log retains consecutive JSON lines" {
  let directory = @fs.tmpdir(prefix="cmd-benchmark-log-")
  defer @fs.rmdir(directory, recursive=true)
  let path = directory + "/trials.jsonl"
  append_jsonl(path, { "pair": 0, "correct": true })
  append_jsonl(path, { "pair": 1, "correct": false })
  assert_eq(
    @fs.read_file(path).text(),
    "{\"pair\":0,\"correct\":true}\n{\"pair\":1,\"correct\":false}\n",
  )
}

///|
async test "benchmark small inputs preserve partial chunks and operand expectations" {
  let directory = @fs.tmpdir(prefix="cmd-benchmark-input-")
  defer @fs.rmdir(directory, recursive=true)
  for (size, expected) in [(0, b""), (1, b"a")] {
    let path = directory + "/input-" + size.to_string()
    prepare_input(path, size)
    assert_eq(@fs.read_file(path).binary(), expected)
  }
  let input = directory + "/input-4096"
  prepare_input(input, 4096)
  let bytes = @fs.read_file(input).binary()
  assert_eq(bytes.length(), 4096)
  assert_eq(
    bytes[:64].to_owned(),
    b"abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijk\n",
  )
  assert_eq(bytes[4095], b'\n')
  let crossing = directory + "/input-65537"
  prepare_input(crossing, 65537)
  assert_eq(@fs.file_size(crossing), 65537L)
  let file = @fs.open(crossing, mode=ReadOnly)
  defer file.close()
  assert_eq(file.read_exactly_at(1, position=65536L), b"a")
  let workload : PilotWorkload = {
    id: "basename-operand-4k",
    reference_behavior_id: "case:phase3-basename-suffix",
    command: "basename",
    input_bytes: 4096,
    expected_status: 0,
    args: Some(["--", "${INPUT_TEXT}"]),
    input_mode: Some("operand"),
    stdout_check: Some("input-newline"),
  }
  let args = workload_args(workload, input)
  assert_eq(args[0], "--")
  assert_eq(args[1], @fs.read_file(input).text())
  let expected = prepare_expected(
    workload,
    input,
    directory + "/input-0",
    directory,
  )
  assert_eq(@fs.read_file(expected).binary(), bytes + b"\n")
  let count = { ..workload, command: "wc", stdout_check: Some("byte-count"), }
  let expected = prepare_expected(
    count,
    input,
    directory + "/input-0",
    directory,
  )
  assert_eq(@fs.read_file(expected).text(), "4096\n")
  let checksum = {
    ..workload,
    command: "sha256sum",
    stdout_check: Some("sha256"),
  }
  let expected = prepare_expected(
    checksum,
    directory + "/input-0",
    directory + "/input-0",
    directory,
  )
  assert_eq(
    @fs.read_file(expected).text(),
    "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855  -\n",
  )
}

///|
async test "benchmark gzip observations decode content and reject corrupt output" {
  let directory = @fs.tmpdir(prefix="cmd-benchmark-gzip-")
  defer @fs.rmdir(directory, recursive=true)
  let compressed = directory + "/compressed.gz"
  let expected = directory + "/input.bin"
  let decoded = directory + "/decoded.bin"
  // A standard fixed-Huffman gzip member containing "abc".
  @fs.write_file(
    compressed, b"\x1f\x8b\x08\x00\x00\x00\x00\x00\x00\x03\x4b\x4c\x4a\x06\x00\xc2\x41\x24\x35\x03\x00\x00\x00",
  )
  @fs.write_file(expected, b"abc")
  assert_true(gzip_roundtrip(compressed, expected, decoded))
  @fs.write_file(expected, b"abd")
  assert_false(gzip_roundtrip(compressed, expected, decoded))
  @fs.write_file(compressed, b"not gzip data")
  let accepted = gzip_roundtrip(compressed, expected, decoded) catch {
    _ => false
  }
  assert_false(accepted)
}
