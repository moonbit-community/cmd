///|
test "mount traversal follows the visible parent through an overmount" {
  let mounts = parse(
    "1 0 0:1 / / rw - base disk rw\n2 1 0:2 / /a/b rw - old older rw\n3 1 0:3 / /a rw - new newer rw\n4 3 0:4 / /a/c\\040d rw - nested child rw\n",
  )
  assert_eq(locate(mounts, "/a/b/file").source, "newer")
  assert_eq(locate(mounts, "/a/c d/file").source, "child")
  assert_eq(locate(mounts, "/abc").target, "/")
}
