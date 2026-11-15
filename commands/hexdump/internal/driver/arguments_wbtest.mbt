///|
test "hexdump color normalization preserves argument order" {
  assert_eq(normalized_args(["-CLalways", "-e", "\"%c\"", "--", "-L"][:]), [
    "-C", "--color=always", "-e", "\"%c\"", "--", "-L",
  ])
}
