///|
test "controlled option children preserve argv boundaries and split source quoting" {
  let args = expand_args(
    ["${PRINTF_CHILD}", "<%s>\n", "two words", ""],
    "/work",
  )
  assert_eq(args, [
    option_child_path(),
    "--option-test-helper",
    "printf",
    "<%s>\n",
    "two words",
    "",
  ])
  let source = expand_text("${PRINTENV_CHILD} A B", "/work")
  assert_true(source.has_suffix("' --option-test-helper printenv A B"))
  let fixture : Case = @json.from_json(
    @json.parse(
      "{\"id\":\"controlled-child\",\"command\":\"env\",\"args\":[\"-S\",\"${PRINTF_CHILD} %s value\"],\"files\":[],\"environment\":{},\"normalizations\":[],\"expected_status\":0}",
    ),
  )
  assert_true(option_child_required(fixture))
  assert_false(option_child_required({ ..fixture, args: ["--help"], }))
}

///|
test "controlled option children resolve relative executables before fixture cwd changes" {
  let program = option_child_executable("./helper directory/runner.exe")
  assert_true(@path.Path(program).is_absolute())
  let expected = @path.Path(@env.current_dir().unwrap())
    .join(Path("helper directory/runner.exe"))
    .to_string()
    .replace_all(old="\\", new="/")
  assert_eq(program, expected)
  assert_eq(option_child_executable(program), program)
}
