///|
test "sed substitution captures nth occurrence global and empty matches" {
  let letters = @bytere.compile("[a-z]")
  assert_eq(substitute(letters, "abc", "X", false, 2), ("aXc", true))
  assert_eq(substitute(letters, "abc", "X", true, 2), ("aXX", true))
  let capture = @bytere.compile("a\\(b\\)")
  assert_eq(substitute(capture, "ab", "[\\1:&]", false, 0), ("[b:ab]", true))
  assert_eq(
    substitute(@bytere.compile("a*"), "aaab", "X", true, 0),
    ("XbX", true),
  )
  assert_eq(
    substitute(@bytere.compile("x*"), "ab", "X", true, 0),
    ("XaXbX", true),
  )
}

///|
test "sed numeric regex and inverted address ranges" {
  let runtime : Runtime = { previous: None, missing_newline: false, }
  let commands = compile("2,3p; /a/,/a/!p", false)
  assert_false(commands[0].selected(1, false, "a", runtime))
  assert_true(commands[0].selected(2, false, "b", runtime))
  assert_true(commands[0].selected(3, false, "c", runtime))
  assert_false(commands[0].selected(4, true, "d", runtime))
  assert_false(commands[1].selected(1, false, "a", runtime))
  assert_false(commands[1].selected(2, false, "b", runtime))
  assert_false(commands[1].selected(3, false, "a", runtime))
  assert_true(commands[1].selected(4, true, "c", runtime))
}

///|
test "sed delimiter escaping keeps regex and replacement meaning" {
  let commands = compile("s.a\\.b.X.; s&X&\\&&", false)
  guard commands[0].action
    is Substitute(Explicit(pattern), replacement, _, _, _) else {
    fail("missing substitution")
  }
  assert_eq(
    substitute(pattern, "a.b axb", replacement, false, 0),
    ("X axb", true),
  )
  guard commands[1].action
    is Substitute(Explicit(pattern), replacement, _, _, _) else {
    fail("missing substitution")
  }
  assert_eq(substitute(pattern, "X", replacement, false, 0), ("&", true))
}

///|
test "sed empty patterns use the last executed regular expression" {
  let commands = compile("3s/x/y/; 2s//z/", false)
  guard commands[1].action is Substitute(Previous, _, _, _, _) else {
    fail("empty pattern was bound statically")
  }
  let runtime : Runtime = {
    previous: Some(@bytere.compile("a")),
    missing_newline: false,
  }
  assert_eq(Previous.resolve(runtime).find("a").unwrap().end, 1)
}
