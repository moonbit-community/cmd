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
