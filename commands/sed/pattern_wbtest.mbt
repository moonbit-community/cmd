///|
test "sed byte rejection preserves the full matcher for nullable alternatives captures and binary data" {
  for extended in [false, true] {
    let sources = [
      "", "^", "$", "ab", "^ab$", "ab.*cd", "a*b*", "a?b?", "[ab]+", "a\nb", "\u00ff\u0000",
    ]
    sources.append(
      if extended {
        ["(ab|cd)", "(ab)?", "(ab)+", "(ab)\\1", "a{0,2}"]
      } else {
        ["\\(ab\\)\\1", "ab\\|cd", "\\(ab\\)\\?", "a\\{0,2\\}"]
      },
    )
    for source in sources {
      let pattern = @bytere.compile(source, extended~)
      let prepared = PreparedPattern::new(pattern)
      for
        bytes in [
          b"", b"a", b"ab", b"cd", b"abab", b"abZZcd", b"a\nb", b"\xff\x00", b"\x00\xff",
        ] {
        let expected = pattern.is_match(@bytere.text(bytes[:]))
        let space = Space::from_bytes(bytes[:], false)
        if prepared.rejects(space) {
          assert_false(expected, msg=source)
        }
        assert_eq(prepared.matches(space), expected, msg=source)
        let text_space = Space::from_text(@bytere.text(bytes[:]), false)
        assert_false(prepared.rejects(text_space))
        assert_eq(prepared.matches(text_space), expected, msg=source)
      }
    }
  }
}

///|
async test "sed byte rejection updates executed pattern history without decoding a miss" {
  let output : SedOutput = { bytes: [], calls: 0, budget: 100, }
  let runtime = sed_test_runtime(output)
  let space = Space::from_bytes(b"plain", true)
  let commands = compile("/absent/!p", false)
  assert_true(commands[0].selected(sed_address_input(1), space, runtime))
  assert_true(space.decoded is None)
  assert_true(Previous.resolve(runtime).pattern.is_match("absent"))
  assert_false(Previous.resolve(runtime).matches(space))
  assert_true(space.decoded is None)
}

///|
async test "sed byte rejection preserves previous regex errors branches captures and multiline spaces" {
  for
    (script, data, expected) in [
      ("/zz/!s//Q/;p", b"ab\nzz\n", b"ab\nzz\n"),
      ("s/ab/xy/;s/absent/Q/;t yes;d;:yes;p", b"ab\ncd\n", b"xy\n"),
      ("s/absent/Q/;T yes;d;:yes;p", b"ab\n", b"ab\n"),
      ("s/ab/ab/;t yes;d;:yes;p", b"ab\n", b"ab\n"),
      ("s/\\(ab\\)/[\\1]/g;p", b"ab00ab\n", b"[ab]00[ab]\n"),
      ("s/a*/X/g;p", b"bb\n", b"XbXbX\n"),
      ("N;s/a\\nb/Z/;p", b"a\nb\n", b"Z\n"),
    ] {
    let reader = @io.MemoryReader(writer => writer.write(data))
    defer reader.close()
    let output : SedOutput = { bytes: [], calls: 0, budget: 100, }
    let runtime = sed_test_runtime(output)
    execute(
      compile(script, false),
      sed_test_input(reader, runtime),
      true,
      runtime,
    )
    assert_eq(Bytes::from_array(output.bytes), expected, msg=script)
  }
  for
    (script, message) in [
      ("2s/zz/Q/;s//Q/", "no previous regular expression"),
      ("/zz/!s//\\1/", "invalid replacement backreference"),
    ] {
    let reader = @io.MemoryReader(writer => writer.write(b"ab\n"))
    defer reader.close()
    let output : SedOutput = { bytes: [], calls: 0, budget: 100, }
    let runtime = sed_test_runtime(output)
    try
      execute(
        compile(script, false),
        sed_test_input(reader, runtime),
        true,
        runtime,
      )
    catch {
      SedError(actual) => assert_eq(actual, message)
      error => fail("unexpected error: \{error}")
    } noraise {
      _ => fail("byte rejection must not bypass an error")
    }
    assert_eq(output.bytes.length(), 0)
  }
}
