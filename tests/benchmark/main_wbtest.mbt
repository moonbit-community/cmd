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
