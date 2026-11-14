///|
async test "stream events retain frozen jq paths and prefixes across chunk boundaries" {
  let mut root = @fs.realpath(".")
  while !@fs.exists(root + "/moon.work") {
    let parent = @fs.realpath(root + "/..")
    guard parent != root else { fail("jq stream corpus workspace is missing") }
    root = parent
  }
  guard @json.parse(
      @fs.read_file(root + "/tests/fixtures/jq/stream.json").text(),
    )
    is { "cases": Array(cases), .. } else {
    fail("missing stream cases")
  }
  assert_eq(cases.length(), 47)
  for record in cases {
    guard record
      is {
        "label": String(label),
        "stdin_text": String(text),
        "status": Number(status, ..),
        "stdout_text": String(stdout),
        "stderr_text": String(stderr),
        ..
      } else {
      fail("invalid stream case")
    }
    // File sequencing is exercised by the command cases using these records.
    if label.has_prefix("files-") {
      continue
    }
    let expected : Array[Json] = []
    for line in stdout.split("\n") {
      if !line.is_empty() {
        expected.push(@json.parse(line))
      }
    }
    let source = @utf8.encode(text)
    for chunk in [1, 2, 3, 7, 65536] {
      let reader = @io.MemoryReader(writer => {
        for offset = 0; offset < source.length(); offset = offset + chunk {
          writer.write(source[offset:(offset + chunk).min(source.length())])
        }
      })
      defer reader.close()
      let actual : Array[Json] = []
      let error = try {
        StreamInput::new(reader).read(
          value => actual.push(value),
          errors=label.has_prefix("stream-errors-"),
        )
        ""
      } catch {
        StreamError(message, line, column) =>
          "jq: parse error: " +
          message +
          " at line " +
          line.to_string() +
          ", column " +
          column.to_string() +
          "\n"
        error => raise error
      }
      assert_eq(
        actual,
        expected,
        msg=label +
          ": " +
          Json::array(actual).stringify() +
          " != " +
          Json::array(expected).stringify(),
      )
      assert_eq(error, stderr, msg=label)
      assert_eq(if error == "" { 0 } else { 5 }, status.to_int(), msg=label)
    }
  }
}

///|
async test "stream emits completed children before requesting the remaining document" {
  let events : Array[Json] = []
  let reader = @io.MemoryReader(writer => {
    writer.write("[1,")
    fail("late reader failure")
  })
  defer reader.close()
  try StreamInput::new(reader).read(value => events.push(value)) catch {
    _ => assert_eq(events, [@json.parse("[[0],1]")])
  } noraise {
    _ => fail("missing reader failure")
  }
}

///|
async test "stream output failure prevents later input reads" {
  let reader = @io.MemoryReader(writer => {
    writer.write("[1,")
    fail("must not request the next chunk")
  })
  defer reader.close()
  let writes = Ref(0)
  try
    StreamInput::new(reader).read(_ => {
      writes.val += 1
      fail("output failed")
    })
  catch {
    error => assert_true(error.to_string().contains("output failed"))
  } noraise {
    _ => fail("missing output failure")
  }
  assert_eq(writes.val, 1)
}
