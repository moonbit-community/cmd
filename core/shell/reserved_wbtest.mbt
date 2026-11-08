///|
test "unmatched reserved words reject a complete command list before execution" {
  for word in ["then", "else", "elif", "fi", "do", "done", "in", "esac"] {
    for
      source in [
        word,
        "printf prefix; " + word,
        "true && " + word,
        "true | " + word,
      ] {
      try parse_input(source) catch {
        InvalidSyntax(message) =>
          assert_eq(message, "unexpected reserved word '" + word + "'")
        issue => raise issue
      } noraise {
        _ => fail("unmatched reserved word became an external command")
      }
    }
    // Quoted words and arguments are ordinary words, not grammar delimiters.
    ignore(parse_input("'" + word + "'"))
    ignore(parse_input("printf '%s' " + word))
    ignore(parse_input("VALUE=" + word))
    ignore(parse_input("VALUE=prefix " + word))
    ignore(parse_input("> marker " + word))
  }
}

///|
async test "reserved word syntax failure preserves session state and permits recovery" {
  let output : CaptureBuffer = { bytes: [], }
  let session = Session::new(
    output~,
    env={ "KEPT": "before" },
    interactive=true,
  )
  try session.feed("KEPT=wrong; printf prefix; then") catch {
    ShellError(message) => assert_eq(message, "unexpected reserved word 'then'")
    error => raise error
  } noraise {
    _ => fail("syntax error was accepted")
  }
  assert_eq(output.bytes.length(), 0)
  assert_eq(session.context.env.get("KEPT"), Some("before"))
  assert_eq(session.feed("printf '%s|%s' \"$?\" \"$KEPT\""), Completed(0))
  assert_eq(@utf8.decode(Bytes::from_array(output.bytes)), "2|before")
}

///|
test "compound lists require commands and logical operators require right operands" {
  for
    source in [
      "if true && then printf wrong; fi", "while true || do break; done", "(true &&)",
      "if true; then fi", "if ; then printf wrong; fi", "for x in a; do done", "if false; then :; else fi",
      "foo() { }", "()", "{ }", "while ; do :; done",
    ] {
    try parse_input(source) catch {
      InvalidSyntax(_) => ()
      issue => raise issue
    } noraise {
      _ => fail("invalid compound list was accepted: " + source)
    }
  }
  for
    source in [
      "", "case x in x) ;; esac", "case x in esac", "for x in; do :; done",
    ] {
    ignore(parse_input(source))
  }
}

///|
async test "EOF executes complete continued commands but rejects incomplete grammar" {
  assert_eq(run("\\\n"), 0)
  for
    (source, expected) in [
      ("\\\n", ""),
      ("printf kept\\\n", "kept"),
      ("printf 'quoted\\\nline'\\\n", "quoted\\\nline"),
    ] {
    let output : CaptureBuffer = { bytes: [], }
    let session = Session::new(output~)
    assert_eq(session.feed(source), NeedMoreInput)
    assert_eq(session.finish(), Exit(0))
    assert_eq(@utf8.decode(Bytes::from_array(output.bytes)), expected)
  }
  for
    (source, reason) in [
      ("if true; then \\\n", "incomplete: unexpected empty command list"),
      ("printf 'unclosed\\\n", "unterminated quote"),
      ("cat <<EOF\nbody\\\n", "unterminated here-document"),
    ] {
    let session = Session::new()
    assert_eq(session.feed(source), NeedMoreInput)
    try session.finish() catch {
      ShellError(message) =>
        assert_eq(message, "unexpected end of input: " + reason)
      error => raise error
    } noraise {
      _ => fail("EOF accepted incomplete grammar")
    }
    assert_eq(session.finish(), Exit(2))
  }
}

///|
async test "finished sessions retain status and never execute another feed" {
  for (source, status) in [("true\\\n", 0), ("false\\\n", 1), ("exit 7\\\n", 7)] {
    let output : CaptureBuffer = { bytes: [], }
    let session = Session::new(output~)
    assert_eq(session.feed(source), NeedMoreInput)
    assert_eq(session.finish(), Exit(status))
    assert_eq(session.feed("printf wrong"), Exit(status))
    assert_eq(session.finish(), Exit(status))
    assert_eq(output.bytes.length(), 0)
  }
}
