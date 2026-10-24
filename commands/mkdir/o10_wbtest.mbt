///|
test "mkdir symbolic evaluation follows directory X copied classes and operations" {
  for
    (mode, mask, expected) in [
      ("u=rwx,go=rx", 0o077, 0o755),
      ("a=rwX", 0o077, 0o777),
      ("u=rw,g=u,o=g", 0o077, 0o666),
      ("=rx", 0o077, 0o500),
      ("+w", 0o077, 0o777),
      ("-w", 0o077, 0o577),
      ("u+s,g+s,a+t", 0o022, 0o7777),
      ("u=rwx-w+x,g=u,o=g", 0o077, 0o555),
    ] {
    assert_eq(adjust_mode(compile_mode(mode), mask), expected)
  }
}

///|
test "mkdir rejects only symbolic results that require an unknown umask" {
  assert_eq(symbolic_mode("+w"), 0o777)
  assert_eq(symbolic_mode("="), 0)
  assert_eq(symbolic_mode("=r,a=rx"), 0o555)
  for mode in ["=rx", "-w", "+r-w"] {
    try symbolic_mode(mode) catch {
      error => assert_true(error is NeedsUmask)
    } noraise {
      _ => fail("mode depends on process umask")
    }
  }
  for mode in ["", "u+z", "u=rw,", "a=ur", "u", "u+r,z=w"] {
    try compile_mode(mode) catch {
      error => assert_true(error is InvalidMode)
    } noraise {
      _ => fail("invalid symbolic mode")
    }
  }
}
