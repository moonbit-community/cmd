///|
test "expand converts tabs at default and explicit stops" {
  assert_eq(expand_bytes(b"a\tb\n", false, [8]), b"a       b\n")
  assert_eq(expand_bytes(b"1234\tX\t\n", false, [4, 10]), b"1234      X \n")
}

///|
test "expand initial mode preserves tabs after content" {
  assert_eq(expand_bytes(b"\t\tA\tB\n", true, [8]), b"                A\tB\n")
}
