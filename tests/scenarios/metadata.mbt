///|
async fn metadata_pair(
  root : String,
  work : String,
  label : String,
  positive : Array[String],
  negative : Array[String],
  selected : String,
  proof? : @harness.ScenarioProof,
) -> Unit {
  let yes = scenario_run(work, root, "find", positive, cwd=work)
  let no = scenario_run(work, root, "find", negative, cwd=work)
  let actual : Json = {
    "statuses": [yes.status, no.status],
    "stdout": [
      @harness.scenario_text(yes.stdout),
      @harness.scenario_text(no.stdout),
    ],
    "stderr": [
      @harness.scenario_text(yes.stderr),
      @harness.scenario_text(no.stderr),
    ],
  }
  let expected : Json = {
    "statuses": [0, 0],
    "stdout": [selected + "\n", ""],
    "stderr": ["", ""],
  }
  assert_eq(actual, expected)
  if proof is Some(proof) {
    proof.observe_equal("find/" + label, "find", actual, expected)
  }
}

///|
async fn metadata_scenario(
  root : String,
  work : String,
  observation_path : String,
  proof? : @harness.ScenarioProof,
  selectors_only~ : Bool = false,
  oracle_image? : String,
) -> Unit {
  guard !@fs.exists(observation_path) else {
    fail("metadata infrastructure: preserve previous observations")
  }
  let observations : Array[Json] = []
  @fs.write_file(observation_path, "[]\n")
  errdefer @async.protect_from_cancel(() => {
    observations.push({
      "phase": "incomplete",
      "detail": "The case report retains the error; prior raw observations are preserved.",
    })
    @fs.write_file(
      observation_path,
      Json(observations).stringify(indent=2) + "\n",
    )
  })
  // Workspace readers can change atime independently of the command under test.
  let isolated = @fs.tmpdir(prefix="cmd-metadata-")
  defer @async.protect_from_cancel(() => {
    defer @fs.rmdir(isolated, recursive=true)
    let streams = isolated + "/streams"
    if @fs.exists(streams) {
      @fs.mkdir(work + "/streams")
      for name in @fs.readdir(streams) {
        @fs.write_file(
          work + "/streams/" + name,
          @fs.read_file(streams + "/" + name).binary(),
        )
      }
    }
  })
  @fs.mkdir(isolated + "/work")
  if selectors_only {
    metadata_selector_matrix(
      root,
      isolated + "/work",
      observation_path,
      observations,
      proof?,
      oracle_image?,
    )
  } else {
    metadata_observations(
      root,
      isolated + "/work",
      observation_path,
      observations,
      proof?,
    )
  }
}

///|
async fn metadata_observations(
  root : String,
  work : String,
  observation_path : String,
  observations : Array[Json],
  proof? : @harness.ScenarioProof,
) -> Unit {
  // Native observation prepares timestamps; commands still execute as Wasm.
  for
    (name, date, seconds) in [
      ("old", "200001010000.00", 946684800L),
      ("future", "209901010000.00", 4070908800L),
    ] {
    @fs.write_file(work + "/" + name, name)
    let set = @harness.run("touch", ["-t", date, work + "/" + name], extra_env={
      "TZ": "UTC",
    })
    observations.push({
      "phase": "time-setup",
      "path": name,
      "requested": date,
      "status": set.status,
      "stdout": @harness.scenario_text(set.stdout),
      "stderr": @harness.scenario_text(set.stderr),
    })
    @fs.write_file(
      observation_path,
      Json(observations).stringify(indent=2) + "\n",
    )
    assert_eq(set.status, 0)
    assert_eq(set.stderr, b"")
    let accessed = @fs.atime(work + "/" + name)
    let modified = @fs.mtime(work + "/" + name)
    observations.push({
      "phase": "time-precondition",
      "path": name,
      "atime": accessed,
      "mtime": modified,
      "expected_seconds": seconds.to_string(),
    })
    @fs.write_file(
      observation_path,
      Json(observations).stringify(indent=2) + "\n",
    )
    assert_eq(accessed, (seconds, 0))
    assert_eq(modified, (seconds, 0))
  }
  @fs.write_file(work + "/reference", "reference")
  let reference_change = @fs.ctime(work + "/reference")
  @async.sleep(20)
  @fs.write_file(work + "/fresh", "fresh")
  let fresh_change = @fs.ctime(work + "/fresh")
  observations.push({
    "phase": "ctime-precondition",
    "reference_ctime": reference_change,
    "fresh_ctime": fresh_change,
  })
  @fs.write_file(
    observation_path,
    Json(observations).stringify(indent=2) + "\n",
  )
  assert_true(
    fresh_change.0 > reference_change.0 ||
    (
      fresh_change.0 == reference_change.0 &&
      fresh_change.1 > reference_change.1
    ),
  )
  let clock_before = @env.now().reinterpret_as_int64()
  assert_true(
    clock_before / 1000L > 946684800L && clock_before / 1000L < 4070908800L,
  )
  assert_true(
    clock_before / 1000L - fresh_change.0 >= 0L &&
    clock_before / 1000L - fresh_change.0 < 30L,
  )
  ignore(
    save_metadata_observations(
      work, observation_path, observations, "time-fixtures-before",
    ),
  )
  for label in ["amin", "atime", "mmin"] {
    metadata_pair(
      root,
      work,
      label,
      ["old", "-" + label, "+1"],
      ["future", "-" + label, "+1"],
      "old",
      proof?,
    )
  }
  for label in ["cmin", "ctime"] {
    metadata_pair(
      root,
      work,
      label,
      ["fresh", "-" + label, "-1"],
      ["fresh", "-" + label, "+1"],
      "fresh",
      proof?,
    )
  }
  for label in ["anewer", "cnewer"] {
    metadata_pair(
      root,
      work,
      label,
      ["fresh", "-" + label, "old"],
      ["fresh", "-" + label, "future"],
      "fresh",
      proof?,
    )
  }
  metadata_pair(
    root,
    work,
    "used",
    ["future", "-used", "+1"],
    ["old", "-used", "+1"],
    "future",
    proof?,
  )
  for x in ["a", "c", "m"] {
    for y in ["a", "c", "m"] {
      let label = "newer" + x + y
      let positive = if x == "c" { "fresh" } else { "future" }
      let reference = if y == "c" { "reference" } else { "old" }
      let negative = if x == "c" { "fresh" } else { "old" }
      let negative_reference = if y == "c" { "fresh" } else { "future" }
      metadata_pair(
        root,
        work,
        label,
        [positive, "-" + label, reference],
        [negative, "-" + label, negative_reference],
        positive,
        proof?,
      )
    }
  }
  let clock_after = @env.now().reinterpret_as_int64()
  assert_true(
    clock_after >= clock_before && clock_after - clock_before < 30000L,
  )
  ignore(
    save_metadata_observations(
      work, observation_path, observations, "time-fixtures-after",
    ),
  )
  metadata_selector_matrix(root, work, observation_path, observations, proof?)
  for
    (label, option, mode) in [
      ("readable", "-r", 0o400),
      ("writable", "-w", 0o200),
      ("executable", "-x", 0o100),
    ] {
    let allowed = work + "/" + label + "-yes"
    let denied = work + "/" + label + "-no"
    @fs.write_file(allowed, "permission fixture", permission=mode)
    @fs.write_file(denied, "permission fixture", permission=0o000)
    let observed = match label {
      "readable" => (@fs.can_read(allowed), @fs.can_read(denied))
      "writable" => (@fs.can_write(allowed), @fs.can_write(denied))
      _ => (@fs.can_execute(allowed), @fs.can_execute(denied))
    }
    observations.push({
      "phase": "access-precondition",
      "predicate": label,
      "observed": observed,
      "requested_modes": [mode, 0],
    })
    @fs.write_file(
      observation_path,
      Json(observations).stringify(indent=2) + "\n",
    )
    assert_eq(
      observed,
      (true, false),
      msg="public access-check fixture precondition",
    )
    ignore(
      save_metadata_observations(
        work,
        observation_path,
        observations,
        "access-" + label + "-before",
      ),
    )
    metadata_pair(
      root,
      work,
      label,
      [label + "-yes", "-" + label],
      [label + "-no", "-" + label],
      label + "-yes",
      proof?,
    )
    let yes = scenario_run(work, root, "test", [option, allowed], cwd=work)
    let no = scenario_run(work, root, "test", [option, denied], cwd=work)
    let actual : Json = {
      "statuses": [yes.status, no.status],
      "stdout": [
        @harness.scenario_text(yes.stdout),
        @harness.scenario_text(no.stdout),
      ],
      "stderr": [
        @harness.scenario_text(yes.stderr),
        @harness.scenario_text(no.stderr),
      ],
    }
    let expected : Json = {
      "statuses": [0, 1],
      "stdout": ["", ""],
      "stderr": ["", ""],
    }
    assert_eq(actual, expected)
    if proof is Some(proof) {
      proof.observe_equal("test/" + label, "test", actual, expected)
    }
    ignore(
      save_metadata_observations(
        work,
        observation_path,
        observations,
        "access-" + label + "-after",
      ),
    )
  }
}
