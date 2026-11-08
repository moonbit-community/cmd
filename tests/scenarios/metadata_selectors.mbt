///|
async fn save_metadata_observations(
  work : String,
  destination : String,
  observations : Array[Json],
  phase : String,
) -> Array[@harness.SnapshotEntry] {
  let snapshot = if @async.platform is Windows {
    filesystem_windows_snapshot(work, destination, observations)
  } else {
    @harness.snapshot(
      work,
      observe=["mode", "identity", "atime", "mtime", "ctime", "symlink-target"],
      content=false,
      preserve_identity=true,
    )
  }
  observations.push({
    "phase": phase,
    "clock_ms": @env.now().to_string(),
    "entries": snapshot.map(entry => {
      (
        { "path": entry.path, "kind": entry.kind, "metadata": entry.metadata } :
        Json)
    }),
  })
  @fs.write_file(destination, Json(observations).stringify(indent=2) + "\n")
  snapshot
}

///|
async fn metadata_selector_matrix(
  root : String,
  work : String,
  observation_path : String,
  observations : Array[Json],
  proof? : @harness.ScenarioProof,
  oracle_image? : String,
) -> Unit {
  let oracle_user = if oracle_image is Some(_) {
    guard @async.platform is Linux else {
      fail("sealed selector oracle requires Linux")
    }
    @harness.docker_user()
  } else {
    ""
  }
  // The ranks are fixed fixture facts: 2000 < 2001 < four ordered ctimes
  // < 2098 < 2099. All a/m pairs differ, and ctime ties are tested by selecting
  // the same entry. This distinguishes a swapped source or reference selector.
  let fixtures = [
    (
      "selector-a",
      "200001010000.00",
      946684800L,
      "209901010000.00",
      4070908800L,
      [0, 2, 7],
    ),
    (
      "selector-b",
      "209801010000.00",
      4039372800L,
      "200101010000.00",
      978307200L,
      [6, 3, 1],
    ),
    (
      "selector-c",
      "209901010000.00",
      4070908800L,
      "200001010000.00",
      946684800L,
      [7, 4, 0],
    ),
    (
      "selector-d",
      "200101010000.00",
      978307200L,
      "209801010000.00",
      4039372800L,
      [1, 5, 6],
    ),
  ]
  let changes : Array[(Int64, Int32)] = []
  let births : Array[Int64] = []
  // Reverse creation order makes birth time observably different from the
  // subsequent A/B/C/D ChangeTime order. A birth-time substitution must fail.
  for i = fixtures.length() - 1; i >= 0; i = i - 1 {
    let (name, _, _, _, _, _) = fixtures[i]
    @fs.write_file(work + "/" + name, name)
    @async.sleep(20)
  }
  for
    (name, access_text, access_seconds, modified_text, modified_seconds, _) in fixtures {
    if @async.platform is Windows {
      filesystem_windows_set_time(
        work + "/" + name,
        access_seconds,
        modified_seconds,
        observation_path,
        observations,
        births~,
      )
    } else {
      for (flag, text) in [("-a", access_text), ("-m", modified_text)] {
        let result = @harness.run(
          "touch",
          [flag, "-t", text, work + "/" + name],
          extra_env={ "TZ": "UTC" },
        )
        observations.push({
          "phase": "selector-setup",
          "path": name,
          "flag": flag,
          "requested": text,
          "status": result.status,
          "stdout": @harness.scenario_text(result.stdout),
          "stderr": @harness.scenario_text(result.stderr),
        })
        @fs.write_file(
          observation_path,
          Json(observations).stringify(indent=2) + "\n",
        )
        assert_eq(result.status, 0)
        assert_eq(result.stderr, b"")
      }
    }
    let raw_accessed = @fs.atime(work + "/" + name)
    let raw_modified = @fs.mtime(work + "/" + name)
    let raw_changed = @fs.ctime(work + "/" + name)
    let accessed = filesystem_native_unix_time(raw_accessed)
    let modified = filesystem_native_unix_time(raw_modified)
    let changed = filesystem_native_unix_time(raw_changed)
    observations.push({
      "phase": "selector-precondition",
      "path": name,
      "atime": accessed,
      "mtime": modified,
      "ctime": changed,
      "raw_native_atime": raw_accessed,
      "raw_native_mtime": raw_modified,
      "raw_native_ctime": raw_changed,
      "native_epoch": if @async.platform is Windows {
        "1601-01-01 UTC"
      } else {
        "1970-01-01 UTC"
      },
      "normalized_epoch": "1970-01-01 UTC",
      "expected_atime": (access_seconds, 0),
      "expected_mtime": (modified_seconds, 0),
    })
    @fs.write_file(
      observation_path,
      Json(observations).stringify(indent=2) + "\n",
    )
    assert_eq(accessed, (access_seconds, 0))
    assert_eq(modified, (modified_seconds, 0))
    assert_true(changed.0 > 978307200L && changed.0 < 4039372800L)
    if changes.last() is Some(previous) {
      assert_true(
        changed.0 > previous.0 ||
        (changed.0 == previous.0 && changed.1 > previous.1),
        msg="independent ctime ordering precondition",
      )
    }
    changes.push(changed)
    @async.sleep(20)
  }
  if @async.platform is Windows {
    filesystem_record(observation_path, observations, {
      "phase": "birth-versus-change-precondition",
      "creation_ticks_in_selector_order": births.map(value => value.to_string()),
      "change_times_in_selector_order": changes,
    })
    assert_eq(births.length(), 4)
    for i in 1..<births.length() {
      assert_true(
        births[i - 1] > births[i],
        msg="birth order must oppose the independently observed ChangeTime order",
      )
    }
  }
  let before = save_metadata_observations(
    work, observation_path, observations, "selector-matrix-before",
  ).filter(entry => entry.path.has_prefix("selector-"))
  for x, source_selector in ["a", "c", "m"] {
    for y, reference_selector in ["a", "c", "m"] {
      let label = "newer" + source_selector + reference_selector
      let actual_outputs : Array[String] = []
      let expected_outputs : Array[String] = []
      let statuses : Array[Int32] = []
      let errors : Array[String] = []
      for (source, _, _, _, _, source_ranks) in fixtures {
        for (reference, _, _, _, _, reference_ranks) in fixtures {
          let result = scenario_run(
            work,
            root,
            "find",
            [source, "-" + label, reference],
            cwd=work,
          )
          actual_outputs.push(@harness.scenario_text(result.stdout))
          statuses.push(result.status)
          errors.push(@harness.scenario_text(result.stderr))
          let expected_output = if source_ranks[x] > reference_ranks[y] {
            source + "\n"
          } else {
            ""
          }
          expected_outputs.push(expected_output)
          if oracle_image is Some(image) {
            let observed = @harness.run_oracle_with_deadline(
              "docker",
              [
                "run",
                "--rm",
                "-i",
                "--user",
                oracle_user,
                "-v",
                work + ":" + work + ":ro",
                "-w",
                work,
                "-e",
                "LC_ALL=C",
                "-e",
                "LANG=C",
                image,
                "/oracle/bin/find",
                source,
                "-" + label,
                reference,
              ],
              15000,
              evidence_dir=work +
                "/../oracle-" +
                label +
                "-" +
                source +
                "-" +
                reference,
              stdin=b"",
            )
            observations.push({
              "phase": "selector-oracle",
              "image": image,
              "predicate": label,
              "source": source,
              "reference": reference,
              "status": observed.output.status,
              "stdout": @harness.scenario_text(observed.output.stdout),
              "stderr": @harness.scenario_text(observed.output.stderr),
              "timed_out": observed.timed_out,
              "cleanup_error": observed.cleanup_error,
              "expected_stdout": expected_output,
            })
            @fs.write_file(
              observation_path,
              Json(observations).stringify(indent=2) + "\n",
            )
            assert_false(observed.timed_out)
            assert_eq(observed.cleanup_error, None)
            assert_eq(observed.output.status, 0)
            assert_eq(observed.output.stderr, b"")
            assert_eq(observed.output.stdout, @utf8.encode(expected_output))
          }
        }
      }
      let actual : Json = {
        "statuses": statuses,
        "stdout": actual_outputs,
        "stderr": errors,
      }
      let expected : Json = {
        "statuses": Array::make(16, 0),
        "stdout": expected_outputs,
        "stderr": Array::make(16, ""),
      }
      observations.push({
        "phase": "selector-matrix-results",
        "predicate": label,
        "source_reference_order": [
          "selector-a", "selector-b", "selector-c", "selector-d",
        ],
        "actual": actual,
        "expected": expected,
      })
      @fs.write_file(
        observation_path,
        Json(observations).stringify(indent=2) + "\n",
      )
      assert_eq(actual, expected)
      if proof is Some(proof) {
        proof.observe_equal("find/selectors-" + label, "find", actual, expected)
      }
    }
  }
  let after = save_metadata_observations(
    work, observation_path, observations, "selector-matrix-after",
  ).filter(entry => entry.path.has_prefix("selector-"))
  let preserved = @harness.snapshots_equal(before, after)
  observations.push({
    "phase": "selector-preservation",
    "metadata_unchanged": preserved,
    "entry_count": after.length(),
  })
  @fs.write_file(
    observation_path,
    Json(observations).stringify(indent=2) + "\n",
  )
  assert_true(
    preserved,
    msg="selector predicates must preserve raw identity/mode/timestamps",
  )
  // Content is read only after the final timestamp observation.
  for (name, _, _, _, _, _) in fixtures {
    assert_eq(@fs.read_file(work + "/" + name).text(), name)
  }
  if proof is Some(proof) {
    proof.observe_equal(
      "find/selectors-preserved",
      "find",
      {
        "metadata_unchanged": preserved,
        "entry_count": after.length(),
        "content_preserved": true,
      },
      {
        "metadata_unchanged": true,
        "entry_count": 4,
        "content_preserved": true,
      },
    )
  }
}
