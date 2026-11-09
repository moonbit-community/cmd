///|
async test "success evidence compaction preserves exact binary and hidden observations" {
  let root = @fs.tmpdir(prefix="cmd-compact-evidence-")
  defer @fs.rmdir(root, recursive=true)
  let work = root + "/case"
  @fs.mkdir(work)
  @fs.mkdir(work + "/nested")
  @fs.write_file(work + "/nested/output.bin", b"\x00\xff\x0a")
  @fs.write_file(work + "/.intent.json", "{\"returned\":true}")
  let output = compact_evidence(work)
  assert_false(@fs.exists(work))
  let rows : Array[Json] = []
  for line in @fs.read_file(output).text().split("\n") {
    if line != "" {
      rows.push(@json.parse(line.to_owned()))
    }
  }
  assert_eq(rows.length(), 3)
  assert_true(
    rows.any(row => {
      row
      is {
        "path": String("nested/output.bin"),
        "content_hex": String("00ff0a"),
        ..
      }
    }),
  )
  assert_true(rows.any(row => row is { "path": String(".intent.json"), .. }))
}

///|
async test "compaction refuses an existing destination without deleting original observations" {
  let root = @fs.tmpdir(prefix="cmd-compact-failure-")
  defer @fs.rmdir(root, recursive=true)
  @fs.mkdir(root + "/case")
  @fs.write_file(root + "/case/output", "original")
  @fs.write_file(root + "/case.jsonl", "previous")
  try compact_evidence(root + "/case") catch {
    _ => ()
  } noraise {
    _ => fail("existing report was overwritten")
  }
  assert_eq(@fs.read_file(root + "/case/output").text(), "original")
  assert_eq(@fs.read_file(root + "/case.jsonl").text(), "previous")
}
