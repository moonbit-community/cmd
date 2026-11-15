///|
test "comparison key applies fields then characters" {
  assert_eq(comparison_key(b"1 xa", 1, 1, Some(1), false), b"x")
  assert_eq(comparison_key(b"1 xA", 1, 1, None, true), b"xa")
}

///|
test "zero comparison width makes all selected suffixes equal" {
  assert_eq(comparison_key(b"left", 0, 0, Some(0), false), b"")
}

///|
async fn uniq_output(
  input : Bytes,
  mode : OutputMode,
  only_unique~ : Bool = false,
  only_repeated~ : Bool = false,
  ignore_case~ : Bool = false,
  delimiter~ : Byte = b'\n',
) -> Bytes {
  let reader = @io.MemoryReader(writer => writer.write(input))
  defer reader.close()
  let output = @io.MemoryReader(writer => {
    process_reader(
      reader,
      false,
      only_repeated,
      only_unique,
      ignore_case,
      0,
      0,
      None,
      delimiter,
      mode,
      writer~,
    )
  })
  defer output.close()
  output.read_all().binary()
}

///|
async test "uniq all repeated preserves members and unique skips only the last" {
  let input = b"A\na\nA\nb\nc\nc"
  assert_eq(
    uniq_output(input, AllRepeated(NoSeparator), ignore_case=true),
    b"A\na\nA\nc\nc\n",
  )
  assert_eq(
    uniq_output(input, AllRepeated(Separate), ignore_case=true),
    b"A\na\nA\n\nc\nc\n",
  )
  assert_eq(
    uniq_output(input, AllRepeated(Prepend), ignore_case=true),
    b"\nA\na\nA\n\nc\nc\n",
  )
  assert_eq(
    uniq_output(
      input,
      AllRepeated(NoSeparator),
      only_unique=true,
      ignore_case=true,
    ),
    b"A\na\nc\n",
  )
  assert_eq(
    uniq_output(
      input,
      AllRepeated(NoSeparator),
      only_unique=true,
      only_repeated=true,
      ignore_case=true,
    ),
    b"A\na\nc\n",
  )
  assert_eq(
    uniq_output(input, Summarize, only_unique=true, only_repeated=true),
    b"",
  )
}

///|
async test "uniq group methods delimit singleton repeated empty and NUL records" {
  let input = b"a\na\nb\nc\nc"
  for
    (separator, expected) in [
      (Separate, b"a\na\n\nb\n\nc\nc\n"),
      (Prepend, b"\na\na\n\nb\n\nc\nc\n"),
      (Append, b"a\na\n\nb\n\nc\nc\n\n"),
      (Both, b"\na\na\n\nb\n\nc\nc\n\n"),
    ] {
    assert_eq(uniq_output(input, EveryGroup(separator)), expected)
    assert_eq(uniq_output(b"", EveryGroup(separator)), b"")
  }
  assert_eq(
    uniq_output(b"a\x00a\x00b", EveryGroup(Both), delimiter=b'\x00'),
    b"\x00a\x00a\x00\x00b\x00\x00",
  )
  assert_eq(uniq_output(b"\n\nx\n", EveryGroup(Separate)), b"\n\n\nx\n")
}

///|
test "uniq optional methods reset in order and reject conflicting selection" {
  assert_true(output_mode(parse_args(["-D"])) is AllRepeated(NoSeparator))
  assert_true(
    output_mode(parse_args(["--all-repeated=sep"])) is AllRepeated(Separate),
  )
  assert_true(
    output_mode(parse_args(["--all-repeated=prepend", "-D"]))
    is AllRepeated(NoSeparator),
  )
  assert_true(
    output_mode(parse_args(["--all-repeated=prepend", "--all-repeated"]))
    is AllRepeated(NoSeparator),
  )
  assert_true(
    output_mode(parse_args(["-D", "--all-repeated=prepend"]))
    is AllRepeated(Prepend),
  )
  assert_true(output_mode(parse_args(["--group"])) is EveryGroup(Separate))
  assert_true(
    output_mode(parse_args(["--group=pre", "--group=both"])) is EveryGroup(Both),
  )
  assert_eq(parse_args(["--", "--group"]).operands, ["--group"])
  assert_eq(parse_args(["--", "--all-repeated-method=prepend"]).operands, [
    "--all-repeated-method=prepend",
  ])
  assert_eq(
    parse_args(["-f", "--all-repeated"]).last_value("skip-fields"),
    Some("--all-repeated"),
  )
  assert_eq(
    parse_args(["-Df", "--group"]).last_value("skip-fields"),
    Some("--group"),
  )
  assert_eq(
    parse_args(["--skip-chars", "--all-repeated-method=prepend"]).last_value(
      "skip-chars",
    ),
    Some("--all-repeated-method=prepend"),
  )
  for
    args in [
      ["--all-repeated-method=prepend"],
      ["--all-repeated-method", "prepend"],
    ] {
    try parse_args(args) catch {
      @cli.CliError(option~, message~, ..) => {
        assert_eq(option, "all-repeated-method")
        assert_eq(message, "unknown option")
      }
    } noraise {
      _ => fail("internal uniq option must not be accepted")
    }
  }
  for
    (args, diagnostic) in [
      (["--group", "-c"], "mutually exclusive"),
      (["-d", "--group"], "mutually exclusive"),
      (["--group", "-u"], "mutually exclusive"),
      (["-D", "--group"], "mutually exclusive"),
      (["-cD"], "repeat counts"),
      (["-Dc"], "repeat counts"),
      (["--group="], "ambiguous argument"),
      (["--group=none"], "invalid argument"),
      (["--all-repeated=both"], "invalid argument"),
      (["--all-repeated=", "-D"], "ambiguous argument"),
    ] {
    let parsed = parse_args(args)
    try output_mode(parsed) catch {
      CliError(message) => assert_true(message.contains(diagnostic))
    } noraise {
      _ => fail("expected invalid uniq output mode")
    }
  }
}
