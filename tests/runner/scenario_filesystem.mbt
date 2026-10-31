///|
struct ScenarioTimestampObservation {
  before_atime : String
  after_atime : String
  before_mtime : String
  after_mtime : String
} derive(ToJson, FromJson)

///|
fn scenario_timestamp_text(value : (Int64, Int32)) -> String {
  let (seconds, nanos) = value
  "\{seconds}:\{nanos}"
}

///|
async fn diff_directory_devices_boundary_scenario(
  root : String,
  wasm : Bool,
  work : String,
) -> Unit {
  let left = work + "/left"
  let right = work + "/right"
  @fs.mkdir(left)
  @fs.mkdir(right)
  @fs.symlink(left + "/device", target="/dev/null")
  defer @async.protect_from_cancel(() => @fs.remove(left + "/device"))
  @fs.symlink(right + "/device", target="/dev/zero")
  defer @async.protect_from_cancel(() => @fs.remove(right + "/device"))
  assert_eq(@fs.kind(left + "/device"), CharDevice)
  assert_eq(@fs.kind(right + "/device"), CharDevice)
  let result = scenario_run(
    work,
    root,
    wasm,
    "diff",
    ["-r", left, right],
    stdin=b"",
  )
  assert_eq(result.status, 2)
  assert_eq(result.stdout, b"")
  assert_eq(
    result.stderr,
    b"diff: unsupported capability: directory device-number comparison\n",
  )
  let left_kind = @fs.kind(left + "/device", follow_symlink=false)
  let right_kind = @fs.kind(right + "/device", follow_symlink=false)
  let left_target = @fs.realpath(left + "/device")
  let right_target = @fs.realpath(right + "/device")
  let observed : Json = {
    "left": {
      "kind": Json(if left_kind == SymLink { "symlink" } else { "other" }),
      "resolved_target": Json(left_target),
    },
    "right": {
      "kind": Json(if right_kind == SymLink { "symlink" } else { "other" }),
      "resolved_target": Json(right_target),
    },
  }
  @fs.write_file(
    work + "/device-observations.json",
    observed.stringify(indent=2) + "\n",
  )
  assert_eq(left_kind, SymLink)
  assert_eq(right_kind, SymLink)
  assert_eq(left_target, "/dev/null")
  assert_eq(right_target, "/dev/zero")
}

///|
async fn rejected_touch_timestamp_scenario(
  root : String,
  wasm : Bool,
  work : String,
) -> Unit {
  // Repository paths can be read by unrelated indexing or synchronization
  // services. Keep the sensitive observation interval in a private fixture.
  let isolated = @fs.tmpdir(prefix="mooncmd-touch-timestamps-")
  defer (@async.protect_from_cancel(() => @fs.rmdir(isolated, recursive=true)) catch {
    error => fail("cleanup infrastructure: \{error}")
  })
  let source = isolated + "/source"
  @fs.write_file(source, "preserve source", permission=0o640)
  assert_eq(
    @fs.read_file(source, sync_timestamp=true).text(),
    "preserve source",
  )
  let atime = @fs.atime(source)
  let mtime = @fs.mtime(source)
  let touched = scenario_run(work, root, wasm, "touch", [source], stdin=b"")
  let observed_atime = @fs.atime(source)
  let observed_mtime = @fs.mtime(source)
  // Capture both timestamps before reading bytes or copying any evidence.
  // These exact values survive assertion failures; cross-volume rename is not
  // involved in retaining the isolated file.
  let captured : ScenarioTimestampObservation = {
    before_atime: scenario_timestamp_text(atime),
    after_atime: scenario_timestamp_text(observed_atime),
    before_mtime: scenario_timestamp_text(mtime),
    after_mtime: scenario_timestamp_text(observed_mtime),
  }
  @fs.write_file(work + "/../filesystem-origin.txt", isolated)
  @fs.write_file(
    work + "/../timestamp-observations.json",
    @testkit.canonical_json(ToJson::to_json(captured)),
  )
  let content = @fs.read_file(source).binary()
  @fs.write_file(work + "/timestamp-source", content)
  assert_true(touched.status != 0)
  assert_eq(observed_atime, atime)
  assert_eq(observed_mtime, mtime)
  assert_eq(content, b"preserve source")
}

///|
async fn filesystem_fidelity_scenario(
  root : String,
  wasm : Bool,
  work : String,
  proof? : @testkit.ScenarioProof,
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
  if proof is Some(proof) {
    proof.observe_equal(
      "cp/new-copy",
      "cp",
      {
        "status": copied.status,
        "stdout": @testkit.scenario_text(copied.stdout),
        "stderr": @testkit.scenario_text(copied.stderr),
        "content": @fs.read_file(work + "/new").text(),
      },
      { "status": 0, "stdout": "", "stderr": "", "content": "preserve source" },
    )
  }
  @fs.write_file(work + "/mode-reference", "", permission=0o666)
  let snapshot = @testkit.snapshot(work, observe=["mode"])
  if proof is Some(proof) {
    proof.observe_pair(
      "cp/new-mode",
      "cp",
      snapshot.iter().find_first(item => item.path == "new").unwrap().metadata["mode"],
      snapshot.iter().find_first(item => item.path == "mode-reference").unwrap().metadata["mode"],
    )
  }
  assert_eq(
    snapshot.iter().find_first(item => item.path == "new").unwrap().metadata["mode"],
    snapshot.iter().find_first(item => item.path == "mode-reference").unwrap().metadata["mode"],
  )
  rejected_touch_timestamp_scenario(root, wasm, work)
  let mtime = @fs.mtime(source)
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
  if proof is Some(proof) {
    proof.observe_equal(
      "mkdir/parents",
      "mkdir",
      {
        "status": made.status,
        "stdout": @testkit.scenario_text(made.stdout),
        "parent": @fs.exists(work + "/parent"),
        "leaf": @fs.exists(work + "/parent/leaf"),
      },
      { "status": 0, "stdout": "", "parent": true, "leaf": true },
    )
  }
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
  if proof is Some(proof) {
    proof.observe_equal(
      "mkdir/leaf-mode",
      "mkdir",
      Json(
        snapshot.iter().find_first(item => item.path == "parent/leaf").unwrap().metadata["mode"],
      ),
      Json("700"),
    )
    proof.observe_pair(
      "mkdir/parent-mode",
      "mkdir",
      snapshot.iter().find_first(item => item.path == "parent").unwrap().metadata["mode"],
      snapshot
      .iter()
      .find_first(item => item.path == "parent-reference")
      .unwrap().metadata["mode"],
    )
  }
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
  if proof is Some(proof) {
    proof.observe_equal(
      "chmod/recursive-link-skip",
      "chmod",
      {
        "status": recursive.status,
        "referent_mode": snapshot
        .iter()
        .find_first(item => item.path == "source")
        .unwrap().metadata["mode"],
      },
      { "status": 0, "referent_mode": "600" },
    )
  }
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
  if proof is Some(proof) {
    proof.observe_equal(
      "rm/ordinary-no-preserve-root",
      "rm",
      {
        "status": removed.status,
        "stdout": @testkit.scenario_text(removed.stdout),
        "stderr": @testkit.scenario_text(removed.stderr),
        "exists": @fs.exists(work + "/remove-me"),
      },
      { "status": 0, "stdout": "", "stderr": "", "exists": false },
    )
  }
}
