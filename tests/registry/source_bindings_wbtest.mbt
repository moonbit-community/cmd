///|
async test "source scan tolerates entries removed after enumeration without accepting deleted bindings" {
  let root = @fs.tmpdir(prefix="mooncmd-registry-vanished-entry-")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  @fs.mkdir(root + "/fixture")
  @fs.mkdir(root + "/fixture/transient-directory")
  @fs.write_file(
    root + "/fixture/deleted_wbtest.mbt",
    "test \"deleted\" {\n}\n",
  )
  @fs.write_file(
    root + "/fixture/retained_wbtest.mbt",
    "test \"retained\" {\n}\n",
  )
  @fs.write_file(root + "/fixture/transient-url", "observation only\n")
  let entries = @fs.readdir(root + "/fixture", sort=true)
  assert_eq(entries.length(), 4)
  @fs.remove(root + "/fixture/deleted_wbtest.mbt")
  @fs.remove(root + "/fixture/transient-url")
  @fs.rmdir(root + "/fixture/transient-directory")
  let discovered : Array[String] = []
  for name in entries {
    scan_package_test_entry(root + "/", "fixture/" + name, discovered)
  }
  assert_eq(discovered, ["fixture/retained_wbtest.mbt::retained"])
  let failures : Array[String] = []
  compare_references(
    discovered,
    [
      "fixture/deleted_wbtest.mbt::deleted", "fixture/retained_wbtest.mbt::retained",
    ],
    "package test",
    failures,
  )
  assert_eq(failures, [
    "registry: orphan package test 'fixture/deleted_wbtest.mbt::deleted'",
  ])
}

///|
async test "source scan preserves permission non-directory and non-filesystem failures" {
  let root = @fs.tmpdir(prefix="mooncmd-registry-scan-errors-")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let denied = @os_error.OSError(
    match @async.platform {
      Windows => 5
      _ => 13
    },
    context="source-scan-injected-permission",
  )
  assert_true(denied.is_EACCES())
  try {
    scan_package_test_entry(root + "/", "fixture", [], inspect=_ => raise denied)
    fail("permission failure was ignored")
  } catch {
    @os_error.OSError(_) as error =>
      assert_eq(error.to_string(), denied.to_string())
    error => raise error
  }
  let not_directory = @os_error.OSError(
    @os_error.errno_ENOTDIR,
    context="source-scan-injected-non-directory",
  )
  try {
    scan_package_test_entry(root + "/", "fixture", [], inspect=_ => {
      raise not_directory
    })
    fail("non-directory failure was ignored")
  } catch {
    @os_error.OSError(_) as error => assert_true(error.is_ENOTDIR())
    error => raise error
  }
  let failed = try {
    scan_package_test_entry(root + "/", "fixture", [], inspect=_ => {
      fail("scan-observer-failed")
    })
    false
  } catch {
    error => error.to_string().contains("scan-observer-failed")
  }
  assert_true(failed)
}
