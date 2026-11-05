///|
test "semver versions" {
  let check = (v : String) => {
    try parse_semver_version(v) catch {
      @kit.StrError(msg) => msg
    } noraise {
      _ => "ok"
    }
  }
  inspect(check("1.2.3-alpha.1+build.5"), content="ok")
  inspect(
    check("1.2.3-"),
    content="empty identifier segment in pre-release identifier",
  )
  inspect(
    check("1.2.3-01"),
    content="invalid leading zero in pre-release identifier",
  )
  inspect(check("1.2.3+01"), content="ok")
  inspect(
    check("1.2.3-a_b"),
    content="unexpected character '_' after pre-release identifier",
  )
  inspect(
    check("18446744073709551616.0.0"),
    content="value of major version number exceeds u64::MAX",
  )
  inspect(check("18446744073709551615.0.0"), content="ok")
  inspect(
    check("1..3"),
    content="unexpected character '.' while parsing minor version number",
  )
}

///|
test "help subcommand" {
  inspect(
    parse_result(["help", "compile", "extra"]),
    content="usage error: unrecognized subcommand 'extra' | typst compile [OPTIONS] <INPUT> [OUTPUT]",
  )
  inspect(
    parse_result(["help", "bogus"]),
    content="usage error: unrecognized subcommand 'bogus' | typst [OPTIONS] <COMMAND>",
  )
  inspect(parse_result(["help", "c"]), content="display")
}

///|
test "large page ranges" {
  inspect(
    parse_result(["compile", "a.typ", "--pages=2147483648-2147483647"]),
    content="invalid: invalid value '2147483648-2147483647' for '--pages <PAGES>': page range must end at a page after the start",
  )
  inspect(
    parse_result(["compile", "a.typ", "--pages=2147483647-99999999999"]),
    content=(
      #|other color=auto
    ),
  )
}

///|
test "large numbers" {
  inspect(
    parse_result(["compile", "--pages=2147483648", "--help"]),
    content="display",
  )
  inspect(
    parse_result(["compile", "--jobs", "99999999999999999999", "x"]),
    content="invalid: invalid value '99999999999999999999' for '--jobs <JOBS>': number too large to fit in target type",
  )
}
