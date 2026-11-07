///|
async test "backticks preserve quoting trim newlines and isolate shell state" {
  assert_eq(
    capture(
      "a=parent; printf '<%s>' `printf 'one two\\n\\n'` \"`a=child; printf '%s  \\n\\n' \"$a\"`\"; printf '|%s' \"$a\"",
    ),
    (0, "<one><two><child  >|parent"),
  )
  assert_eq(capture("value=`false`; printf '%s' $?"), (0, "1"))
}

///|
async test "backticks support escaped nested substitution and literal backticks" {
  assert_eq(
    capture("printf '%s' `printf '%s' \\`printf nested\\``"),
    (0, "nested"),
  )
  assert_eq(capture("printf '%s' \"\\`literal\\`\""), (0, "`literal`"))
  assert_eq(capture("printf '%s' $(printf '%s' `printf ')'`)"), (0, ")"))
  assert_eq(
    capture("printf '%s' \"$(printf '%s' \"`printf ')'`\")\""),
    (0, ")"),
  )
}

///|
async test "arithmetic expands parameter and command substitutions before evaluation" {
  assert_eq(
    capture("b=3; printf '%s|%s' $((a=$b+$(printf 4))) \"$a\""),
    (0, "7|7"),
  )
  assert_eq(capture("printf '%s' $((`printf 3`+2))"), (0, "5"))
}

///|
async test "substitution scanner ignores comment syntax only at word boundaries" {
  assert_eq(capture("printf '%s' \"$(printf ok # <<EOF\n)\""), (0, "ok"))
  assert_eq(capture("printf '%s' $(# )\nprintf ok)"), (0, "ok"))
  assert_eq(capture("printf '%s' $(printf '%s' foo\\ #bar)"), (0, "foo#bar"))
  assert_eq(capture("printf '%s' \"$(printf '%s' foo#bar)\""), (0, "foo#bar"))
}

///|
async test "backtick sessions retain incomplete input and recover invalid nested syntax" {
  let output : ShellTestOutput = { bytes: [], }
  let errors : ShellTestOutput = { bytes: [], }
  let session = Session::new(env={}, output~, error=errors, interactive=true)
  assert_eq(session.feed("value=`printf"), NeedMoreInput)
  assert_eq(session.feed(" ready`; printf '%s' \"$value\"\n"), Completed(0))
  assert_eq(output.text(), "ready")
  assert_eq(session.feed("value=`)`\n"), Completed(2))
  assert_eq(session.feed("test \"$value\" = ready\n"), Completed(0))
  assert_eq(
    errors.text(),
    "sh: command substitution: unexpected closing token\n",
  )
}

///|
async test "command substitution uses case and group grammar for closing parentheses" {
  for
    script in [
      "case x in x) printf ok;; esac", "case x in (x) printf ok;; esac", "case x in x) printf ok; esac",
      "case x in x) case y in y) printf ok;; esac;; esac", " (case x in x) printf ok;; esac)",
      "case x in x) (printf ok);; esac", "f() { printf ok; }; f", "\\\n# )\nprintf ok",
    ] {
    let result = capture("printf '<%s>' \"$(" + script + ")\"") catch {
      ShellError(message) => fail(script + ": " + message)
      error => raise error
    }
    assert_eq(result, (0, "<ok>"))
  }
  let output : ShellTestOutput = { bytes: [], }
  let errors : ShellTestOutput = { bytes: [], }
  let session = Session::new(env={}, output~, error=errors, interactive=true)
  assert_eq(session.feed("value=$(case x in\n"), NeedMoreInput)
  assert_eq(session.feed("x)\n"), NeedMoreInput)
  assert_eq(session.feed("printf ok;;\n"), NeedMoreInput)
  assert_eq(session.feed("esac); printf '<%s>' \"$value\"\n"), Completed(0))
  assert_eq(output.text(), "<ok>")
  assert_eq(errors.text(), "")
}
