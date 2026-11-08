///|
async test "loop counts accept only C whitespace decimal positive Int32 values" {
  for name in ["break", "continue"] {
    for value in ["0x1", "1_0", "2147483648"] {
      let output : ShellTestOutput = { bytes: [], }
      let errors : ShellTestOutput = { bytes: [], }
      let session = Session::new(env={}, output~, error=errors)
      assert_eq(
        session.feed(
          "for x in once; do " + name + " '" + value + "'; done; printf after",
        ),
        Exit(2),
      )
      assert_eq(output.text(), "")
      assert_eq(
        errors.text(),
        "sh: " + name + ": positive loop count required\n",
      )
    }
    for value in [" 1 ", "\u000b1\u000c", "+01"] {
      assert_eq(
        capture(
          "for x in once; do " + name + " '" + value + "'; done; printf after",
        ),
        (0, "after"),
      )
    }
  }
}

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
    ShellError(message) =>
      assert_eq(
        message, "unexpected end of input: incomplete: unexpected empty command list",
      )
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

///|
async test "loop counts propagate through exactly the requested nesting levels" {
  for
    (source, expected) in [
      (
        "for a in 1 2; do for b in 3 4; do printf '%s%s' $a $b; break 2; done; printf wrong; done; printf end",
        "13end",
      ),
      (
        "for a in 1 2; do for b in 3 4; do printf '%s%s' $a $b; continue 2; done; printf wrong; done; printf end",
        "1323end",
      ),
      (
        "for a in 1 2; do for b in 3 4; do printf '%s%s' $a $b; break 9; done; printf wrong; done; printf end",
        "13end",
      ),
      (
        "for a in 1 2; do while break 2; do printf wrong; done; printf wrong; done; printf end",
        "end",
      ),
      (
        "for a in 1 2; do while continue 2; do printf wrong; done; printf wrong; done; printf end",
        "end",
      ),
      ("break; printf '%s|' $?; continue; printf '%s' $?", "0|0"),
    ] {
    assert_eq(capture(source), (0, expected))
  }
}

///|
async test "invalid loop counts preserve earlier output and stop the script" {
  for source in ["break 0", "continue -1", "break invalid"] {
    let output : ShellTestOutput = { bytes: [], }
    let errors : ShellTestOutput = { bytes: [], }
    let session = Session::new(env={}, output~, error=errors)
    assert_eq(
      session.feed("printf before; " + source + "; printf wrong"),
      Exit(2),
    )
    assert_eq(output.text(), "before")
    assert_true(errors.text().has_suffix(": positive loop count required\n"))
  }
}
