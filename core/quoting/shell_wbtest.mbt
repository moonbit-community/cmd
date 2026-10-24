///|
test "shell escaping preserves C profile byte groups" {
  assert_eq(shell_escape(b"plain"[:]), "plain")
  assert_eq(shell_escape(b"single'quote"[:]), "\"single'quote\"")
  assert_eq(shell_escape(b"a\nb"[:]), "'a'$'\\n''b'")
  assert_eq(shell_escape(b"\x00\xff"[:]), "''$'\\000\\377'")
}

///|
test "shell escaping supports forced and colon quoting" {
  assert_eq(shell_escape(b"plain"[:], force=true), "'plain'")
  assert_eq(shell_escape(b"a:b"[:]), "a:b")
  assert_eq(shell_escape(b"a:b"[:], colon=true), "'a:b'")
  assert_eq(shell_escape(b""[:], force=true), "''")
}
