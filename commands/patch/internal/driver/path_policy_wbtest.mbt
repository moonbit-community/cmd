///|
test "patch rejects malformed metadata and unsafe paths" {
  try @hunks.parse_patch(b"--- a\n+++ b\n@@ -1 +1 @@\n-old\n") catch {
    @hunks.PatchError(message) => assert_true(message.contains("incomplete"))
    err => fail("unexpected parse error: \{err}")
  } noraise {
    _ => fail("expected malformed patch")
  }
  try stripped("../../escape", Some(0)) catch {
    @hunks.PatchError(message) => assert_true(message.contains("unsafe"))
  } noraise {
    _ => fail("expected unsafe path")
  }
  assert_eq(stripped("a/b/file", Some(1)), "b/file")
  try
    @hunks.parse_patch(
      b"old mode 100644\nnew mode 100755\n*** old\n--- new\n***************\n*** 1 ****\n! old\n--- 1 ----\n! new\n",
    )
  catch {
    @hunks.PatchError(message) => assert_true(message.contains("mode"))
    err => fail("unexpected metadata parse error: \{err}")
  } noraise {
    _ => fail("expected unsupported mode metadata")
  }
}
