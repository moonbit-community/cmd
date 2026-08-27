///|
test "lexer preserves quoting and recognizes control operators" {
  let tokens = lex("echo 'a b' \"$HOME\" && false || true")
  inspect(tokens.length(), content="7")
  assert_true(tokens[3] is AndIf)
  assert_true(tokens[5] is OrIf)
}

///|
test "parser rejects unterminated quotes and unsupported substitution" {
  try lex("echo 'open") catch {
    ShellError(message) => inspect(message, content="unterminated quote")
  } noraise {
    _ => fail("expected quote error")
  }
  try lex("echo $(date)") catch {
    ShellError(message) =>
      inspect(message, content="command substitution is not supported")
  } noraise {
    _ => fail("expected command substitution error")
  }
}

///|
test "expansion distinguishes quoted and unquoted variables" {
  let context : Context = {
    env: { "VALUE": "one two" },
    positional: ["left", "right"],
    name: "demo",
    cwd: "/",
    last_status: 7,
    exited: false,
    exit_status: 0,
  }
  let jobs = parse("run $VALUE \"$VALUE\" $0 $1 $# $?")
  let prepared = prepare(jobs[0].pipeline.commands[0], context)
  debug_inspect(
    prepared.argv,
    content="[\"run\", \"one\", \"two\", \"one two\", \"demo\", \"left\", \"2\", \"7\"]",
  )
}

///|
test "leading assignments update command environment" {
  let context : Context = {
    env: { "BASE": "kept" },
    positional: [],
    name: "sh",
    cwd: "/",
    last_status: 0,
    exited: false,
    exit_status: 0,
  }
  let jobs = parse("NEW=value command argument")
  let prepared = prepare(jobs[0].pipeline.commands[0], context)
  debug_inspect(prepared.argv, content="[\"command\", \"argument\"]")
  debug_inspect(prepared.env.get("NEW"), content="Some(\"value\")")
  debug_inspect(prepared.env.get("BASE"), content="Some(\"kept\")")
}
