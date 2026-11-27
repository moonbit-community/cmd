///|
test "closed symbolic assignments compile without reading old mode" {
  assert_eq(parse_symbolic_mode("a=rw,u+x"), 0o766)
  assert_eq(parse_symbolic_mode("u=rw,g=u,o="), 0o660)
  assert_eq(parse_symbolic_mode("a=x,g+X,o-x,u+s,g+s,o+t"), 0o7110)
  assert_eq(parse_symbolic_mode("a=rw+X"), 0o666)
  assert_eq(parse_symbolic_mode("a=rwx,g-u"), 0o707)
  assert_eq(parse_symbolic_mode("a-rwxst"), 0)
  assert_eq(parse_symbolic_mode("a=rwx"), 0o777)
  assert_eq(parse_symbolic_mode("u=rw,g=r,o="), 0o640)
  assert_eq(parse_symbolic_mode("u=r,g=rw,o=x"), 0o461)
}

///|
test "symbolic chmod rejects incremental and incomplete forms" {
  try parse_symbolic_mode("u+x") catch {
    _ => ()
  } noraise {
    _ => fail("incremental mode must be rejected")
  }
  try parse_symbolic_mode("u=rw") catch {
    _ => ()
  } noraise {
    _ => fail("incomplete assignment must be rejected")
  }
}
