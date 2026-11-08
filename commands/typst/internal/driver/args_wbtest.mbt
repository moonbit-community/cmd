///|
fn parse_result(argv : Array[String]) -> String {
  try parse_args(argv) catch {
    Usage(msg, usage) => "usage error: \{msg} | \{usage}"
    Invalid(msg) => "invalid: \{msg}"
    Display(_) => "display"
    MissingSubcommand => "missing subcommand"
  } noraise {
    args => {
      let color = match args.color {
        Auto => "auto"
        Always => "always"
        Never => "never"
      }
      match args.command {
        Eval(e) => "eval \{e.expression} color=\{color}"
        _ => "other color=\{color}"
      }
    }
  }
}

///|
test "color option" {
  inspect(
    parse_result(["--color", "never", "eval", "1"]),
    content="eval 1 color=never",
  )
  inspect(
    parse_result(["--color=always", "eval", "1"]),
    content="eval 1 color=always",
  )
  inspect(
    parse_result(["--color", "eval", "1"]),
    content="usage error: unrecognized subcommand '1' | typst [OPTIONS] <COMMAND>",
  )
  inspect(
    parse_result(["--color", "bogus", "eval", "1"]),
    content=(
      #|invalid: invalid value 'bogus' for '--color <COLOR>'
      #|  [possible values: auto, always, never]
    ),
  )
  inspect(
    parse_result(["--color", "", "eval", "1"]),
    content=(
      #|invalid: a value is required for '--color <COLOR>' but none was supplied
      #|  [possible values: auto, always, never]
    ),
  )
}

///|
test "empty values" {
  inspect(
    parse_result(["eval", "1", "--root", ""]),
    content="invalid: a value is required for '--root <DIR>' but none was supplied",
  )
  inspect(
    parse_result(["eval", "1", "--creation-timestamp="]),
    content="invalid: invalid value '' for '--creation-timestamp <UNIX_TIMESTAMP>': cannot parse integer from empty string",
  )
  inspect(
    parse_result(["eval", "1", "--in", ""]),
    content=(
      #|invalid: invalid value '' for '--in <IN>': error: one of the values isn't valid for an argument
      #|
    ),
  )
  inspect(
    parse_result(["eval", "1", "--features="]),
    content=(
      #|invalid: a value is required for '--features <FEATURES>' but none was supplied
      #|  [possible values: html, bundle, a11y-extras]
    ),
  )
  @env.set_env_var("SOURCE_DATE_EPOCH", "")
  let result = parse_result(["eval", "1"])
  @env.unset_env_var("SOURCE_DATE_EPOCH")
  inspect(
    result,
    content="invalid: invalid value '' for '--creation-timestamp <UNIX_TIMESTAMP>': cannot parse integer from empty string",
  )
  @env.set_env_var("TYPST_IGNORE_SYSTEM_FONTS", "yes")
  let result = parse_result(["eval", "1"])
  @env.unset_env_var("TYPST_IGNORE_SYSTEM_FONTS")
  inspect(
    result,
    content=(
      #|invalid: invalid value 'yes' for '--ignore-system-fonts'
      #|  [possible values: true, false]
    ),
  )
}

///|
test "color validation order" {
  let bogus =
    #|invalid: invalid value 'bogus' for '--color <COLOR>'
    #|  [possible values: auto, always, never]
  // Attached values are validated immediately.
  inspect(parse_result(["--color=bogus", "--help"]) == bogus, content="true")
  inspect(parse_result(["--color=bogus", "eval"]) == bogus, content="true")
  // Separate values: before the next option, at the end, or after a
  // following subcommand is parsed.
  inspect(parse_result(["--color", "bogus", "--help"]) == bogus, content="true")
  inspect(
    parse_result(["--color", "bogus", "eval", "--help"]),
    content="display",
  )
  inspect(
    parse_result(["--color", "bogus", "eval"]),
    content=(
      #|usage error: the following required arguments were not provided:
      #|  <EXPRESSION> | typst eval <EXPRESSION>
    ),
  )
  inspect(
    parse_result(["--color", "bogus", "eval", "1"]) == bogus,
    content="true",
  )
  inspect(
    parse_result(["--color", "eval"]),
    content=(
      #|invalid: invalid value 'eval' for '--color <COLOR>'
      #|  [possible values: auto, always, never]
    ),
  )
  inspect(
    parse_result(["--color"]),
    content=(
      #|invalid: a value is required for '--color <COLOR>' but none was supplied
      #|  [possible values: auto, always, never]
    ),
  )
}

///|
test "values are parsed when consumed" {
  inspect(
    parse_result(["eval", "1", "-j="]),
    content="invalid: invalid value '' for '--jobs <JOBS>': cannot parse integer from empty string",
  )
  inspect(
    parse_result(["eval", "-j=", "--help"]),
    content="invalid: invalid value '' for '--jobs <JOBS>': cannot parse integer from empty string",
  )
  inspect(
    parse_result(["compile", "-j="]),
    content="invalid: invalid value '' for '--jobs <JOBS>': cannot parse integer from empty string",
  )
  inspect(
    parse_result(["compile", "--ppi", "x", "--help"]),
    content="invalid: invalid value 'x' for '--ppi <PPI>': invalid float literal",
  )
  inspect(
    parse_result(["info", "-f=", "json"]),
    content=(
      #|invalid: a value is required for '--format <FORMAT>' but none was supplied
      #|  [possible values: json, yaml]
    ),
  )
}

///|
test "usage of unknown-argument errors" {
  inspect(
    parse_result(["fonts", "--variants", "--bogus"]),
    content=(
      #|usage error: unexpected argument '--bogus' found | typst fonts --variants
    ),
  )
  inspect(
    parse_result(["eval", "1", "--bogus"]),
    content=(
      #|usage error: unexpected argument '--bogus' found
      #|
      #|  tip: to pass '--bogus' as a value, use '-- --bogus' | typst eval <EXPRESSION>
    ),
  )
}

///|
test "pending values and clap's usage" {
  inspect(
    parse_result(["compile", "--ppi", "x", "--bogus"]),
    content=(
      #|usage error: unexpected argument '--bogus' found
      #|
      #|  tip: to pass '--bogus' as a value, use '-- --bogus' | typst compile --ppi <PPI> <INPUT> [OUTPUT]
    ),
  )
  inspect(
    parse_result(["compile", "--ppi", "x", "a.typ", "--bogus"]),
    content="invalid: invalid value 'x' for '--ppi <PPI>': invalid float literal",
  )
  inspect(
    parse_result(["--color", "--bogus"]),
    content="usage error: unexpected argument '--bogus' found | typst [OPTIONS] <COMMAND>",
  )
  inspect(
    parse_result(["--color=never", "--bogus"]),
    content="usage error: unexpected argument '--bogus' found | typst --color <COLOR> <COMMAND>",
  )
  inspect(
    parse_result(["fonts", "--variants", "--font-path", "x", "--bogus"]),
    content="usage error: unexpected argument '--bogus' found | typst fonts --variants --font-path <DIR>",
  )
  inspect(
    parse_result(["fonts", "--variants", "-Z"]),
    content="usage error: unexpected argument '-Z' found | typst fonts [OPTIONS]",
  )
  inspect(
    parse_result(["compile", "--ppi", "1", "--ppi", "2", "a.typ"]),
    content="usage error: the argument '--ppi <PPI>' cannot be used multiple times | typst compile [OPTIONS] <INPUT> [OUTPUT]",
  )
  inspect(
    parse_result(["compile", "--ppi", "1", "a.typ", "--ppi", "2", "--bogus"]),
    content=(
      #|usage error: unexpected argument '--bogus' found
      #|
      #|  tip: to pass '--bogus' as a value, use '-- --bogus' | typst compile <INPUT> [OUTPUT]
    ),
  )
}

///|
test "open takes any viewer" {
  let open = (argv : Array[String]) => {
    try parse_args(argv) catch {
      _ => "error"
    } noraise {
      args =>
        match args.command {
          Compile(c) => @debug.to_string(c.open)
          _ => "other"
        }
    }
  }
  inspect(
    open(["compile", "a.typ", "--open=Preview"]),
    content=(
      #|Some(Some("Preview"))
    ),
  )
  inspect(open(["compile", "a.typ", "--open"]), content="Some(None)")
  inspect(open(["compile", "a.typ"]), content="None")
}

///|
test "help and version take no values" {
  inspect(
    parse_result(["eval", "--help=foo"]),
    content="usage error: unexpected value 'foo' for '--help' found; no more were expected | typst eval --help <EXPRESSION>",
  )
  inspect(
    parse_result(["--version=foo"]),
    content="usage error: unexpected value 'foo' for '--version' found; no more were expected | typst --version <COMMAND>",
  )
}

///|
test "positionals are parsed when consumed" {
  inspect(
    parse_result(["compile", "", "--help"]),
    content=(
      #|invalid: invalid value '' for '<INPUT>': error: one of the values isn't valid for an argument
      #|
    ),
  )
}

///|
test "parent environment after the subcommand" {
  @env.set_env_var("TYPST_CERT", "")
  let help = parse_result(["eval", "--help"])
  let run = parse_result(["eval", "1"])
  @env.unset_env_var("TYPST_CERT")
  inspect(help, content="display")
  inspect(
    run,
    content="invalid: a value is required for '--cert <CERT>' but none was supplied",
  )
}

///|
test "excess and typed positionals" {
  inspect(
    parse_result(["eval", "1", "extra", "--help"]),
    content="usage error: unexpected argument 'extra' found | typst eval [OPTIONS] <EXPRESSION>",
  )
  inspect(
    parse_result(["completions", "bogus", "--help"]),
    content=(
      #|invalid: invalid value 'bogus' for '<SHELL>'
      #|  [possible values: bash, elvish, fish, nushell, powershell, zsh]
    ),
  )
  inspect(
    parse_result(["update", "1.2"]),
    content="invalid: invalid value '1.2' for '[VERSION]': unexpected end of input while parsing minor version number",
  )
  inspect(
    parse_result(["update", "1.2.3.4"]),
    content="invalid: invalid value '1.2.3.4' for '[VERSION]': unexpected character '.' after patch version number",
  )
  inspect(parse_result(["update", "1.2.3-beta+x"]), content="other color=auto")
}

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

///|
test "update conflicts" {
  inspect(
    parse_result(["update", "--revert", "--force"]),
    content="usage error: the argument '--revert' cannot be used with '--force' | typst update --revert [VERSION]",
  )
  inspect(
    parse_result(["update", "1.2.3", "--revert"]),
    content="usage error: the argument '[VERSION]' cannot be used with '--revert' | typst update <VERSION>",
  )
  inspect(
    parse_result(["update", "--revert", "--force", "1.2.3"]),
    content=(
      #|usage error: the argument '--revert' cannot be used with:
      #|  --force
      #|  [VERSION] | typst update --revert [VERSION]
    ),
  )
  inspect(
    parse_result(["update", "--force", "1.2.3"]),
    content="other color=auto",
  )
}
