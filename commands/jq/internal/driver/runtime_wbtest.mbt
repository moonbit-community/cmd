///|
test "shared input requests suspend before reading" {
  let state = @ast.evaluate(
    parse_filter("input, inputs"),
    null,
    @ast.Env::new(),
  )
  guard state.step() is Request(Input, advance) else {
    fail("expected first input request")
  }
  guard advance(Ok(Some(Json(1)))).step() is Yield(value, next) else {
    fail("expected first value")
  }
  assert_eq(value, Json(1))
  guard next.step() is Request(Input, advance) else {
    fail("expected inputs request")
  }
  assert_true(advance(Ok(None)).step() is Done)
}

///|
test "module parsing retains dependencies and namespace references" {
  let program = @parser.parse_program(
    "module {name:\"main\"}; import \"values\" as values; values::get",
  )
  assert_eq(program.metadata, @json.parse("{\"name\":\"main\"}"))
  assert_eq(program.dependencies.length(), 1)
  assert_eq(program.dependencies[0].path, "values")
  assert_eq(program.dependencies[0].binding, Some("values"))
  assert_true(program.body is At(FunctionCall("values::get", []), _))
}

///|
test "compile validation rejects reachable unresolved names before evaluation" {
  let scope = @ast.Env::new()
  for
    query in [
      "input, missing", "if false then missing else 1 end", "def f:$x; 1 as $x|f",
    ] {
    let program = @parser.parse_program(query)
    try scope.validate(program.body) catch {
      @ast.Undefined(_, _, _, _) => ()
    } noraise {
      _ => fail("undefined lexical reference accepted")
    }
  }
  scope.validate(@parser.parse_program("def unused: missing; 1").body)
}

///|
priv suberror OutputFailure {
  OutputFailure
}

///|
test "module home uses Windows fallbacks only when HOME is absent" {
  let environment : Map[String, String] = {
    "HOME": "home",
    "USERPROFILE": "profile",
    "HOMEDRIVE": "C:",
    "HOMEPATH": "\\user",
  }
  let lookup = name => environment.get(name)
  assert_eq(module_home(true, lookup), Some("home"))
  environment.remove("HOME")
  assert_eq(module_home(false, lookup), None)
  assert_eq(module_home(true, lookup), Some("profile"))
  environment.remove("USERPROFILE")
  assert_eq(module_home(true, lookup), Some("C:\\user"))
  environment.remove("HOMEDRIVE")
  assert_eq(module_home(true, lookup), Some("\\user"))
  environment.remove("HOMEPATH")
  assert_eq(module_home(true, lookup), None)
}

///|
async test "failed output neither replays nor consumes the following input" {
  let mut reads = 0
  let outputs : Array[Json] = []
  let stream = @ast.evaluate(parse_filter("1,input"), null, @ast.Env::new())
  try
    consume(
      stream,
      _ => {
        reads += 1
        Ok(Some(Json(2)))
      },
      value => {
        outputs.push(value)
        raise OutputFailure
      },
    )
  catch {
    OutputFailure => ()
    error => raise error
  } noraise {
    _ => fail("output failure was lost")
  }
  assert_eq(reads, 0)
  assert_eq(outputs, [Json(1)])
}

///|
test "library parsing rejects executable bodies" {
  for source in ["1", "def f:1; f", "def f:1; ."] {
    try @parser.parse_program(source, library=true) catch {
      _ => ()
    } noraise {
      _ => fail("library body accepted")
    }
  }
  ignore(@parser.parse_program("def f:1;", library=true))
}

///|
async test "module metadata reports invalid syntax and returns null" {
  let directory = @tempio.Directory::new(prefix="jq-metadata-")
  defer directory.close()
  @fs.write_file(directory.path() + "/bad.jq", "1")
  guard parse_cli(["-L", directory.path(), "-n", "."]) is Run(options) else {
    fail("module options")
  }
  let modules = Modules::new(options)
  let diagnostics : Array[String] = []
  assert_eq(
    modules.metadata("bad", message => diagnostics.push(message)),
    Json::null(),
  )
  assert_eq(diagnostics, [
    "moonjq: " +
    @parser.InvalidSyntax("A module may contain only imports and definitions").to_string() +
    "\n",
  ])
}

///|
async test "logs preserve each operand's unterminated final record" {
  let directory = @tempio.Directory::new(prefix="jq-logs-")
  defer directory.close()
  let a = directory.path() + "/a"
  let b = directory.path() + "/b"
  let stdin = @io.MemoryReader(_ => ())
  defer stdin.close()
  for
    (left, right, expected) in [
      ("1", "2\n", [Json(1), Json(2)]),
      (
        "{\"a\":1}",
        "{\"b\":2}\n",
        [@json.parse("{\"a\":1}"), @json.parse("{\"b\":2}")],
      ),
    ] {
    @fs.write_file(a, left)
    @fs.write_file(b, right)
    guard parse_cli(["-lc", ".", a, b]) is Run(options) else {
      fail("logs options")
    }
    let cursor = InputCursor::new(options, stdin, _ => {
      fail("unexpected file error")
    })
    defer cursor.sources.close()
    assert_eq(cursor.next(), Some(expected[0]))
    assert_eq(cursor.next(), Some(expected[1]))
    assert_eq(cursor.next(), None)
  }
  @fs.write_file(a, b"\xff\n1\n")
  guard parse_cli(["-lc", ".", a]) is Run(options) else { fail("logs options") }
  let cursor = InputCursor::new(options, stdin, _ => {
    fail("unexpected file error")
  })
  defer cursor.sources.close()
  try cursor.next() catch {
    @utf8.Malformed(_) => ()
    error => raise error
  } noraise {
    _ => fail("logs must reject malformed UTF-8 before later records")
  }
}
