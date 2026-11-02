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
    assert_eq(set.status, 0)
    assert_eq(set.stderr, b"")
    assert_eq(@fs.atime(work + "/" + name), (seconds, 0))
    assert_eq(@fs.mtime(work + "/" + name), (seconds, 0))
  }
  @fs.write_file(work + "/reference", "reference")
  let reference_change = @fs.ctime(work + "/reference")
  @async.sleep(20)
  @fs.write_file(work + "/fresh", "fresh")
  let fresh_change = @fs.ctime(work + "/fresh")
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
    assert_eq(
      observed,
      (true, false),
      msg="effective-access fixture precondition",
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
  }
}
