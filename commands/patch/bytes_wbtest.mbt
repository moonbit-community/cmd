///|
test "patch byte domain preserves every unchanged byte and changed binary records" {
  let all = Bytes::makei(256, i => i.to_byte())
  assert_eq(apply_hunks(all, [], false, 2).data, all)
  for
    (before, after) in [
      (b"\x00\x80\xff\r", b"\xff\x00\x81"),
      (b"", b"\x00"),
      (b"\r", b""),
    ] {
    let patch = b"--- old\n+++ new\n@@ -1 +1 @@\n-" +
      before +
      b"\n+" +
      after +
      b"\n"
    let hunks = parse_patch(patch)[0].hunks
    assert_eq(apply_hunks(before + b"\n", hunks, false, 0).data, after + b"\n")
    assert_eq(apply_hunks(after + b"\n", hunks, true, 0).data, before + b"\n")
  }
}
