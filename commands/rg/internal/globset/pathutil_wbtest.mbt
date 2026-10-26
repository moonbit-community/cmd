// Tests ported from globset/src/pathutil.rs.

///|
test "name1" {
  assert_eq(file_name(b"foo/bar"), Some(b"bar"))
}

///|
test "name2" {
  assert_eq(file_name(b"foo"), Some(b"foo"))
}

///|
test "name3" {
  assert_eq(file_name(b"foo/.."), None)
}

///|
test "name4" {
  assert_eq(file_name(b""), None)
}

///|
test "ext1" {
  assert_eq(file_name_ext(b"foo.rs"), Some(b".rs"))
}

///|
test "ext2" {
  assert_eq(file_name_ext(b".rs"), Some(b".rs"))
}

///|
test "ext3" {
  assert_eq(file_name_ext(b"..rs"), Some(b".rs"))
}

///|
test "ext4" {
  assert_eq(file_name_ext(b""), None)
}

///|
test "ext5" {
  assert_eq(file_name_ext(b"foo"), None)
}

///|
test "normal1" {
  assert_eq(normalize_path(b"foo"), b"foo")
}

///|
test "normal2" {
  assert_eq(normalize_path(b"foo/bar"), b"foo/bar")
}

///|
test "normal3" {
  assert_eq(normalize_path(b"foo\\bar"), b"foo\\bar")
}

///|
test "normal4" {
  assert_eq(normalize_path(b"foo\\bar/baz"), b"foo\\bar/baz")
}
