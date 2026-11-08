///|
let heredoc_copy = "copy() { while IFS= read -r line; do printf '%s\\n' \"$line\"; done; }; "

///|
async test "unquoted heredocs expand without splitting globbing or quote removal" {
  let source = heredoc_copy +
    "value='a b'; copy <<EOF\n$value|$((2+3))|$(printf sub)|`printf old`\n\"quoted\" \\\"literal\\\" *.txt\nEOF\n"
  assert_eq(
    capture(source),
    (0, "a b|5|sub|old\n\"quoted\" \\\"literal\\\" *.txt\n"),
  )
}

///|
async test "quoted and escaped delimiters preserve literal heredoc bytes" {
  for delimiter in ["'EOF'", "\"EOF\"", "E\\OF", "E'O'F"] {
    let source = heredoc_copy +
      "value=changed; copy <<" +
      delimiter +
      "\n$value `printf wrong` $((1/0))\nEOF\n"
    assert_eq(capture(source), (0, "$value `printf wrong` $((1/0))\n"))
  }
  assert_eq(capture(heredoc_copy + "copy <<'#'\nbody\n#\n"), (0, "body\n"))
  try lex("true <<#\nbody\n#\n") catch {
    ShellError(message) =>
      assert_eq(message, "here-document requires a delimiter")
  } noraise {
    _ => fail("unquoted comment is not a delimiter")
  }
}

///|
async test "heredoc headers retain following commands and multiple input redirections" {
  assert_eq(
    capture(heredoc_copy + "copy <<EOF; printf tail\nbody\nEOF\n"),
    (0, "body\ntail"),
  )
  assert_eq(
    capture(
      heredoc_copy +
      "copy <<FIRST <<SECOND\nfirst\nFIRST\nsecond\nSECOND\nprintf end",
    ),
    (0, "second\nend"),
  )
}

///|
async test "tab stripping and unquoted line continuation precede delimiter matching" {
  assert_eq(
    capture(
      heredoc_copy + "value=beta; copy <<-EOF\n\talpha\n\t\t$value\n\tEOF\n",
    ),
    (0, "alpha\nbeta\n"),
  )
  assert_eq(
    capture(heredoc_copy + "copy <<EOF\none\\\ntwo\nEO\\\nF\nprintf end"),
    (0, "onetwo\nend"),
  )
  assert_eq(
    capture(heredoc_copy + "copy <<'EOF'\none\\\ntwo\nEOF\n"),
    (0, "one\\\ntwo\n"),
  )
}

///|
async test "heredoc session executes only after the complete delimiter arrives" {
  let output : ShellTestOutput = { bytes: [], }
  let errors : ShellTestOutput = { bytes: [], }
  let session = Session::new(env={}, output~, error=errors, interactive=true)
  assert_eq(
    session.feed(heredoc_copy + "copy <<EOF; printf done\n"),
    NeedMoreInput,
  )
  assert_eq(session.feed("data\n"), NeedMoreInput)
  assert_eq(output.text(), "")
  assert_eq(session.feed("EOF\n"), Completed(0))
  assert_eq(output.text(), "data\ndone")
  assert_eq(errors.text(), "")
}

///|
async test "heredoc delimiter continuation does not quote its body" {
  assert_eq(
    capture(heredoc_copy + "value=changed; copy <<E\\\nOF\n$value\nEOF\n"),
    (0, "changed\n"),
  )
  assert_eq(
    capture(heredoc_copy + "copy <<-EOF\n\tone\\\n\t\ttwo\nEOF\n"),
    (0, "one\t\ttwo\n"),
  )
}

///|
async test "command substitution skips heredoc body syntax when locating its end" {
  for (begin, end) in [("value=$(", ");"), ("value=\"$(", ")\";")] {
    let source = heredoc_copy +
      begin +
      "copy <<EOF\n)\nEOF\n" +
      end +
      " printf '<%s>' \"$value\""
    assert_eq(capture(source), (0, "<)>"))
  }
  assert_eq(
    capture(
      heredoc_copy +
      "value=$(copy <<'EOF'\n(\"')\nEOF\n); printf '<%s>' \"$value\"",
    ),
    (0, "<(\"')>"),
  )
  assert_eq(
    capture("printf '%s' \"$(printf '%s' \"$(printf ')')\")\""),
    (0, ")"),
  )
}

///|
async test "heredoc expansion failure distinguishes ordinary and special builtins" {
  for
    (command, expected, result) in [
      ("true", "beforeafter", Completed(0)),
      (":", "before", Exit(2)),
    ] {
    let output : ShellTestOutput = { bytes: [], }
    let errors : ShellTestOutput = { bytes: [], }
    let session = Session::new(env={}, output~, error=errors)
    assert_eq(
      session.feed(
        "set -u; printf before; " +
        command +
        " <<EOF\n$missing\nEOF\nprintf after",
      ),
      result,
    )
    assert_eq(output.text(), expected)
    assert_eq(errors.text(), "sh: parameter 'missing' is unset\n")
  }
}
