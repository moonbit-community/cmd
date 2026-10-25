///|
test "mktemp infers only the final X run and validates explicit suffixes" {
  let parsed = parse_template("prefixXXXX.tailXXX.end", None)
  assert_eq(
    (parsed.prefix, parsed.width, parsed.suffix),
    ("prefixXXXX.tail", 3, ".end"),
  )
  let value = parsed.fill()
  assert_true(value.has_prefix("prefixXXXX.tail") && value.has_suffix(".end"))
  let explicit = parse_template("name.XXX", Some(".log"))
  assert_eq(
    (explicit.prefix, explicit.width, explicit.suffix),
    ("name.", 3, ".log"),
  )
  for
    (template, suffix) in [
      ("name.XX.end", None),
      ("name.XXX.end", Some(".log")),
      ("name.XXX", Some("/bad")),
    ] {
    try parse_template(template, suffix) catch {
      MktempError(_) => ()
    } noraise {
      _ => fail("invalid templates must fail before creation")
    }
  }
}

///|
test "mktemp optional long tmpdir does not consume an operand or option value" {
  assert_eq(mktemp_args(["--tmpdir", "name.XXX", "--", "--tmpdir"]), [
    "--tmpdir=", "name.XXX", "--", "--tmpdir",
  ])
  assert_eq(mktemp_args(["-dp", "--tmpdir", "--suffix", "--tmpdir"]), [
    "-dp", "--tmpdir", "--suffix", "--tmpdir",
  ])
}
