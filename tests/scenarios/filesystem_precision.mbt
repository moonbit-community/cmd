///|
async fn prepare_subsecond_fixture(
  prepare : async () -> ((Int64, Int32), (Int64, Int32)),
  record : async (Json) -> Unit,
  attempt_limit~ : Int32 = 8,
  timeout_ms~ : Int32 = 10000,
) -> ((Int64, Int32), (Int64, Int32)) {
  guard attempt_limit > 0 && timeout_ms > 0 else {
    fail("subsecond fixture infrastructure: invalid preparation budget")
  }
  @async.with_timeout(
    timeout_ms,
    () => {
      for attempt in 1..<=attempt_limit {
        let started = @env.now()
        let (early, late) = prepare()
        let formed = early.0 == late.0 &&
          early.1 >= 0 &&
          early.1 < late.1 &&
          late.1 < 1000000000
        record({
          "phase": "subsecond-fixture-attempt",
          "attempt": attempt,
          "clock_before_ms": started.to_string(),
          "clock_after_ms": @env.now().to_string(),
          "early_mtime": early,
          "late_mtime": late,
          "formed": formed,
          "reason": if formed {
            "same-second strictly ordered nanoseconds"
          } else if early.0 != late.0 {
            "different seconds"
          } else {
            "nanoseconds not strictly ordered within range"
          },
        })
        if formed {
          return (early, late)
        }
      }
      fail(
        "subsecond fixture infrastructure: no valid pair after " +
        attempt_limit.to_string() +
        " preparations",
      )
    },
    error=Failure(
      "subsecond fixture infrastructure: preparation deadline expired",
    ),
  )
}

///|
async fn filesystem_precision_scenario(
  root : String,
  work : String,
  observation_path : String,
  oracle_image? : String,
) -> Unit {
  guard !@fs.exists(observation_path) else {
    fail("preserve previous precision observations")
  }
  let observations : Array[Json] = []
  // Filesystem timestamps can cross a second despite a wall-clock start guess.
  // Only fixture preparation may repeat. Every observation is retained, and all
  // product/oracle calls remain after actual metadata admits one valid pair.
  let (early, late) = prepare_subsecond_fixture(
    () => {
      @fs.write_file(work + "/early", "early")
      let early = @fs.mtime(work + "/early")
      @async.sleep(20)
      @fs.write_file(work + "/late", "late")
      let late = @fs.mtime(work + "/late")
      (early, late)
    },
    event => filesystem_record(observation_path, observations, event),
  )
  filesystem_record(observation_path, observations, {
    "phase": "subsecond-precondition",
    "early_mtime": early,
    "late_mtime": late,
    "clock_ms": @env.now().to_string(),
  })
  guard early.0 == late.0 &&
    early.1 >= 0 &&
    early.1 < late.1 &&
    late.1 < 1000000000 else {
    fail(
      "subsecond fixture infrastructure: distinct same-second timestamps required",
    )
  }
  let before = @harness.snapshot(
    work,
    observe=["atime", "mtime", "ctime"],
    content=false,
  )
  let mut checked = 0
  for
    (args, status) in [
      (["late", "-nt", "early"], 0),
      (["early", "-nt", "late"], 1),
      (["early", "-ot", "late"], 0),
      (["late", "-ot", "early"], 1),
      (["early", "-nt", "early"], 1),
      (["late", "-ot", "late"], 1),
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
    checked += 1
  }
  filesystem_predicate_control(
    root,
    work,
    observation_path,
    observations,
    "find",
    ["late", "-newer", "early"],
    0,
    "late\n",
    oracle_image?,
  )
  filesystem_predicate_control(
    root,
    work,
    observation_path,
    observations,
    "find",
    ["early", "-newer", "late"],
    0,
    "",
    oracle_image?,
  )
  let after = @harness.snapshot(
    work,
    observe=["atime", "mtime", "ctime"],
    content=false,
  )
  filesystem_record(observation_path, observations, {
    "phase": "subsecond-preservation",
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
  assert_eq(@fs.read_file(work + "/early").text(), "early")
  assert_eq(@fs.read_file(work + "/late").text(), "late")

  @harness.assert_observation(
    "find/subsecond-order",
    "find",
    {
      "comparisons": 2,
      "same_second": early.0 == late.0,
      "distinct_subseconds": early.1 < late.1,
      "metadata_preserved": @harness.snapshots_equal(before, after),
    },
    {
      "comparisons": 2,
      "same_second": true,
      "distinct_subseconds": true,
      "metadata_preserved": true,
    },
  )
  @harness.assert_observation(
    "test/subsecond-order",
    "test",
    {
      "comparisons": checked,
      "same_second": true,
      "distinct_subseconds": true,
      "metadata_preserved": true,
    },
    {
      "comparisons": 6,
      "same_second": true,
      "distinct_subseconds": true,
      "metadata_preserved": true,
    },
  )
}

///|
async fn filesystem_directory_size_scenario(
  root : String,
  work : String,
  observation_path : String,
) -> Unit {
  guard !@fs.exists(observation_path) else {
    fail("preserve previous directory-size observations")
  }
  let observations : Array[Json] = []
  @fs.mkdir(work + "/directory")
  @fs.symlink(
    work + "/directory-link",
    target=@fs.realpath(work + "/directory"),
    force_symlink=true,
  )
  assert_true(
    @fs.kind(work + "/directory-link", follow_symlink=false) is SymLink,
  )
  assert_eq(
    @fs.realpath(work + "/directory-link"),
    @fs.realpath(work + "/directory"),
  )
  let available = try @fs.file_size(work + "/directory") catch {
    @os_error.OSError(code, ..) if code == @os_error.errno_ENOTSUP => None
    error => raise error
  } noraise {
    size => Some(size)
  }
  filesystem_record(observation_path, observations, {
    "phase": "directory-size-capability",
    "native_size": available.map(value => value.to_string()),
    "native_ENOTSUP": available is None,
    "scope": "Independent public Native metadata observation; actual Wasm outcomes are separately required. Linux static contracts and immutable oracle comparisons remain independent.",
  })
  for name in ["directory", "directory-link"] {
    assert_true(@fs.kind(work + "/" + name) is Directory)
    let (status, stderr) = match available {
      Some(size) => (if size > 0L { 0 } else { 1 }, "")
      None =>
        (2, "test: unsupported capability: '-s' metadata for '" + name + "'\n")
    }
    filesystem_predicate_control(
      root,
      work,
      observation_path,
      observations,
      "test",
      ["-s", name],
      status,
      "",
      stderr~,
    )
  }
  let (status, stdout, stderr) = match available {
    Some(size) => (0, if size > 0L { "directory\n" } else { "" }, "")
    None =>
      (
        1, "", "find: 'directory': unsupported capability: entry size metadata\n",
      )
  }
  filesystem_predicate_control(
    root,
    work,
    observation_path,
    observations,
    "find",
    ["directory", "-maxdepth", "0", "-size", "+0c"],
    status,
    stdout,
    stderr~,
  )
  assert_true(@fs.kind(work + "/directory", follow_symlink=false) is Directory)
  assert_true(
    @fs.kind(work + "/directory-link", follow_symlink=false) is SymLink,
  )
  assert_eq(
    @fs.readdir(work + "/directory", include_hidden=true, include_special=false),
    [],
  )
  assert_eq(
    @fs.realpath(work + "/directory-link"),
    @fs.realpath(work + "/directory"),
  )

  @harness.assert_observation(
    "test/directory-size-capability",
    "test",
    {
      "actual_wasm_calls": 3,
      "native_capability_matched": true,
      "directory_and_link_preserved": true,
    },
    {
      "actual_wasm_calls": 3,
      "native_capability_matched": true,
      "directory_and_link_preserved": true,
    },
  )
}
