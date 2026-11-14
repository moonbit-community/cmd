///|
async test "owned evaluation follows independently frozen jq generator and closure results" {
  let mut root = @fs.realpath(".")
  while !@fs.exists(root + "/moon.work") {
    let parent = @fs.realpath(root + "/..")
    guard parent != root else {
      fail("jq evaluation corpus workspace is missing")
    }
    root = parent
  }
  guard @json.parse(
      @fs.read_file(root + "/tests/fixtures/jq/evaluation.json").text(),
    )
    is { "binary_sha256": String(binary), "cases": Array(cases), .. } else {
    fail("missing evaluation corpus")
  }
  assert_true(
    binary.has_prefix(
      "b1c22172dd303f3be49e935aa56aa48a8b7a46e0bc838b4997d3bb451495870f",
    ),
  )
  assert_eq(cases.length(), 57)
  for record in cases {
    guard record
      is {
        "label": String(label),
        "args": Array([String("-c"), String(query)]),
        "stdin_text": String(input),
        "status": Number(status, ..),
        "stdout_text": String(stdout),
        ..
      } else {
      fail("invalid evaluation record")
    }
    let expected : Array[Json] = []
    for line in stdout.split("\n") {
      if !line.is_empty() {
        expected.push(@json.parse(line))
      }
    }
    let actual = try {
      let program = @parser.parse_program(query)
      let scope = @ast.Env::new()
      scope.validate(program.body)
      Some(@ast.eval(program.body, @json.parse(input)).collect())
    } catch {
      _ => None
    }
    if status == 0 {
      assert_eq(actual, Some(expected), msg=label)
    } else {
      assert_eq(actual, None, msg=label)
    }
  }
}
