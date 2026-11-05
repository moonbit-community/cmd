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
