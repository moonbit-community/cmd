///|
async test "sed byte rejection updates executed pattern history without decoding a miss" {
  let output : SedOutput = { bytes: [], calls: 0, budget: 100, }
  let runtime = sed_test_runtime(output)
  let space = Space::from_bytes(b"plain", true)
  let commands = @program.compile("/absent/!p", false)
  assert_true(commands[0].selected(sed_address_input(1), space, runtime))
  assert_true(space.decoded is None)
  assert_true(PatternRef::Previous.resolve(runtime).pattern.is_match("absent"))
  assert_false(PatternRef::Previous.resolve(runtime).matches(space))
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
      @program.compile(script, false),
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
        @program.compile(script, false),
        sed_test_input(reader, runtime),
        true,
        runtime,
      )
    catch {
      @program.SedError(actual) => assert_eq(actual, message)
      error => fail("unexpected error: \{error}")
    } noraise {
      _ => fail("byte rejection must not bypass an error")
    }
    assert_eq(output.bytes.length(), 0)
  }
}
