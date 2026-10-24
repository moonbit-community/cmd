///|
test "xargs delimiter parsing follows byte escape and signed char provider rules" {
  for
    (text, value) in [
      (",", 44),
      ("\\nX", 10),
      ("\\0", 0),
      ("\\141", 97),
      ("\\xFF", 255),
      ("\\x", 0),
    ] {
    assert_eq(delimiter_byte(text), value)
  }
  for text in ["", "ab", "\u00e9", "\\q", "\\x100", "\\400", "\\x20tail"] {
    try delimiter_byte(text) catch {
      XargsError(_) => ()
    } noraise {
      _ => fail("invalid delimiter")
    }
  }
  let items = delimited_items(b"a,,b,", 44)
  assert_eq(items.map(item => item.value), ["a", "", "b"])
  assert_eq(items.map(item => item.size), [2L, 1L, 2L])
  assert_eq(delimited_items(b"'a'\\b", 44).map(item => item.value), ["'a'\\b"])
  assert_eq(delimited_items(b"a\xc3\xa9b", 255).map(item => item.value), [
    "a\u00e9b",
  ])
}

///|
test "xargs byte items preserve raw length and reject untransportable argv prefixes" {
  let item = input_item(b"a\x00\xfftail"[:])
  assert_eq(item.value, "a")
  assert_eq(item.size, 8L)
  try delimited_items(b"a\xffb", 255) catch {
    error => assert_true(error is ArgvBytesBoundary)
  } noraise {
    _ => fail("invalid UTF-8 argv must not be replaced")
  }
  assert_eq(command_size(["cmd"], ["\u00e9"]), 7)
}

///|
async test "xargs confirmations use a separate reader and preserve C locale yes rules" {
  let input = @io.MemoryReader(writer => writer.write("yep\n no\nY\n"))
  defer input.close()
  assert_true(confirm_batch(input, "command", ["one"]))
  assert_false(confirm_batch(input, "command", ["two"]))
  assert_true(confirm_batch(input, "command", ["three"]))
  try confirm_batch(input, "command", []) catch {
    error => assert_true(error is XargsError(_))
  } noraise {
    _ => fail("confirmation EOF must fail")
  }
}
