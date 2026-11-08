///|
async fn filesystem_time_scenario(
  root : String,
  work : String,
  observation_path : String,
  proof? : @harness.ScenarioProof,
  oracle_image? : String,
) -> Unit {
  guard !(@async.platform is Windows) else {
    fail("POSIX timestamp setter required")
  }
  guard !@fs.exists(observation_path) else {
    fail("preserve previous time observations")
  }
  let observations : Array[Json] = []
  for
    (name, date, seconds) in [
      ("old", "200001010000.00", 946684800L),
      ("middle", "202001010000.00", 1577836800L),
      ("future", "209901010000.00", 4070908800L),
    ] {
    @fs.write_file(work + "/" + name, name)
    let set = @harness.run(
      "/usr/bin/touch",
      ["-a", "-m", "-t", date, work + "/" + name],
      extra_env={ "TZ": "UTC" },
    )
    filesystem_record(observation_path, observations, {
      "phase": "time-setup",
      "path": name,
      "requested": seconds.to_string(),
      "status": set.status,
      "stdout": @harness.scenario_text(set.stdout),
      "stderr": @harness.scenario_text(set.stderr),
      "atime": @fs.atime(work + "/" + name),
      "mtime": @fs.mtime(work + "/" + name),
      "ctime": @fs.ctime(work + "/" + name),
    })
    assert_eq(set.status, 0)
    assert_eq(set.stderr, b"")
    assert_eq(@fs.atime(work + "/" + name), (seconds, 0))
    assert_eq(@fs.mtime(work + "/" + name), (seconds, 0))
  }
  let start = @env.now().reinterpret_as_int64()
  filesystem_record(observation_path, observations, {
    "phase": "clock-before",
    "clock_ms": start.to_string(),
  })
  assert_true(start / 1000L > 1577836800L && start / 1000L < 4070908800L)
  let mut comparisons = 0
  for predicate in ["-amin", "-atime", "-mmin", "-mtime"] {
    for
      (token, old, future) in [
        ("+1", true, false),
        ("-1", false, true),
        ("0", false, false),
        ("+1.5", true, false),
        ("-1.5", false, true),
        ("+1e1", true, false),
        ("-0x1p1", false, true),
        ("++1", true, false),
        ("+-1", true, false),
        ("--1", false, true),
        ("+ 1", true, false),
      ] {
      for (name, selected) in [("old", old), ("future", future)] {
        filesystem_predicate_control(
          root,
          work,
          observation_path,
          observations,
          "find",
          [name, predicate, token],
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
  @fs.write_file(work + "/fresh", "fresh")
  let fresh_ctime = @fs.ctime(work + "/fresh")
  @async.sleep(1100)
  let minute_start = @env.now().reinterpret_as_int64()
  filesystem_record(observation_path, observations, {
    "phase": "minute-clock-before",
    "clock_ms": minute_start.to_string(),
    "fresh_ctime": fresh_ctime,
  })
  assert_true(
    minute_start / 1000L > fresh_ctime.0 &&
    minute_start / 1000L - fresh_ctime.0 < 10L,
  )
  for
    (predicate, token, selected) in [
      ("-cmin", "1", true),
      ("-cmin", "0", false),
      ("-cmin", "+0", true),
      ("-cmin", "-1", true),
      ("-cmin", "-0", false),
      ("-ctime", "0", true),
      ("-ctime", "1", false),
      ("-ctime", "+0", false),
      ("-ctime", "-1", true),
      ("-ctime", "-0", false),
    ] {
    filesystem_predicate_control(
      root,
      work,
      observation_path,
      observations,
      "find",
      ["fresh", predicate, token],
      0,
      if selected {
        "fresh\n"
      } else {
        ""
      },
      oracle_image?,
    )
    comparisons += 1
  }
  let end = @env.now().reinterpret_as_int64()
  filesystem_record(observation_path, observations, {
    "phase": "minute-clock-after",
    "clock_ms": end.to_string(),
    "elapsed_ms": (end - minute_start).to_string(),
  })
  guard end >= minute_start && end / 1000L - fresh_ctime.0 < 50L else {
    fail("time fixture infrastructure: minute-window margin exhausted")
  }
  for
    (token, selected) in [
      ("+1", true),
      ("-1", false),
      ("1", false),
      ("+1.5", true),
      ("-1.5", false),
      ("+1e1", true),
      ("-0x1p1", false),
    ] {
    filesystem_predicate_control(
      root,
      work,
      observation_path,
      observations,
      "find",
      ["future", "-used", token],
      0,
      if selected {
        "future\n"
      } else {
        ""
      },
      oracle_image?,
    )
    filesystem_predicate_control(
      root,
      work,
      observation_path,
      observations,
      "find",
      ["old", "-used", token],
      0,
      "",
      oracle_image?,
    )
    comparisons += 2
  }
  for (name, target) in [("reference-link", "future"), ("dangling", "missing")] {
    @fs.symlink(work + "/" + name, target~)
    let set = @harness.run(
      "/usr/bin/touch",
      ["-h", "-a", "-m", "-t", "200001010000.00", work + "/" + name],
      extra_env={ "TZ": "UTC" },
    )
    filesystem_record(observation_path, observations, {
      "phase": "reference-link-setup",
      "path": name,
      "target": target,
      "status": set.status,
      "stdout": @harness.scenario_text(set.stdout),
      "stderr": @harness.scenario_text(set.stderr),
      "nofollow_atime": @fs.atime(work + "/" + name, follow_symlink=false),
      "nofollow_mtime": @fs.mtime(work + "/" + name, follow_symlink=false),
    })
    assert_eq(set.status, 0)
    assert_eq(set.stderr, b"")
    assert_eq(
      @fs.atime(work + "/" + name, follow_symlink=false),
      (946684800L, 0),
    )
    assert_eq(
      @fs.mtime(work + "/" + name, follow_symlink=false),
      (946684800L, 0),
    )
    for predicate in ["-newer", "-anewer", "-cnewer", "-newerma", "-neweraa"] {
      filesystem_predicate_control(
        root,
        work,
        observation_path,
        observations,
        "find",
        ["middle", predicate, name],
        0,
        "middle\n",
        oracle_image?,
      )
      comparisons += 1
    }
    filesystem_predicate_control(
      root,
      work,
      observation_path,
      observations,
      "find",
      [name, "-size", target.length().to_string() + "c"],
      0,
      name + "\n",
      oracle_image?,
    )
  }
  if proof is Some(proof) {
    proof.observe_equal(
      "find/time-reference-controls",
      "find",
      {
        "comparisons": comparisons,
        "nofollow_references": 2,
        "clock_margin_valid": true,
      },
      {
        "comparisons": 122,
        "nofollow_references": 2,
        "clock_margin_valid": true,
      },
    )
  }
}

///|
async fn filesystem_error_scenario(
  root : String,
  work : String,
  observation_path : String,
  proof? : @harness.ScenarioProof,
  oracle_image? : String,
) -> Unit {
  guard !(@async.platform is Windows) else {
    fail("POSIX access denial required")
  }
  guard !@fs.exists(observation_path) else {
    fail("preserve previous predicate error observations")
  }
  let observations : Array[Json] = []
  @fs.mkdir(work + "/locked")
  @fs.write_file(work + "/locked/file", "retained")
  @fs.write_file(work + "/victim", "retained")
  @fs.symlink(work + "/denied-link", target="locked/file")
  let before = @harness.snapshot(
    work,
    observe=["mode", "identity", "atime", "mtime", "ctime", "symlink-target"],
    content=false,
    preserve_identity=true,
  )
  @fs.chmod(work + "/locked", 0)
  defer @async.protect_from_cancel(() => @fs.chmod(work + "/locked", 0o700))
  let denied = !@fs.can_execute(work + "/locked")
  filesystem_record(observation_path, observations, {
    "phase": "access-precondition",
    "search_denied": denied,
    "raw_mode_identity": filesystem_mode(work + "/locked").1,
  })
  guard denied else {
    fail("predicate infrastructure: real search denial required")
  }
  let error = "find: 'denied-link': Permission denied\n"
  let mut comparisons = 0
  for
    (args, status, stdout, stderr) in [
      (
        ["denied-link", "-xtype", "l", "-o", "(", "-true", "-o", "-print", ")"],
        1,
        "",
        error,
      ),
      (
        ["denied-link", "(", "-xtype", "l", "-o", "-true", ")", "-o", "-print"],
        0,
        "",
        "",
      ),
      (
        ["denied-link", "-xtype", "l", "-a", "(", "-false", "-a", "-print", ")"],
        1,
        "",
        error,
      ),
      (
        ["denied-link", "(", "-xtype", "l", "-a", "-false", ")", "-a", "-print"],
        0,
        "",
        "",
      ),
      (["denied-link", "!", "-xtype", "f"], 1, "denied-link\n", error),
      (
        ["denied-link", "-xtype", "l", "-o", "-xtype", "f"],
        1,
        "",
        error + error,
      ),
      (
        ["locked", "-maxdepth", "0", "-empty", "-o", "-empty"],
        1,
        "",
        "find: 'locked': Permission denied\nfind: 'locked': Permission denied\n",
      ),
      (
        ["missing", "-false"],
        1,
        "",
        "find: 'missing': No such file or directory\n",
      ),
      (
        ["missing", "-true", "-o", "-print"],
        1,
        "",
        "find: 'missing': No such file or directory\n",
      ),
    ] {
    filesystem_predicate_control(
      root,
      work,
      observation_path,
      observations,
      "find",
      args,
      status,
      stdout,
      stderr~,
      oracle_image?,
    )
    comparisons += 1
  }
  for
    operator in [
      "-e", "-f", "-d", "-L", "-h", "-p", "-S", "-b", "-c", "-s", "-N", "-r", "-w",
      "-x",
    ] {
    filesystem_predicate_control(
      root,
      work,
      observation_path,
      observations,
      "test",
      [operator, "locked/file"],
      1,
      "",
      oracle_image?,
    )
    comparisons += 1
  }
  for
    (args, status) in [
      (["locked/file", "-nt", "victim"], 1),
      (["victim", "-nt", "locked/file"], 0),
      (["locked/file", "-ot", "victim"], 0),
      (["victim", "-ot", "locked/file"], 1),
    ] {
    filesystem_predicate_control(
      root,
      work,
      observation_path,
      observations,
      "test",
      args,
      status,
      "",
      oracle_image?,
    )
    comparisons += 1
  }
  for
    (reference, reason) in [
      ("missing", "No such file or directory"),
      ("victim/child", "Not a directory"),
      ("locked/file", "Permission denied"),
    ] {
    for action in ["-print", "-delete"] {
      let args = ["victim", action, "-o", "-newer", reference]
      let actual = scenario_run(work, root, "find", args, cwd=work)
      let stderr = @harness.scenario_text(actual.stderr)
      filesystem_record(observation_path, observations, {
        "phase": "reference-setup-error",
        "args": args,
        "status": actual.status,
        "stdout": @harness.scenario_text(actual.stdout),
        "stderr": stderr,
        "required_reason": reason,
      })
      assert_eq(actual.status, 1)
      assert_eq(actual.stdout, b"")
      assert_true(
        stderr.has_prefix("find: cannot read reference timestamp: ") &&
        stderr.contains(reason) &&
        stderr.contains(reference),
      )
      assert_eq(@fs.kind(work + "/victim"), Regular)
      if oracle_image is Some(image) {
        let oracle = @harness.run_oracle_with_deadline(
          "docker",
          [
            "run",
            "--rm",
            "-i",
            "--user",
            @harness.docker_user(),
            "-v",
            work + ":" + work,
            "-w",
            work,
            "-e",
            "LC_ALL=C",
            "-e",
            "LANG=C",
            image,
            "/oracle/bin/find",
            ..args,
          ],
          15000,
          evidence_dir=observation_path +
            ".reference-oracle-" +
            comparisons.to_string(),
          stdin=b"",
        )
        filesystem_record(observation_path, observations, {
          "phase": "reference-oracle-error",
          "image": image,
          "args": args,
          "status": oracle.output.status,
          "stdout": @harness.scenario_text(oracle.output.stdout),
          "stderr": @harness.scenario_text(oracle.output.stderr),
          "timed_out": oracle.timed_out,
          "cleanup_error": oracle.cleanup_error,
        })
        assert_false(oracle.timed_out)
        assert_eq(oracle.cleanup_error, None)
        assert_eq(oracle.output.status, 1)
        assert_eq(oracle.output.stdout, b"")
        let diagnostic = @harness.scenario_text(oracle.output.stderr)
        assert_true(
          diagnostic.contains(reference) && diagnostic.contains(reason),
        )
        assert_eq(@fs.kind(work + "/victim"), Regular)
      }
      comparisons += 1
    }
  }
  @fs.chmod(work + "/locked", 0o700)
  let after = @harness.snapshot(
    work,
    observe=["mode", "identity", "atime", "mtime", "ctime", "symlink-target"],
    content=false,
    preserve_identity=true,
  )
  filesystem_record(observation_path, observations, {
    "phase": "error-effects",
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
    "observer_changes": "locked mode restored to 0700; its mode/ctime are excluded from predicate preservation",
  })
  assert_true(
    @harness.snapshots_equal(
      before.filter(entry => entry.path != "locked"),
      after.filter(entry => entry.path != "locked"),
    ),
  )
  assert_eq(@fs.read_file(work + "/victim").text(), "retained")
  assert_eq(@fs.read_file(work + "/locked/file").text(), "retained")
  if proof is Some(proof) {
    proof.observe_equal(
      "find/error-order-effects",
      "find",
      {
        "comparisons": comparisons,
        "victim_preserved": true,
        "denied_child_preserved": true,
      },
      {
        "comparisons": 33,
        "victim_preserved": true,
        "denied_child_preserved": true,
      },
    )
  }
}
