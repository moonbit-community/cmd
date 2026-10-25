///|
async test "mktemp option scenario rejects malformed names and extra creations" {
  for extra in [false, true] {
    let root = @fs.tmpdir(prefix="mktemp-scenario-")
    defer @fs.rmdir(root, recursive=true)
    let rejected = try {
      check_mktemp_options(
        root,
        (_, cwd, environment) => {
          let name = environment["TMPDIR"] +
            "/tmp." +
            (if extra { "AAAAAAAAAA" } else { "AAAAAAAAA" })
          @fs.write_file(name, b"")
          if extra {
            @fs.write_file(cwd + "/unexpected", b"")
          }
          { status: 0, stdout: @utf8.encode(name + "\n"), stderr: b"", }
        },
        check_mode=false,
      )
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
}
