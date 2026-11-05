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
