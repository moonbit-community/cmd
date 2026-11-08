///|
async fn filesystem_unreadable_scenario(
  root : String,
  work : String,
  observation_path : String,
  command : String,
  proof? : @harness.ScenarioProof,
  oracle_image? : String,
) -> Unit {
  guard !(@async.platform is Windows) &&
    (command == "find" || command == "test") else {
    fail("POSIX unreadable size fixture required")
  }
  guard !@fs.exists(observation_path) else {
    fail("preserve unreadable observations")
  }
  let observations : Array[Json] = []
  for (name, contents) in [("full", "payload"), ("empty", "")] {
    @fs.write_file(work + "/" + name, contents)
  }
  // Restore only after the original metadata was observed, including on failure,
  // so report upload and cleanup cannot be blocked by the test's own mode 000.
  defer @async.protect_from_cancel(() => {
    for name in ["full", "empty"] {
      @fs.chmod(work + "/" + name, 0o600)
    }
  })
  for name in ["full", "empty"] {
    let path = work + "/" + name
    @fs.chmod(path, 0)
    let unreadable = !@fs.can_read(path)
    let denied = try {
      let file = @fs.open(path, mode=ReadOnly)
      file.close()
      false
    } catch {
      // POSIX EACCES is 13 on both supported observation platforms.
      @os_error.OSError(13, ..) => true
      error => raise error
    }
    let (mode, raw_mode) = filesystem_mode(path)
    filesystem_record(observation_path, observations, {
      "phase": "unreadable-precondition",
      "path": name,
      "read_access_denied": unreadable,
      "open_denied": denied,
      "mode": mode,
      "raw_mode_identity": raw_mode,
      "size": @fs.file_size(path).to_string(),
    })
    assert_true(unreadable && denied)
    assert_eq(mode, 0)
    assert_eq(@fs.kind(path), Regular)
  }
  let before = @harness.snapshot(
    work,
    observe=["mode", "identity", "atime", "mtime", "ctime"],
    content=false,
    preserve_identity=true,
  )
  let mut comparisons = 0
  for (name, nonempty) in [("full", true), ("empty", false)] {
    if command == "test" {
      filesystem_predicate_control(
        root,
        work,
        observation_path,
        observations,
        command,
        ["-s", name],
        if nonempty {
          0
        } else {
          1
        },
        "",
        oracle_image?,
      )
      comparisons += 1
    } else {
      for (size, selected) in [("7c", nonempty), ("0c", !nonempty)] {
        filesystem_predicate_control(
          root,
          work,
          observation_path,
          observations,
          command,
          [name, "-size", size],
          0,
          if selected {
            name + "\n"
          } else {
            ""
          },
          oracle_image?,
        )
        comparisons += 1
      }
    }
  }
  let after = @harness.snapshot(
    work,
    observe=["mode", "identity", "atime", "mtime", "ctime"],
    content=false,
    preserve_identity=true,
  )
  filesystem_record(observation_path, observations, {
    "phase": "unreadable-original-effects",
    "before": before.map(entry => {
      (
        { "path": entry.path, "kind": entry.kind, "metadata": entry.metadata } :
        Json)
    }),
    "after": after.map(entry => {
      (
        { "path": entry.path, "kind": entry.kind, "metadata": entry.metadata } :
        Json)
    }),
  })
  assert_true(@harness.snapshots_equal(before, after))
  for (name, contents) in [("full", "payload"), ("empty", "")] {
    let path = work + "/" + name
    assert_false(@fs.can_read(path))
    assert_eq(filesystem_mode(path).0, 0)
    @fs.chmod(path, 0o600)
    let retained = @fs.read_file(path).text()
    filesystem_record(observation_path, observations, {
      "phase": "observer-permission-restored-content",
      "path": name,
      "observer_mode": "0600",
      "content": retained,
      "expected_content": contents,
    })
    assert_eq(retained, contents)
  }
  if proof is Some(proof) {
    proof.observe_equal(
      command + "/unreadable-size",
      command,
      {
        "comparisons": comparisons,
        "open_denied": true,
        "original_metadata_preserved": true,
        "content_preserved": true,
      },
      {
        "comparisons": if command == "find" {
          4
        } else {
          2
        },
        "open_denied": true,
        "original_metadata_preserved": true,
        "content_preserved": true,
      },
    )
  }
}
