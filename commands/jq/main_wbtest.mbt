///|
test "jq sort and output modes are deterministic" {
  let value = @json.parse("{\"z\":1,\"a\":2}")
  assert_eq(
    render_result(value, false, true, true, None, false, None),
    "{\"a\":2,\"z\":1}",
  )
  assert_eq(status_for_results([@json.parse("false")]), 1)
  assert_eq(status_for_results([@json.parse("null")]), 1)
  assert_eq(status_for_results([@json.parse("true")]), 0)
}

///|
async test "jq raw input framing omits terminal empty records" {
  guard parse_cli(["-R", "."]) is Run(options) else { fail("raw options") }
  let state : Evaluation = {
    query: compile_query(".", {}),
    options,
    colors: None,
    last: None,
    values: [],
    raw: [],
  }
  let input = @io.MemoryReader(writer => writer.write("one\ntwo\n"))
  defer input.close()
  state.read(input)
  assert_eq(state.last, Some(Json::string("two")))
}

///|
test "jq argument binding supports interpolation and lexical shadowing" {
  let args : Map[String, String] = { "name": json_string_literal("Moon") }
  assert_eq(
    @ast.eval(compile_query("\"hello \\($name)\"", args), Json::null()).collect(),
    [Json::string("hello Moon")],
  )
  assert_eq(
    @ast.eval(compile_query("\"inner\" as $name | $name", args), Json::null()).collect(),
    [Json::string("inner")],
  )
  assert_eq(
    @ast.eval(
      compile_query("[$name, (\"inner\" as $name | $name), $name]", args),
      Json::null(),
    ).collect(),
    [
      Json::array([
        Json::string("Moon"),
        Json::string("inner"),
        Json::string("Moon"),
      ]),
    ],
  )
}

///|
async test "jq frames consecutive JSON values including nested and escaped strings" {
  let reader = @io.MemoryReader(writer => {
    writer.write("1\n{\"s\":\"}\\\"\"}[2,3]\"尾\" true null")
  })
  defer reader.close()
  let input = JsonInput::new(reader)
  let values : Array[Json] = []
  while input.next() is Some(value) {
    values.push(value)
  }
  assert_eq(values, [
    @json.parse("1"),
    @json.parse("{\"s\":\"}\\\"\"}"),
    @json.parse("[2,3]"),
    Json::string("尾"),
    Json::boolean(true),
    Json::null(),
  ])
}

///|
async test "jq preserves prior values before a later parse error" {
  let reader = @io.MemoryReader(writer => writer.write("1\n{bad"))
  defer reader.close()
  let input = JsonInput::new(reader)
  assert_eq(input.next(), Some(Json::number(1)))
  let failed = try {
    ignore(input.next())
    false
  } catch {
    _ => true
  }
  assert_true(failed)
}

///|
async test "jq empty input yields no values" {
  let reader = @io.MemoryReader(writer => writer.write(" \r\n\t"))
  defer reader.close()
  assert_eq(JsonInput::new(reader).next(), None)
}

///|
test "jq color and indentation flags follow upstream precedence" {
  for args in [["-CM"], ["-MC"], ["--color-output", "--monochrome-output"]] {
    guard parse_cli(args) is Run(options) else { fail("color options") }
    assert_false(options.color_output)
  }
  guard parse_cli(["-C"]) is Run(color) else { fail("color option") }
  assert_true(color.color_output)
  guard parse_cli(["--tab", "-c"]) is Run(compact) else {
    fail("compact option")
  }
  assert_true(compact.compact_output)
  assert_false(compact.tab)
  guard parse_cli(["-c", "--tab"]) is Run(tab) else { fail("tab option") }
  assert_false(tab.compact_output)
  assert_true(tab.tab)
  guard parse_cli(["--indent", "0"]) is Run(zero) else { fail("zero indent") }
  assert_false(zero.compact_output)
  assert_eq(zero.indent, Some(0))
  guard parse_cli(["--indent", "-1"]) is Run(negative) else {
    fail("compact indent")
  }
  assert_false(negative.compact_output)
  assert_true(negative.tab)
  assert_true(parse_cli(["--indent", "8"]) is Error(_))
}

///|
test "jq nested ANSI rendering preserves punctuation resets and raw strings" {
  let palette = default_colors()
  assert_eq(
    render_result(
      @json.parse("{\"a\":[null,true,\"x\"]}"),
      false,
      true,
      false,
      None,
      false,
      Some(palette),
    ),
    "\u{1b}[1;39m{\u{1b}[0m\u{1b}[1;34m\"a\"\u{1b}[0m\u{1b}[1;39m:\u{1b}[0m\u{1b}[1;39m[\u{1b}[0m\u{1b}[0;90mnull\u{1b}[0m\u{1b}[1;39m,\u{1b}[0m\u{1b}[0;39mtrue\u{1b}[0m\u{1b}[1;39m,\u{1b}[0m\u{1b}[0;32m\"x\"\u{1b}[0m\u{1b}[1;39m]\u{1b}[0m\u{1b}[1;39m}\u{1b}[0m",
  )
  assert_eq(
    render_result(
      @json.parse("{\"a\":false}"),
      false,
      false,
      false,
      None,
      false,
      Some(palette),
    ),
    "\u{1b}[1;39m{\u{1b}[0m\n  \u{1b}[1;34m\"a\"\u{1b}[0m\u{1b}[1;39m:\u{1b}[0m \u{1b}[0;39mfalse\u{1b}[0m\n\u{1b}[1;39m}\u{1b}[0m",
  )
  assert_eq(
    render_result(
      Json::string("raw\n"),
      true,
      false,
      false,
      None,
      false,
      Some(palette),
    ),
    "raw\n",
  )
  assert_eq(
    render_json(@json.parse("[1,{}]"), false, 0, false, Some(palette)),
    "\u{1b}[1;39m[\u{1b}[0m\u{1b}[0;39m1\u{1b}[0m\u{1b}[1;39m,\u{1b}[0m\u{1b}[1;39m{}\u{1b}[0m\u{1b}[1;39m]\u{1b}[0m",
  )
  assert_eq(
    render_json(@json.parse("{\"a\":[1]}"), true, 2, true, None),
    "{\n\t\"a\": [\n\t\t1\n\t]\n}",
  )
  assert_eq(
    render_json(@json.parse("[1,2]"), true, 0, false, None),
    "[\n1,\n2\n]",
  )
}

///|
test "jq palettes accept partial and empty slots and reject invalid input atomically" {
  assert_eq(parse_colors(None), (default_colors(), true))
  assert_eq(parse_colors(Some("")), (default_colors(), true))
  let (partial, valid) = parse_colors(Some("31:32:"))
  assert_true(valid)
  assert_eq(partial[0], "\u{1b}[31m")
  assert_eq(partial[1], "\u{1b}[32m")
  assert_eq(partial[2], default_colors()[2])
  assert_eq(parse_colors(Some(":")).0[0], "\u{1b}[m")
  assert_eq(parse_colors(Some("31:bad")), (default_colors(), false))
  assert_eq(parse_colors(Some("31:\u{1b}[m")), (default_colors(), false))
  let (full, accepted) = parse_colors(Some("1:2:3:4:5:6:7:8:ignored"))
  assert_true(accepted)
  assert_eq(full[7], "\u{1b}[8m")
  assert_eq(
    render_json(Json::null(), false, 0, false, Some(partial)),
    "\u{1b}[31mnull\u{1b}[0m",
  )
}
