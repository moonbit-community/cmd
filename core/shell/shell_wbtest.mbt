///|
test "lexer preserves quoting and recognizes control operators" {
  let tokens = lex("echo 'a b' \"$HOME\" && false || true")
  assert_eq(tokens.length(), 7)
  assert_true(tokens[3] is AndIf)
  assert_true(tokens[5] is OrIf)
}

///|
async test "quoted fields local variables arithmetic and substitution status" {
  let (status, output) = capture(
    "VALUE='one two'; printf '<%s>\\n' $VALUE \"$VALUE\"; printf '%s\\n' $((2+3*4)); X=$(false); printf '%s' $?",
  )
  assert_eq(status, 0)
  assert_eq(output, "<one>\n<two>\n<one two>\n14\n1")
}

///|
async test "substitution removes only trailing linefeeds and inherits functions" {
  let (status, output) = capture(
    "f() { printf 'ok  \\n\\n'; }; printf '<%s>' \"$(f)\"",
  )
  assert_eq(status, 0)
  assert_eq(output, "<ok  >")
}

///|
async test "variables export independently and assignment values do not split" {
  let session = Session::new(env={ "BASE": "kept" }, cwd="/")
  ignore(
    session.feed("VALUE='one two'; LOCAL=$VALUE; export BASE; export NEW=value"),
  )
  let jobs = parse("TEMP=$VALUE command $LOCAL")
  let prepared = match jobs[0].statement {
    Pipeline(pipeline) => prepare(pipeline.commands[0], session.context)
    _ => fail("expected pipeline")
  }
  assert_eq(prepared.argv, ["command", "one", "two"])
  assert_eq(prepared.env.get("LOCAL"), None)
  assert_eq(prepared.env.get("BASE"), Some("kept"))
  assert_eq(prepared.env.get("TEMP"), Some("one two"))
  assert_eq(prepared.env.get("NEW"), Some("value"))
}

///|
async test "parameter defaults quoted empty arguments and IFS" {
  let (status, output) = capture(
    "unset missing; printf '<%s>' \"${missing:-a b}\"; IFS=:; V='a:b'; printf '[%s]' $V; set --; printf 'end%s' \"$@\"",
  )
  assert_eq(status, 0)
  assert_eq(output, "<a b>[a][b]end")
}

///|
async test "default words preserve whitespace and assignment expansions are sequential" {
  let (status, output) = capture(
    "unset M; A=first B=$A; printf '<%s>|%s' \"${M:- a  b }\" \"$B\"; set -- unexpected; for x in; do printf wrong; done",
  )
  assert_eq(status, 0)
  assert_eq(output, "< a  b >|first")
}

///|
async test "pathname expansion respects quotes cwd and hidden entries" {
  let directory = @fs.tmpdir(prefix="cmd-sh-glob-")
  defer @fs.rmdir(directory, recursive=true)
  @fs.write_file(directory + "/a.txt", "a")
  @fs.write_file(directory + "/b.txt", "b")
  @fs.write_file(directory + "/.hidden.txt", "hidden")
  let (status, output) = capture(
    "printf '<%s>' *.txt '*.txt'; printf data > out; test -s out",
    cwd=directory,
  )
  assert_eq(status, 0)
  assert_eq(output, "<a.txt><b.txt><*.txt>")
  assert_eq(@fs.read_file(directory + "/out").text(), "data")
}

///|
async test "session holds incomplete source recovers syntax errors and preserves exit" {
  let session = Session::new(interactive=true)
  assert_eq(session.feed("if true; then\n"), NeedMoreInput)
  assert_eq(session.feed("VALUE=kept\nfi\n"), Completed(0))
  assert_eq(session.context.env.get("VALUE"), Some("kept"))
  try session.feed(")\n") catch {
    ShellError(_) => ()
    err => raise err
  } noraise {
    _ => fail("expected invalid closing token")
  }
  assert_eq(session.feed("true\n"), Completed(0))
  assert_eq(session.feed("exit 2\n"), Exit(2))
}

///|
async test "ENV scalar expansion preserves path characters without shell tokenization" {
  let session = Session::new(env={ "ROOT": "C:\\Users\\two  words" })
  assert_eq(
    expand_startup_path("C:\\Users\\two  words\\startup.rc", session.context),
    "C:\\Users\\two  words\\startup.rc",
  )
  assert_eq(
    expand_startup_path("${ROOT}/startup 'quoted';[*].rc", session.context),
    "C:\\Users\\two  words/startup 'quoted';[*].rc",
  )
  assert_eq(
    expand_startup_path("/tmp/\\$ROOT\\\\literal.rc", session.context),
    "/tmp/$ROOT\\literal.rc",
  )
  assert_eq(
    expand_startup_path("$(printf /tmp)/$((1+1)).rc", session.context),
    "/tmp/2.rc",
  )
}

///|
async test "interactive ENV loads a literal filename and script sessions ignore it" {
  let directory = @fs.tmpdir(prefix="cmd-sh-startup-")
  defer @fs.rmdir(directory, recursive=true)
  let basename = "startup ' two  spaces.rc"
  @fs.write_file(directory + "/" + basename, "STARTED=yes; PS1='loaded> '")
  let env = { "ENV": "${STARTUP_DIR}/" + basename, "STARTUP_DIR": directory }
  let session = Session::new(env~, interactive=true)
  session.load_startup()
  assert_eq(session.context.env.get("STARTED"), Some("yes"))
  assert_eq(session.prompt(), "loaded> ")
  let script = Session::new(env~)
  script.load_startup()
  assert_eq(script.context.env.get("STARTED"), None)
}

///|
async test "read consumes one line pipeline builtins preserve parent variables" {
  let (status, output) = capture(
    "VALUE=parent; printf 'child\\n' | read VALUE; printf '%s' \"$VALUE\"; printf hi | printf end",
  )
  assert_eq(status, 0)
  assert_eq(output, "parentend")
}

///|
async test "read protects escaped field separators" {
  let reader = @io.MemoryReader(writer => writer.write("a\\ b c\\ d\n"))
  defer reader.close()
  let session = Session::new(input=reader)
  assert_eq(session.feed("read FIRST REST"), Completed(0))
  assert_eq(session.context.env.get("FIRST"), Some("a b"))
  assert_eq(session.context.env.get("REST"), Some("c d"))
}

///|
async test "continue and test execute locally" {
  let (status, output) = capture(
    "for x in 1 2 3; do if test $x -eq 2; then continue; fi; printf '%s' $x; done",
  )
  assert_eq(status, 0)
  assert_eq(output, "13")
}

///|
async test "arithmetic errors never produce a successful empty expansion" {
  let (status, output) = capture("printf '%s' $((1/0)); printf wrong")
  assert_eq(status, 2)
  assert_eq(output, "")
}

///|
test "wildcards escape and bracket ranges" {
  assert_true(glob_match("a[0-9]?", "a1x"))
  assert_true(!glob_match("a[!0-9]", "a1"))
  assert_true(glob_match("\\*", "*"))
  assert_true(!glob_match("\\*", "anything"))
}
