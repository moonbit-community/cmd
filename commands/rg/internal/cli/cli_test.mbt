///|
test "escape" {
  inspect(@cli.escape(b""), content="")
  inspect(@cli.escape(b"\\"), content="\\\\")
  inspect(@cli.escape(b"\x00"), content="\\0")
  inspect(@cli.escape(b"\n"), content="\\n")
  inspect(@cli.escape(b"\t"), content="\\t")
  inspect(@cli.escape(b"\r"), content="\\r")
  inspect(@cli.escape(b"\\a"), content="\\\\a")
  inspect(@cli.escape(b"\\x"), content="\\\\x")
  inspect(@cli.escape(b"\\xz"), content="\\\\xz")
  inspect(@cli.escape(b"\\xzz"), content="\\\\xzz")
  inspect(@cli.escape(b"\xFF"), content="\\xFF")
  inspect(@cli.escape(b"a\xFFb"), content="a\\xFFb")
  inspect(@cli.escape(b"a b"), content="a\\x20b")
  inspect(@cli.escape(@utf8.encode("☃")), content="☃")
}

///|
test "unescape" {
  assert_eq(@cli.unescape(""), b"")
  assert_eq(@cli.unescape("\\\\"), b"\\")
  assert_eq(@cli.unescape("\\x00"), b"\x00")
  assert_eq(@cli.unescape("\\0"), b"\x00")
  assert_eq(@cli.unescape("\\n"), b"\n")
  assert_eq(@cli.unescape("\\t"), b"\t")
  assert_eq(@cli.unescape("\\r"), b"\r")
  assert_eq(@cli.unescape("\\a"), b"\\a")
  assert_eq(@cli.unescape("\\\\a"), b"\\a")
  assert_eq(@cli.unescape("\\x"), b"\\x")
  assert_eq(@cli.unescape("\\\\x"), b"\\x")
  assert_eq(@cli.unescape("\\xz"), b"\\xz")
  assert_eq(@cli.unescape("\\\\xz"), b"\\xz")
  assert_eq(@cli.unescape("\\xzz"), b"\\xzz")
  assert_eq(@cli.unescape("\\\\xzz"), b"\\xzz")
  assert_eq(@cli.unescape("a\\xFFz"), b"a\xFFz")
}

///|
test "human sizes" {
  inspect(@cli.parse_human_readable_size("123"), content="123")
  inspect(@cli.parse_human_readable_size("123K"), content="125952")
  inspect(@cli.parse_human_readable_size("123M"), content="128974848")
  inspect(@cli.parse_human_readable_size("123G"), content="132070244352")
  for s in ["", "a", "9999999999999999G", "123T"] {
    let r = try @cli.parse_human_readable_size(s) catch {
      _ => "err"
    } noraise {
      _ => "ok"
    }
    inspect(r, content="err")
  }
  let r = try @cli.parse_human_readable_size("12x") catch {
    e => e.to_string()
  } noraise {
    _ => "ok"
  }
  inspect(
    r,
    content="invalid format for size '12x', which should be a non-empty sequence of digits followed by an optional 'K', 'M' or 'G' suffix",
  )
}

///|
test "patterns" {
  let r = try @cli.pattern_from_bytes(b"abc\xFFxyz") catch {
    e => e.valid_up_to()
  } noraise {
    _ => -1
  }
  inspect(r, content="3")
  debug_inspect(
    @cli.patterns_from_bytes(b"foo\nbar\\s+foo\n[a-z]{3}\n"),
    content=(
      #|["foo", "bar\\s+foo", "[a-z]{3}"]
    ),
  )
}
