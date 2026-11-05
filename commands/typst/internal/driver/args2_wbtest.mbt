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
