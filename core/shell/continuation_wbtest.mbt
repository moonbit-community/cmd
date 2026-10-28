///|
async test "incomplete input resumes at each parser boundary" {
  for
    (first, rest) in [
      ("V='", "ready'; test \"$V\" = ready\n"),
      ("V=${M:-", "ready}; test \"$V\" = ready\n"),
      ("V=$(printf", " ready); test \"$V\" = ready\n"),
      ("f() {", " true; }; f\n"),
      ("true &&", " true\n"),
      ("true |", " true\n"),
      ("true \\", "\ntrue\n"),
      ("true <<EOF\n", "body\nEOF\n"),
    ] {
    let session = Session::new(env={})
    assert_eq(session.feed(first), NeedMoreInput)
    assert_eq(session.feed(rest), Completed(0))
    assert_eq(session.finish(), Exit(0))
  }
}

///|
async test "syntax errors preserve diagnostics and clear pending input" {
  for
    (source, expected) in [
      (")", "unexpected closing token"),
      ("true &", "background execution is not supported"),
      ("for 1 in x; do true; done", "for variable must be a name"),
    ] {
    let session = Session::new(env={})
    try session.feed(source) catch {
      ShellError(message) => assert_eq(message, expected)
      other => raise other
    } noraise {
      _ => fail("invalid syntax must fail")
    }
    assert_eq(session.context.last_status, 2)
    assert_eq(session.feed("true\n"), Completed(0))
  }
  let session = Session::new(env={})
  assert_eq(session.feed("if true; then\n"), NeedMoreInput)
  try session.finish() catch {
    ShellError(message) => assert_eq(message, "unexpected end of input")
    other => raise other
  } noraise {
    _ => fail("unfinished input must fail at EOF")
  }
}

///|
async test "nested loops consume only their own break and continue" {
  let (status, output) = capture(
    "for x in a b; do for y in 1 2; do if test $y = 1; then continue; fi; printf '%s%s' $x $y; break; printf wrong; done; printf .; done",
  )
  assert_eq((status, output), (0, "a2.b2."))
  let (status, output) = capture(
    "f() { for x in 1 2; do printf '%s' $x; return 7; done; printf wrong; }; f; printf ':%s' $?",
  )
  assert_eq((status, output), (0, "1:7"))
  let (status, output) = capture(
    "f() { for x in 1 2; do exit 9; done; }; f; printf wrong",
  )
  assert_eq((status, output), (9, ""))
}
