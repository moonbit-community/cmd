///|
test "patch unified exact hunk applies to bytes for dry run or output stream" {
  let patch = b"--- a/file\n+++ b/file\n@@ -1,3 +1,3 @@\n one\n-two\n+TWO\n three\n"
  let files = parse_patch(patch)
  assert_eq(files.length(), 1)
  let output = apply_patch_bytes(b"one\ntwo\nthree\n", files[0].hunks, false)
  assert_eq(output, b"one\nTWO\nthree\n")
}

///|
test "patch reverse and no final newline preserve records" {
  let patch = b"--- old\n+++ new\n@@ -1 +1 @@\n-old\n+new\n\\ No newline at end of file\n"
  let files = parse_patch(patch)
  assert_eq(apply_patch_bytes(b"old\n", files[0].hunks, false), b"new")
  assert_eq(apply_patch_bytes(b"new", files[0].hunks, true), b"old\n")
}

///|
test "patch context format converts to common hunk model" {
  let patch = b"*** old\n--- new\n***************\n*** 1,3 ****\n  one\n! two\n  three\n--- 1,3 ----\n  one\n! TWO\n  three\n"
  let files = parse_patch(patch)
  assert_eq(files.length(), 1)
  assert_eq(
    apply_patch_bytes(b"one\ntwo\nthree\n", files[0].hunks, false),
    b"one\nTWO\nthree\n",
  )
}

///|
test "patch rejects malformed, fuzz and unsafe paths" {
  try parse_patch(b"--- a\n+++ b\n@@ -1 +1 @@\n-old\n") catch {
    PatchError(message) => assert_true(message.contains("incomplete"))
    err => fail("unexpected parse error: \{err}")
  } noraise {
    _ => fail("expected malformed patch")
  }
  try stripped("../../escape", Some(0)) catch {
    PatchError(message) => assert_true(message.contains("unsafe"))
  } noraise {
    _ => fail("expected unsafe path")
  }
  assert_eq(stripped("a/b/file", Some(1)), "b/file")
  try
    parse_patch(
      b"old mode 100644\nnew mode 100755\n*** old\n--- new\n***************\n*** 1 ****\n! old\n--- 1 ----\n! new\n",
    )
  catch {
    PatchError(message) => assert_true(message.contains("mode"))
    err => fail("unexpected metadata parse error: \{err}")
  } noraise {
    _ => fail("expected unsupported mode metadata")
  }
}

///|
test "patch hunk mismatch has no partial output" {
  let patch = parse_patch(b"--- a\n+++ b\n@@ -1 +1 @@\n-old\n+new\n")
  try apply_patch_bytes(b"other\n", patch[0].hunks, false) catch {
    HunkMismatch(number, position) => {
      assert_eq(number, 1)
      assert_eq(position, 1)
    }
  } noraise {
    _ => fail("expected hunk mismatch")
  }
}
