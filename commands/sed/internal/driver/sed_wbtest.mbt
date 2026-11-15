///|
async test "sed numeric regex and inverted address ranges" {
  let runtime = sed_test_runtime(@stdio.stdout)
  let commands = @program.compile("2,3p; /a/,/a/!p", false)
  assert_false(
    commands[0].selected(
      sed_address_input(1),
      Space::from_text("a", true),
      runtime,
    ),
  )
  assert_true(
    commands[0].selected(
      sed_address_input(2),
      Space::from_text("b", true),
      runtime,
    ),
  )
  assert_true(
    commands[0].selected(
      sed_address_input(3),
      Space::from_text("c", true),
      runtime,
    ),
  )
  assert_false(
    commands[0].selected(
      sed_address_input(4),
      Space::from_text("d", true),
      runtime,
    ),
  )
  assert_false(
    commands[1].selected(
      sed_address_input(1),
      Space::from_text("a", true),
      runtime,
    ),
  )
  assert_false(
    commands[1].selected(
      sed_address_input(2),
      Space::from_text("b", true),
      runtime,
    ),
  )
  assert_false(
    commands[1].selected(
      sed_address_input(3),
      Space::from_text("a", true),
      runtime,
    ),
  )
  assert_true(
    commands[1].selected(
      sed_address_input(4),
      Space::from_text("c", true),
      runtime,
    ),
  )
}

///|
async test "sed empty patterns use the last executed regular expression" {
  let commands = @program.compile("3s/x/y/; 2s//z/", false)
  guard commands[1].action is Substitute(Previous, _, _, _, _) else {
    fail("empty pattern was bound statically")
  }
  let runtime : Runtime = {
    previous: Some(test_pattern("a")),
    missing_newline: false,
    output: @stream.BlockWriter::new(@stdio.stdout),
  }
  assert_eq(
    PatternRef::Previous.resolve(runtime).pattern.find("a").unwrap().end,
    1,
  )
  let range = @program.compile("/a/,3p", false)[0]
  assert_true(
    range.selected(sed_address_input(1), Space::from_text("a", true), runtime),
  )
  runtime.previous = Some(test_pattern("b"))
  assert_true(
    range.selected(sed_address_input(2), Space::from_text("c", true), runtime),
  )
  assert_true(
    PatternRef::Previous.resolve(runtime).pattern.find("b") is Some(_),
  )
}

///|
test "sed output records preserve separators termination empty and byte values" {
  assert_eq(output_record("one", true, false), b"one\n")
  assert_eq(output_record("one", false, false), b"one")
  assert_eq(output_record("one", true, true), b"\none\n")
  assert_eq(output_record("one", false, true), b"\none")
  assert_eq(output_record("", false, false), b"")
  assert_eq(output_record("", true, false), b"\n")
  assert_eq(output_record("", false, true), b"\n")
  assert_eq(output_record("", true, true), b"\n\n")
  assert_eq(output_record("\u00ff\u0000\n", true, true), b"\n\xff\x00\n\n")
}

///|
async test "sed numeric ranges close permanently when branch or input skips endpoints" {
  let runtime = sed_test_runtime(@stdio.stdout)
  let range = @program.compile("2,3p", false)[0]
  // A previous N or a branch can make the first visit occur at line three.
  assert_true(
    range.selected(sed_address_input(3), Space::from_text("c", true), runtime),
  )
  assert_false(
    range.selected(sed_address_input(4), Space::from_text("d", true), runtime),
  )
  assert_false(
    range.selected(sed_address_input(3), Space::from_text("c", true), runtime),
  )
  let skipped = @program.compile("2,3p", false)[0]
  assert_false(
    skipped.selected(sed_address_input(4), Space::from_text("d", true), runtime),
  )
  let backwards = @program.compile("2,1p", false)[0]
  assert_true(
    backwards.selected(
      sed_address_input(2),
      Space::from_text("b", true),
      runtime,
    ),
  )
  assert_false(
    backwards.selected(
      sed_address_input(3),
      Space::from_text("c", true),
      runtime,
    ),
  )
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
    output: @stream.BlockWriter::new(@stdio.stdout),
  }
}

///|
async test "sed inactive last address does not inspect later input" {
  let input = sed_address_input(1)
  input.paths.push("sed-must-not-open-unselected-input")
  let runtime = sed_test_runtime(@stdio.stdout)
  let range = @program.compile("/never/,$p", false)[0]
  assert_false(range.selected(input, Space::from_text("one", true), runtime))
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
  assert_true(input.next() is None)
}

///|
fn test_pattern(source : String) -> PreparedPattern raise {
  match @program.compile("/" + source + "/p", false)[0].first {
    Some(Search(Explicit(pattern))) => pattern
    _ => fail("missing compiled pattern")
  }
}
