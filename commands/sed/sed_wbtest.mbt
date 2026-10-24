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
async test "sed numeric regex and inverted address ranges" {
  let runtime : Runtime = { previous: None, missing_newline: false, }
  let commands = compile("2,3p; /a/,/a/!p", false)
  assert_false(commands[0].selected(sed_address_input(1), "a", runtime))
  assert_true(commands[0].selected(sed_address_input(2), "b", runtime))
  assert_true(commands[0].selected(sed_address_input(3), "c", runtime))
  assert_false(commands[0].selected(sed_address_input(4), "d", runtime))
  assert_false(commands[1].selected(sed_address_input(1), "a", runtime))
  assert_false(commands[1].selected(sed_address_input(2), "b", runtime))
  assert_false(commands[1].selected(sed_address_input(3), "a", runtime))
  assert_true(commands[1].selected(sed_address_input(4), "c", runtime))
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
  let newline = compile("s/a\\nb/X/", false)
  guard newline[0].action is Substitute(Explicit(pattern), _, _, _, _) else {
    fail("missing newline expression")
  }
  assert_eq(substitute(pattern, "a\nb", "X", false, 0), ("X", true))
  let escaped = compile("s/a\\\\nb/X/", false)
  guard escaped[0].action is Substitute(Explicit(pattern), _, _, _, _) else {
    fail("missing escaped-backslash expression")
  }
  assert_eq(substitute(pattern, "a\\nb", "X", false, 0), ("X", true))
}

///|
async test "sed empty patterns use the last executed regular expression" {
  let commands = compile("3s/x/y/; 2s//z/", false)
  guard commands[1].action is Substitute(Previous, _, _, _, _) else {
    fail("empty pattern was bound statically")
  }
  let runtime : Runtime = {
    previous: Some(@bytere.compile("a")),
    missing_newline: false,
  }
  assert_eq(Previous.resolve(runtime).find("a").unwrap().end, 1)
  let range = compile("/a/,3p", false)[0]
  assert_true(range.selected(sed_address_input(1), "a", runtime))
  runtime.previous = Some(@bytere.compile("b"))
  assert_true(range.selected(sed_address_input(2), "c", runtime))
  assert_true(Previous.resolve(runtime).find("b") is Some(_))
}

///|
test "sed hold append preserves independent record termination" {
  let empty = Space::{ text: "", terminated: true, }
  let unterminated = Space::{ text: "one", terminated: false, }
  let from_hold = unterminated.append(empty)
  assert_eq(from_hold.text, "one\n")
  assert_true(from_hold.terminated)
  let into_hold = empty.append(unterminated)
  assert_eq(into_hold.text, "\none")
  assert_false(into_hold.terminated)
}

///|
test "sed labels resolve final definitions before any execution" {
  let commands = compile("b end;:end;p;:end;d", false)
  guard commands[0].action is Jump(target) else { fail("missing branch") }
  assert_eq(target, 3)
  let no_label = compile("b;t;T", false)
  assert_true(no_label[0].action is Jump(3))
  assert_true(no_label[1].action is TestJump(3, true))
  assert_true(no_label[2].action is TestJump(3, false))
  let missing = try {
    ignore(compile("p;b absent", false))
    false
  } catch {
    SedLabelError(message) => message.contains("absent")
    _ => false
  }
  assert_true(missing)
}

///|
test "sed text lines preserve escaped newlines and distinguish empty text" {
  let commands = compile("a\\\nleft\\\nright\ni\\\n\nc\\", false)
  guard commands[0].action is Append(text) else { fail("missing append") }
  assert_eq(text, "left\nright\n")
  guard commands[1].action is Insert(text) else { fail("missing insert") }
  assert_eq(text, "\n")
  guard commands[2].action is Change(text) else { fail("missing change") }
  assert_eq(text, "")
  let final_escape = compile("a\\\nword\\", false)
  guard final_escape[0].action is Append(text) else { fail("missing text") }
  assert_eq(text, "word\n")
}

///|
async test "sed numeric ranges close permanently when branch or input skips endpoints" {
  let runtime : Runtime = { previous: None, missing_newline: false, }
  let range = compile("2,3p", false)[0]
  // A previous N or a branch can make the first visit occur at line three.
  assert_true(range.selected(sed_address_input(3), "c", runtime))
  assert_false(range.selected(sed_address_input(4), "d", runtime))
  assert_false(range.selected(sed_address_input(3), "c", runtime))
  let skipped = compile("2,3p", false)[0]
  assert_false(skipped.selected(sed_address_input(4), "d", runtime))
  let backwards = compile("2,1p", false)[0]
  assert_true(backwards.selected(sed_address_input(2), "b", runtime))
  assert_false(backwards.selected(sed_address_input(3), "c", runtime))
}

///|
fn sed_address_input(number : Int32) -> Input {
  {
    paths: [],
    index: 0,
    path: "",
    file: None,
    reader: None,
    buffer: b"",
    position: 0,
    number,
    status: 0,
  }
}

///|
async test "sed inactive last address does not inspect later input" {
  let input = sed_address_input(1)
  input.paths.push("sed-must-not-open-unselected-input")
  let runtime : Runtime = { previous: None, missing_newline: false, }
  let range = compile("/never/,$p", false)[0]
  assert_false(range.selected(input, "one", runtime))
  assert_eq(input.index, 0)
  assert_eq(input.status, 0)
}

///|
async test "sed read failure retains an already buffered partial record" {
  let reader = @io.MemoryReader(_ => fail("injected input failure"))
  defer reader.close()
  let input = sed_address_input(0)
  input.reader = Some((reader : &@io.Reader))
  input.buffer = b"partial"
  let line = input.next().unwrap()
  assert_eq(line.data, b"partial")
  assert_false(line.terminated)
  assert_eq(input.status, 2)
  assert_eq(input.next(), None)
}

///|
test "sed group compilation rejects incomplete programs and allows adjacent ends" {
  ignore(compile("1{2!{s/a/X/};p}", false))
  for script in ["p;{p", "p;}", ":;p", "1:label"] {
    let rejected = try {
      ignore(compile(script, false))
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
}
