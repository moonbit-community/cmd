///|
test "env split strings preserve quotes expansions and argument splice tokens" {
  let environment = Map([("KEEP", "one two"), ("EMPTY", "")])
  assert_eq(
    split_string(
      "a ${KEEP} ${EMPTY} ${MISSING} \"${MISSING}\" '${KEEP}'", environment,
    ),
    ["a", "one two", "", "", "${KEEP}"],
  )
  assert_eq(split_string("one\\_two \"three\\_four\" '\\_'", environment), [
    "one", "two", "three four", "\\_",
  ])
  assert_eq(split_string("'a\\'b' '' \"\"", environment), ["a'b", "", ""])
  assert_eq(split_string("one # ignored", environment), ["one"])
  assert_eq(split_string("one#two \\cignored", environment), ["one#two"])
  assert_eq(
    split_string("'$(uname)' '*?[a]' ';' '|' '\u0060echo\u0060'", environment),
    ["$(uname)", "*?[a]", ";", "|", "\u0060echo\u0060"],
  )
  assert_eq(split_string("-i -S next", environment), ["-i", "-S", "next"])
}

///|
test "env split errors reject unsupported expansions escapes and quotes" {
  for
    text in [
      "$KEEP", "${1BAD}", "${KEEP", "\\q", "trailing\\", "\"\\c\"", "'unclosed",
    ] {
    try split_string(text, Map([])) catch {
      SplitError(_) => ()
    } noraise {
      _ => fail("invalid -S text must fail")
    }
  }
}
