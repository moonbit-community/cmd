///|
test "lexer preserves quoting and recognizes control operators" {
  let tokens = lex("echo 'a b' \"$HOME\" && false || true")
  inspect(tokens.length(), content="7")
  assert_true(tokens[3] is AndIf)
  assert_true(tokens[5] is OrIf)
}

///|
async test "parser rejects unterminated quotes and recognizes substitution" {
  try lex("echo 'open") catch {
    ShellError(message) => inspect(message, content="unterminated quote")
  } noraise {
    _ => fail("expected quote error")
  }
  let tokens = lex("echo $(date)")
  assert_true(tokens.length() == 2)
}

///|
async test "command substitution captures output" {
  let status = run("printf '%s' \"$(printf inner)\"")
  assert_eq(status, 0)
}

///|
async test "expansion distinguishes quoted and unquoted variables" {
  let context : Context = {
    env: { "VALUE": "one two" },
    positional: ["left", "right"],
    name: "demo",
    cwd: "/",
    last_status: 7,
    exited: false,
    exit_status: 0,
    capture: None,
    functions: Map([]),
    errexit: false,
    nounset: false,
    return_status: None,
    break_loop: false,
  }
  let jobs = parse("run $VALUE \"$VALUE\" $0 $1 $# $?")
  let prepared = match jobs[0].statement {
    Pipeline(pipeline) => prepare(pipeline.commands[0], context)
    _ => fail("expected pipeline")
  }
  debug_inspect(
    prepared.argv,
    content="[\"run\", \"one\", \"two\", \"one two\", \"demo\", \"left\", \"2\", \"7\"]",
  )
}

///|
async test "leading assignments update command environment" {
  let context : Context = {
    env: { "BASE": "kept" },
    positional: [],
    name: "sh",
    cwd: "/",
    last_status: 0,
    exited: false,
    exit_status: 0,
    capture: None,
    functions: Map([]),
    errexit: false,
    nounset: false,
    return_status: None,
    break_loop: false,
  }
  let jobs = parse("NEW=value command argument")
  let prepared = match jobs[0].statement {
    Pipeline(pipeline) => prepare(pipeline.commands[0], context)
    _ => fail("expected pipeline")
  }
  debug_inspect(prepared.argv, content="[\"command\", \"argument\"]")
  debug_inspect(prepared.env.get("NEW"), content="Some(\"value\")")
  debug_inspect(prepared.env.get("BASE"), content="Some(\"kept\")")
}
