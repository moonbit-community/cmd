///|
test "metadata pair rejects different help bytes even when both contracts permit them" {
  let native : Map[String, Bytes] = {
    "help.stdout.bin": b"Usage: echo\n--help --version native detail\n",
    "help.stderr.bin": b"",
    "help.status.txt": b"0",
    "version.stdout.bin": b"echo 0.2.0\n",
    "version.stderr.bin": b"",
    "version.status.txt": b"0",
  }
  assert_true(metadata_pair_differences(native, native).is_empty())
  let wasm = native.copy()
  wasm["help.stdout.bin"] = b"Usage: echo\n--help --version different detail\n"
  assert_eq(metadata_pair_differences(native, wasm), [
    "backend observation differs: help.stdout.bin",
  ])
  wasm["help.stdout.bin"] = native["help.stdout.bin"]
  wasm["version.status.txt"] = b"1"
  assert_eq(metadata_pair_differences(native, wasm), [
    "backend observation differs: version.status.txt",
  ])
  assert_false(metadata_pair_differences(Map([]), Map([])).is_empty())
}
