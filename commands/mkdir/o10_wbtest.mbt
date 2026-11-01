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
  for mask in [0o022, 0o077, 0o000] {
    for
      (mode, expected) in [
        ("+w", 0o777),
        ("+t", 0o1755),
        ("a=rwx,+t", 0o1777),
        ("+t,a=rwx", 0o777),
      ] {
      assert_eq(adjust_mode(compile_mode(mode), mask), expected)
    }
  }
}

///|
test "mkdir rejects only symbolic results that require an unknown umask" {
  assert_eq(symbolic_mode("+w"), 0o777)
  assert_eq(symbolic_mode("+t"), 0o1755)
  assert_eq(symbolic_mode("a=rwx,+t"), 0o1777)
  assert_eq(symbolic_mode("+t,a=rwx"), 0o777)
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

///|
test "mkdir creation capability preserves Linux and Darwin sticky staging" {
  for mask in [0o000, 0o022, 0o077] {
    assert_eq(
      adjust_mode(compile_mode("+t"), mask, creation_retains_sticky=true),
      0o1755,
    )
    assert_eq(
      adjust_mode(compile_mode("+t"), mask, creation_retains_sticky=false),
      0o1777,
    )
  }
  for creation_retains_sticky in [true, false] {
    for
      (mode, expected) in [
        ("a=rwx,+t", 0o1777),
        ("+t,a=rwx", 0o777),
        ("u+s,g+s,a+t", 0o7777),
        ("u=rwx,go=rx", 0o755),
      ] {
      assert_eq(symbolic_mode(mode, creation_retains_sticky~), expected)
    }
    for mode in ["=rx", "-w", "+r-w"] {
      try symbolic_mode(mode, creation_retains_sticky~) catch {
        error => assert_true(error is NeedsUmask)
      } noraise {
        _ => fail("creation capability must not hide umask dependence")
      }
    }
  }
}
