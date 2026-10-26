///|
test "config basic" {
  let (args, errs) = @driver.parse_config_bytes(
    b"# Test\n--context=0\n   --smart-case\n-u\n\n   # --bar\n--foo\n",
  )
  inspect(errs.is_empty(), content="true")
  debug_inspect(
    args,
    content=(
      #|["--context=0", "--smart-case", "-u", "--foo"]
    ),
  )
}

///|
test "config error" {
  // Like ripgrep on Unix, arguments keep arbitrary bytes (as OS strings).
  let (args, errs) = @driver.parse_config_bytes(b"quux\nfoo\xFFbar\nbaz\n")
  assert_eq(args.length(), 3)
  assert_eq(args[0], "quux")
  assert_eq(@osstr.encode(args[1]), b"foo\xFFbar")
  assert_eq(args[2], "baz")
  inspect(errs.length(), content="0")
}

///|
test "config trims unicode whitespace" {
  let (args, _) = @driver.parse_config_bytes(
    b"\xC2\xA0--ignore-case\xC2\xA0\n\xE3\x80\x80# comment\n\xE2\x80\xA8\n",
  )
  debug_inspect(
    args,
    content=(
      #|["--ignore-case"]
    ),
  )
}
