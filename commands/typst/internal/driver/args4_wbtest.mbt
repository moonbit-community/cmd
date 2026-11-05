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
