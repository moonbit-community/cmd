///|
test "sed substitution captures nth occurrence global and empty matches" {
  let letters = @bytere.compile("[a-z]")
  assert_eq(@program.substitute(letters, "abc", "X", false, 2), ("aXc", true))
  assert_eq(@program.substitute(letters, "abc", "X", true, 2), ("aXX", true))
  let capture = @bytere.compile("a\\(b\\)")
  assert_eq(
    @program.substitute(capture, "ab", "[\\1:&]", false, 0),
    ("[b:ab]", true),
  )
  assert_eq(
    @program.substitute(@bytere.compile("a*"), "aaab", "X", true, 0),
    ("XbX", true),
  )
  assert_eq(
    @program.substitute(@bytere.compile("x*"), "ab", "X", true, 0),
    ("XaXbX", true),
  )
}

///|
test "sed delimiter escaping keeps regex and replacement meaning" {
  let commands = @program.compile("s.a\\.b.X.; s&X&\\&&", false)
  guard commands[0].action
    is Substitute(Explicit(pattern), replacement, _, _, _) else {
    fail("missing substitution")
  }
  assert_eq(
    @program.substitute(pattern.pattern, "a.b axb", replacement, false, 0),
    ("X axb", true),
  )
  guard commands[1].action
    is Substitute(Explicit(pattern), replacement, _, _, _) else {
    fail("missing substitution")
  }
  assert_eq(
    @program.substitute(pattern.pattern, "X", replacement, false, 0),
    ("&", true),
  )
  let newline = @program.compile("s/a\\nb/X/", false)
  guard newline[0].action is Substitute(Explicit(pattern), _, _, _, _) else {
    fail("missing newline expression")
  }
  assert_eq(
    @program.substitute(pattern.pattern, "a\nb", "X", false, 0),
    ("X", true),
  )
  let escaped = @program.compile("s/a\\\\nb/X/", false)
  guard escaped[0].action is Substitute(Explicit(pattern), _, _, _, _) else {
    fail("missing escaped-backslash expression")
  }
  assert_eq(
    @program.substitute(pattern.pattern, "a\\nb", "X", false, 0),
    ("X", true),
  )
}

///|
test "sed hold append preserves independent record termination" {
  let empty = @program.Space::from_text("", true)
  let unterminated = @program.Space::from_text("one", false)
  let from_hold = unterminated.append(empty)
  assert_eq(from_hold.text(), "one\n")
  assert_true(from_hold.terminated)
  let into_hold = empty.append(unterminated)
  assert_eq(into_hold.text(), "\none")
  assert_false(into_hold.terminated)
}

///|
test "sed labels resolve final definitions before any execution" {
  let commands = @program.compile("b end;:end;p;:end;d", false)
  guard commands[0].action is Jump(target) else { fail("missing branch") }
  assert_eq(target, 3)
  let no_label = @program.compile("b;t;T", false)
  assert_true(no_label[0].action is Jump(3))
  assert_true(no_label[1].action is TestJump(3, true))
  assert_true(no_label[2].action is TestJump(3, false))
  let missing = try {
    ignore(@program.compile("p;b absent", false))
    false
  } catch {
    @program.SedLabelError(message) => message.contains("absent")
    _ => false
  }
  assert_true(missing)
}

///|
test "sed text lines preserve escaped newlines and distinguish empty text" {
  let commands = @program.compile("a\\\nleft\\\nright\ni\\\n\nc\\", false)
  guard commands[0].action is Append(text) else { fail("missing append") }
  assert_eq(text, "left\nright\n")
  guard commands[1].action is Insert(text) else { fail("missing insert") }
  assert_eq(text, "\n")
  guard commands[2].action is Change(text) else { fail("missing change") }
  assert_eq(text, "")
  let final_escape = @program.compile("a\\\nword\\", false)
  guard final_escape[0].action is Append(text) else { fail("missing text") }
  assert_eq(text, "word\n")
}

///|
test "sed group compilation rejects incomplete programs and allows adjacent ends" {
  ignore(@program.compile("1{2!{s/a/X/};p}", false))
  for script in ["p;{p", "p;}", ":;p", "1:label"] {
    let rejected = try {
      ignore(@program.compile(script, false))
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
}
