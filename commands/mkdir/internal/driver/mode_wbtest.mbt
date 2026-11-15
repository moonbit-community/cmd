///|
test "octal modes preserve prefixes leading zeroes and permission bounds" {
  for
    (text, expected) in [
      ("0", 0),
      ("000", 0),
      ("755", 0o755),
      ("0755", 0o755),
      ("0o755", 0o755),
      ("0O0755", 0o755),
      ("7777", 0o7777),
      ("0".repeat(1000) + "7777", 0o7777),
    ] {
    assert_eq(octal_mode(text), expected)
  }
  for
    text in [
      "",
      "0o",
      "0O",
      "8",
      "0o8",
      "800",
      "10000",
      "-1",
      "+755",
      " 755",
      "755 ",
      "7_55",
      "0x755",
      "７５５",
      "7\u{0}55",
      "7777777777777777777777777777777",
      "0".repeat(1000) + "10000",
      "u=rwx",
      "0o0O755",
    ] {
    try octal_mode(text) catch {
      error => assert_true(error is InvalidMode)
    } noraise {
      _ => fail("invalid octal mode: " + text)
    }
  }
}

///|
test "symbolic evaluation follows directory X copied classes and operations" {
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
test "rejects only symbolic results that require an unknown umask" {
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
test "creation capability preserves Linux and Darwin sticky staging" {
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
