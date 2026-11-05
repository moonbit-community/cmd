///|
test "host error classification keeps Win32 and POSIX numbering separate" {
  assert_eq(host_error_kind(3, Windows), NotFound)
  assert_eq(host_error_kind(5, Windows), PermissionDenied)
  assert_eq(host_error_kind(183, Windows), AlreadyExists)
  assert_eq(host_error_kind(87, Windows), InvalidInput)
  assert_eq(host_error_kind(2, Linux), NotFound)
  assert_eq(host_error_kind(5, Linux), Other)
  assert_eq(host_error_kind(13, MacOs), PermissionDenied)
  assert_eq(host_error_kind(17, MacOs), AlreadyExists)
}
