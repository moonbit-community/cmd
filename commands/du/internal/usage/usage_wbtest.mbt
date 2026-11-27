///|
async test "an unreadable directory contributes its inode and reports the failed walk" {
  if @platform.is_windows() {
    return
  }
  let root = @fs.tmpdir(prefix="du-directory-count")
  defer @fs.remove(root, recursive=true)
  let locked = root + "/locked"
  @fs.mkdir(locked, permission=0)
  defer @fs.remove(locked)
  if @fs.can_read(locked) {
    return
  }
  let errors = []
  let rows = []
  let total = measure(
    [root],
    detail=All,
    follow=false,
    count_links=false,
    inodes=true,
    emit=(path, n) => rows.push((path, n)),
    report=(path, error) => {
      assert_true(error is UnreadableDirectory)
      errors.push(path)
    },
  )
  assert_eq(errors, [locked])
  assert_eq(rows, [(locked, 1L), (root, 2L)])
  assert_eq(total, 2L)
}
