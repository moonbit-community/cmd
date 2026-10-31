///|
test "gzip compression levels default to six and follow the final option" {
  assert_eq(gzip_level(parse_gzip_args([])), 6)
  for level in 1..<=9 {
    assert_eq(gzip_level(parse_gzip_args(["-" + level.to_string()])), level)
  }
  for
    (args, expected) in [
      (["-1", "-9"], 9),
      (["-9", "-1"], 1),
      (["-cn19"], 9),
      (["-cn91"], 1),
      (["--fast", "--best"], 9),
      (["--best", "--fast"], 1),
      (["-9", "--fast"], 1),
      (["--fast", "-9"], 9),
      (["--best", "-2", "-6"], 6),
    ] {
    assert_eq(gzip_level(parse_gzip_args(args)), expected)
  }
}

///|
test "gzip level parsing preserves option terminators and decompression flags" {
  let parsed = parse_gzip_args(["--fast", "--", "-9", "--best", "--2", "-"])
  assert_eq(gzip_level(parsed), 1)
  assert_eq(parsed.operands, ["-9", "--best", "--2", "-"])
  let parsed = parse_gzip_args(["-d19", "--fast", "-t", "input.gz"])
  assert_true(parsed.contains("decompress"))
  assert_true(parsed.contains("test"))
  assert_eq(gzip_level(parsed), 1)
  assert_eq(parsed.operands, ["input.gz"])
}

///|
test "gzip level parsing rejects zero and unsupported long numeric forms" {
  for arg in ["-0", "-90", "--0", "--1", "--2", "--2=fast", "--9"] {
    try parse_gzip_args([arg]) catch {
      @args.CliError(kind=UnknownOption, ..) => ()
      _ => fail("expected unknown level option")
    } noraise {
      _ => fail("must reject unsupported level option: " + arg)
    }
  }
}
