///|
async fn filesystem_fidelity_scenario(
  root : String,
  wasm : Bool,
  work : String,
) -> Unit {
  let source = work + "/source"
  let destination = work + "/destination"
  @fs.write_file(source, "preserve source", permission=0o640)
  @fs.write_file(destination, "preserve destination")
  let linked = @testkit.run("ln", [source, work + "/alias"])
  assert_eq(linked.status, 0)
  let identity_args = if @async.platform is MacOS {
    ["-f", "%i:%l"]
  } else {
    ["-c", "%i:%h"]
  }
  let identities_before = @testkit.run(
    "stat",
    [..identity_args, source, work + "/alias"],
    stdin=b"",
  )
  assert_eq(identities_before.status, 0)
  let before = @testkit.snapshot(work, observe=["identity", "mode", "mtime"])
  for
    args in [
      [source, source],
      [source, destination],
      [source, work + "/alias"],
      ["--no-preserve=mode", source, work + "/alias"],
    ] {
    let result = scenario_run(work, root, wasm, "cp", args, stdin=b"")
    assert_true(result.status != 0)
    assert_eq(result.stdout, b"")
    assert_true(@testkit.contains_bytes(result.stderr, "cp:"))
    assert_true(
      @testkit.snapshots_equal(
        before,
        @testkit.snapshot(work, observe=["identity", "mode", "mtime"]),
      ),
    )
  }
  // Raw identities are compared only before/after within this same fixture.
  let identities_after = @testkit.run(
    "stat",
    [..identity_args, source, work + "/alias"],
    stdin=b"",
  )
  assert_eq(identities_after.status, 0)
  assert_eq(identities_after.stdout, identities_before.stdout)
  let copied = scenario_run(
    work,
    root,
    wasm,
    "cp",
    ["--no-preserve=mode", source, work + "/new"],
    stdin=b"",
  )
  assert_eq(copied.status, 0)
  assert_eq(copied.stdout, b"")
  assert_eq(copied.stderr, b"")
  assert_eq(@fs.read_file(work + "/new").text(), "preserve source")
  @fs.write_file(work + "/mode-reference", "", permission=0o666)
  let snapshot = @testkit.snapshot(work, observe=["mode"])
  assert_eq(
    snapshot.iter().find_first(item => item.path == "new").unwrap().metadata["mode"],
    snapshot.iter().find_first(item => item.path == "mode-reference").unwrap().metadata["mode"],
  )
  let atime = @fs.atime(source)
  let mtime = @fs.mtime(source)
  let touched = scenario_run(work, root, wasm, "touch", [source], stdin=b"")
  assert_true(touched.status != 0)
  assert_eq(@fs.atime(source), atime)
  assert_eq(@fs.mtime(source), mtime)
  assert_eq(@fs.read_file(source).text(), "preserve source")
  let absent = scenario_run(
    work,
    root,
    wasm,
    "touch",
    ["-c", work + "/absent"],
    stdin=b"",
  )
  assert_eq(absent.status, 0)
  assert_eq(absent.stdout, b"")
  assert_false(@fs.exists(work + "/absent"))
  let created = scenario_run(
    work,
    root,
    wasm,
    "touch",
    [work + "/created"],
    stdin=b"",
  )
  assert_eq(created.status, 0)
  assert_eq(created.stdout, b"")
  assert_true(@fs.exists(work + "/created"))
  let partial = scenario_run(
    work,
    root,
    wasm,
    "touch",
    [work + "/earlier-created", source],
    stdin=b"",
  )
  assert_true(partial.status != 0)
  assert_true(@fs.exists(work + "/earlier-created"))
  assert_eq(@fs.mtime(source), mtime)
  let made = scenario_run(
    work,
    root,
    wasm,
    "mkdir",
    ["-p", "-m700", work + "/parent/leaf"],
    stdin=b"",
  )
  assert_eq(made.status, 0)
  assert_eq(made.stdout, b"")
  @fs.mkdir(work + "/parent-reference", permission=0o777)
  let snapshot = @testkit.snapshot(work, observe=["mode"])
  assert_eq(
    snapshot.iter().find_first(item => item.path == "parent").unwrap().metadata["mode"],
    snapshot.iter().find_first(item => item.path == "parent-reference").unwrap().metadata["mode"],
  )
  assert_eq(
    snapshot.iter().find_first(item => item.path == "parent/leaf").unwrap().metadata["mode"],
    "700",
  )
  @fs.symlink(work + "/link", target=source)
  let changed = scenario_run(
    work,
    root,
    wasm,
    "chmod",
    ["600", work + "/link"],
    stdin=b"",
  )
  assert_eq(changed.status, 0)
  assert_eq(changed.stdout, b"")
  let snapshot = @testkit.snapshot(work, observe=["mode"])
  assert_eq(
    snapshot.iter().find_first(item => item.path == "source").unwrap().metadata["mode"],
    "600",
  )
  @fs.mkdir(work + "/recursive")
  @fs.symlink(work + "/recursive/link", target=source)
  let recursive = scenario_run(
    work,
    root,
    wasm,
    "chmod",
    ["-R", "700", work + "/recursive"],
    stdin=b"",
  )
  assert_eq(recursive.status, 0)
  let snapshot = @testkit.snapshot(work, observe=["mode"])
  assert_eq(
    snapshot.iter().find_first(item => item.path == "source").unwrap().metadata["mode"],
    "600",
  )
  @fs.write_file(work + "/remove-me", "disposable")
  let removed = scenario_run(
    work,
    root,
    wasm,
    "rm",
    ["--no-preserve-root", work + "/remove-me"],
    stdin=b"",
  )
  assert_eq(removed.status, 0)
  assert_eq(removed.stdout, b"")
  assert_eq(removed.stderr, b"")
  assert_false(@fs.exists(work + "/remove-me"))
}
