///|
test "unavailable system detection remains explicit" {
  assert_true(is_tty(0) is Unavailable(_))
  assert_true(is_tty(1) is Unavailable(_))
  assert_true(stdin_is_readable() is Unavailable(_))
  assert_true(
    try {
      ignore(read_link("unread-link"))
      false
    } catch {
      IOError(kind=Unsupported, ..) => true
      _ => false
    },
  )
}

///|
test "Windows lexical paths retain drives and canonical prefixes" {
  assert_eq(normalize_windows_path("C:\\work\\tree\\file"), "C:/work/tree/file")
  assert_eq(normalize_windows_path("\\\\?\\C:\\work\\file"), "C:/work/file")
  assert_eq(
    normalize_windows_path("\\\\?\\UNC\\host\\share\\file"),
    "//host/share/file",
  )
  if !is_windows() {
    assert_eq(normalize_path("literal\\name"), "literal\\name")
  }
}

///|
async test "released filesystem operations preserve chunks and unknown identities" {
  let root = @fs.tmpdir(prefix="rg-system-contract-")
  defer @fs.rmdir(root, recursive=true)
  let path = root + "/data"
  write_file(path, b"abcdef\n")
  let md = metadata(path)
  assert_true(md.is_file())
  assert_eq(md.len, 7L)
  let file = File::open(path)
  defer file.close()
  let buf = FixedArray::make(4, b'\x00')
  assert_eq(file.read(buf, 1, 2), 2)
  assert_eq(Bytes::from_array(buf[:]), b"\x00ab\x00")
  assert_eq(file.read(buf, 0, 4), 4)
  assert_eq(Bytes::from_array(buf[:]), b"cdef")
  assert_eq(file.read(buf, 0, 4), 1)
  assert_eq(buf[0], b'\n')
  assert_eq(file.read(buf, 0, 4), 0)
  assert_eq(file_times(path).created, None)
  assert_eq(read_dir(root).length(), 1)
}

///|
async test "cancelled process reads still close pipes and reap the direct child" {
  let root = @fs.tmpdir(prefix="rg-process-cancel-")
  defer @fs.rmdir(root, recursive=true)
  let process = Process::spawn("moon", [
    "run",
    "internal/sys/testdata/process_fixture.mbtx",
    "--target-dir",
    root + "/build",
    "--",
    "stream",
  ])
  let chunk = FixedArray::make(7, b'\x00')
  assert_true(process.read(chunk, 0, 7) > 0)
  let result : Unit? = @async.with_timeout_opt(20, () => {
    for ;; {
      ignore(process.read(chunk, 0, 7))
      @async.sleep(100)
    }
  })
  assert_true(result is None)
  ignore(process.finish())
  assert_true(process.complete.val)
  assert_true(process.child.val is Some(child) && child.try_wait() is Some(_))
}
