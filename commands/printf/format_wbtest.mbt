///|
test "shell quote preserves GNU C byte and apostrophe choices" {
  for
    (input, expected) in [
      ("", "''"),
      ("safe_word-1", "safe_word-1"),
      ("two words", "'two words'"),
      ("single'quote", "\"single'quote\""),
      ("double\"quote", "'double\"quote'"),
      ("line\nnext", "'line'$'\\n''next'"),
      ("tab\there", "'tab'$'\\t''here'"),
      ("é", "''$'\\303\\251'"),
    ] {
    assert_eq(shell_quote(input), expected)
  }
}

///|
test "hex and quote conversions retain missing reuse and fatal output prefix" {
  let context : Ctx = {
    out: [],
    args: ["0", "two words", "1.5", "nan", "-nan", "-nan"],
    arg_index: 0,
    messages: [],
    exit_error: false,
    stop: false,
    fatal: None,
  }
  scan_format(context, "[%a][%q][%a][%+a][% a][%A]".iter().collect())
  assert_eq(
    Bytes::from_array(context.out),
    b"[0x0p+0]['two words'][0xcp-3][+nan][-nan][-NAN]",
  )
  assert_true(context.fatal is None)
  let invalid : Ctx = {
    out: [],
    args: ["unused"],
    arg_index: 0,
    messages: [],
    exit_error: false,
    stop: false,
    fatal: None,
  }
  scan_format(invalid, "prefix:%10q".iter().collect())
  assert_eq(Bytes::from_array(invalid.out), b"prefix:")
  assert_eq(
    invalid.fatal,
    Some("printf: %10q: invalid conversion specification"),
  )
}
