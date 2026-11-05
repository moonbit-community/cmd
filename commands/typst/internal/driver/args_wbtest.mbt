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
