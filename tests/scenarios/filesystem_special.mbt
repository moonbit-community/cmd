///|
async fn filesystem_predicate_control(
  root : String,
  work : String,
  observation_path : String,
  observations : Array[Json],
  command : String,
  args : Array[String],
  status : Int32,
  stdout : String,
  stderr~ : String = "",
  oracle_image? : String,
) -> Unit {
  let actual = scenario_run(work, root, command, args, cwd=work)
  filesystem_record(observation_path, observations, {
    "phase": "predicate",
    "command": command,
    "args": args,
    "status": actual.status,
    "stdout": @harness.scenario_text(actual.stdout),
    "stderr": @harness.scenario_text(actual.stderr),
    "expected_status": status,
    "expected_stdout": stdout,
  })
  assert_eq(actual.status, status)
  assert_eq(actual.stdout, @utf8.encode(stdout))
  assert_eq(actual.stderr, @utf8.encode(stderr))
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
        work + ":" + work + ":ro",
        "-w",
        work,
        "-e",
        "LC_ALL=C",
        "-e",
        "LANG=C",
        image,
        "/oracle/bin/" + command,
        ..args,
      ],
      15000,
      evidence_dir=observation_path +
        ".oracle-" +
        observations.length().to_string(),
      stdin=b"",
    )
    filesystem_record(observation_path, observations, {
      "phase": "predicate-oracle",
      "image": image,
      "command": command,
      "args": args,
      "status": oracle.output.status,
      "stdout": @harness.scenario_text(oracle.output.stdout),
      "stderr": @harness.scenario_text(oracle.output.stderr),
      "timed_out": oracle.timed_out,
      "cleanup_error": oracle.cleanup_error,
    })
    assert_false(oracle.timed_out)
    assert_eq(oracle.cleanup_error, None)
    assert_eq(oracle.output.status, status)
    assert_eq(oracle.output.stdout, @utf8.encode(stdout))
    // GNU uses the actual argv[0] path in each diagnostic. Only the expected
    // program prefix differs; preserve and compare every other byte.
    let oracle_stderr = stderr
      .split("\n")
      .map(line => {
        if line.has_prefix(command + ": ") {
          "/oracle/bin/" + line.to_owned()
        } else {
          line.to_owned()
        }
      })
      .collect()
      .join("\n")
    assert_eq(oracle.output.stderr, @utf8.encode(oracle_stderr))
  }
}

///|
async fn filesystem_sparse_scenario(
  root : String,
  work : String,
  observation_path : String,
  oracle_image? : String,
) -> Unit {
  guard !(@async.platform is Windows) else {
    fail("POSIX sparse allocation observer required")
  }
  guard !@fs.exists(observation_path) else {
    fail("preserve previous sparse observations")
  }
  let observations : Array[Json] = []
  // Keep multi-gigabyte holes outside uploaded report trees. Retain the raw
  // allocation/sentinel receipts and partial command streams, not payloads.
  let report_work = work
  let isolated = @fs.tmpdir(prefix="cmd-sparse-")
  defer @async.protect_from_cancel(() => {
    defer @fs.rmdir(isolated, recursive=true)
    if @fs.exists(isolated + "/streams") {
      @fs.mkdir(report_work + "/streams")
      for name in @fs.readdir(isolated + "/streams") {
        @fs.write_file(
          report_work + "/streams/" + name,
          @fs.read_file(isolated + "/streams/" + name).binary(),
        )
      }
    }
  })
  let work = isolated + "/work"
  @fs.mkdir(work)
  let mut checked = 0
  for
    (name, size, matches) in [
      (
        "two-gib",
        2147483648L,
        [true, true, false, true, false, false, false, false, false, true],
      ),
      (
        "four-gib-plus-one",
        4294967297L,
        [false, true, true, false, true, true, true, true, false, true],
      ),
    ] {
    let file = @fs.open(
      work + "/" + name,
      mode=ReadWrite,
      create_mode=CreateNew,
    )
    defer file.close()
    file.write_at(b"x", position=size - 1L)
    let (flag, format) = if @async.platform is MacOS {
      ("-f", "%z %b")
    } else {
      ("-c", "%s %b")
    }
    let allocation = @harness.run("/usr/bin/stat", [
      flag,
      format,
      work + "/" + name,
    ])
    filesystem_record(observation_path, observations, {
      "phase": "sparse-precondition",
      "path": name,
      "requested_size": size.to_string(),
      "status": allocation.status,
      "stdout": @harness.scenario_text(allocation.stdout),
      "stderr": @harness.scenario_text(allocation.stderr),
      "observed_size": file.size().to_string(),
      "first_byte": file.read_exactly_at(1, position=0L)[0].to_int(),
      "last_byte": file.read_exactly_at(1, position=size - 1L)[0].to_int(),
    })
    assert_eq(allocation.status, 0)
    assert_eq(allocation.stderr, b"")
    let fields = @harness.scenario_text(allocation.stdout)
      .trim()
      .split(" ")
      .collect()
    assert_eq(fields.length(), 2)
    assert_eq(@string.parse_int64(fields[0]), size)
    let blocks = @string.parse_int64(fields[1])
    assert_true(
      blocks > 0L && blocks * 512L < 1048576L,
      msg="actual sparse allocation required",
    )
    assert_eq(file.size(), size)
    assert_eq(file.read_exactly_at(1, position=0L), b"\x00")
    assert_eq(file.read_exactly_at(1, position=size - 1L), b"x")
    let before = filesystem_mode(work + "/" + name)
    for
      i, token in [
        "2147483648c", "+2147483647c", "4294967297c", "4194304", "8388609", "4194305k",
        "4097M", "5G", "18446744073709551615c", "-18446744073709551615G",
      ] {
      filesystem_predicate_control(
        root,
        work,
        observation_path,
        observations,
        "find",
        [name, "-size", token],
        0,
        if matches[i] {
          name + "\n"
        } else {
          ""
        },
        oracle_image?,
      )
      checked += 1
    }
    filesystem_predicate_control(
      root,
      work,
      observation_path,
      observations,
      "test",
      ["-s", name],
      0,
      "",
      oracle_image?,
    )
    assert_eq(filesystem_mode(work + "/" + name), before)
    assert_eq(file.size(), size)
    assert_eq(file.read_exactly_at(1, position=0L), b"\x00")
    assert_eq(file.read_exactly_at(1, position=size - 1L), b"x")
  }

  @harness.assert_observation(
    "find/sparse-size",
    "find",
    { "comparisons": checked, "sparse_files": 2, "sentinels_preserved": true },
    { "comparisons": 20, "sparse_files": 2, "sentinels_preserved": true },
  )
}

///|
async fn filesystem_special_scenario(
  root : String,
  work : String,
  observation_path : String,
  oracle_image? : String,
) -> Unit {
  guard !(@async.platform is Windows) else {
    fail("POSIX special-file fixture required")
  }
  guard !@fs.exists(observation_path) else {
    fail("preserve previous special-file observations")
  }
  let observations : Array[Json] = []
  let evidence = work + "/.."
  let isolated = @fs.tmpdir(prefix="cmd-special-")
  filesystem_record(observation_path, observations, {
    "phase": "owned-fixture",
    "path": isolated,
    "cleanup": "removed after successful assertions; retained on failure",
  })
  let work = isolated + "/work"
  @fs.mkdir(work)
  let socket_path = work + "/socket"
  // Only the fixture listens. No connection or device content read is needed.
  @async.with_task_group(group => {
    let stdout = @process.redirect_to_file(evidence + "/socket-setup.stdout")
    let stderr = @process.redirect_to_file(evidence + "/socket-setup.stderr")
    let child = @harness.spawn(
      group,
      "/usr/bin/nc",
      ["-d", "-l", "-U", socket_path],
      stdout~,
      stderr~,
      cancel_handler=@process.hard_cancel(),
    )
    defer @async.protect_from_cancel(() => {
      child.cancel()
      let status = child.wait()
      filesystem_record(observation_path, observations, {
        "phase": "socket-fixture-cleanup",
        "status": status,
        "stdout": @fs.read_file(evidence + "/socket-setup.stdout").text(),
        "stderr": @fs.read_file(evidence + "/socket-setup.stderr").text(),
      })
    })
    @async.with_timeout(5000, () => {
      while !@fs.exists(socket_path) {
        guard child.try_wait() is None else {
          fail("socket fixture exited before creating its node")
        }
        @async.sleep(5)
      }
    })
    let kind = @fs.kind(socket_path, follow_symlink=false)
    filesystem_record(observation_path, observations, {
      "phase": "socket-precondition",
      "program": "/usr/bin/nc",
      "program_sha256": @harness.sha256_bytes(
        @fs.read_file("/usr/bin/nc").binary(),
      ),
      "args": ["-d", "-l", "-U", socket_path],
      "socket": kind is Socket,
    })
    assert_true(kind is Socket)
  })
  assert_true(@fs.kind(socket_path, follow_symlink=false) is Socket)
  let block_path = if @async.platform is MacOS {
    "/dev/disk0"
  } else {
    let path = work + "/block"
    let created = @harness.run_with_deadline(
      "sudo",
      ["-n", "/usr/bin/mknod", path, "b", "240", "0"],
      10000,
      stdin=b"",
    )
    filesystem_record(observation_path, observations, {
      "phase": "block-setup",
      "program": "sudo",
      "args": ["-n", "/usr/bin/mknod", path, "b", "240", "0"],
      "status": created.output.status,
      "stdout": @harness.scenario_text(created.output.stdout),
      "stderr": @harness.scenario_text(created.output.stderr),
      "timed_out": created.timed_out,
      "cleanup_error": created.cleanup_error,
    })
    guard !created.timed_out &&
      created.cleanup_error is None &&
      created.output.status == 0 else {
      fail("block fixture infrastructure unavailable")
    }
    path
  }
  @fs.write_file(work + "/regular", "retained")
  let mut checked = 0
  for
    (path, flag, expected_kind) in [
      (socket_path, "S", @fs.Socket),
      ("/dev/null", "c", @fs.CharDevice),
      (block_path, "b", @fs.BlockDevice),
    ] {
    let actual_kind = @fs.kind(path, follow_symlink=false)
    let metadata = filesystem_mode(path)
    filesystem_record(observation_path, observations, {
      "phase": "special-precondition",
      "path": path,
      "predicate": flag,
      "kind_matches": actual_kind == expected_kind,
      "mode_identity": metadata.1,
      "atime": @fs.atime(path),
      "mtime": @fs.mtime(path),
      "ctime": @fs.ctime(path),
    })
    assert_eq(actual_kind, expected_kind)
    for other in ["S", "b", "c", "p", "f", "d"] {
      filesystem_predicate_control(
        root,
        work,
        observation_path,
        observations,
        "test",
        ["-" + other, path],
        if other == flag {
          0
        } else {
          1
        },
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
      "test",
      ["-" + flag, "regular"],
      1,
      "",
      oracle_image?,
    )
    let find_kind = if flag == "S" { "s" } else { flag }
    for predicate in ["-type", "-xtype"] {
      filesystem_predicate_control(
        root,
        work,
        observation_path,
        observations,
        "find",
        [path, predicate, find_kind],
        0,
        path + "\n",
        oracle_image?,
      )
      filesystem_predicate_control(
        root,
        work,
        observation_path,
        observations,
        "find",
        [path, predicate, "f"],
        0,
        "",
        oracle_image?,
      )
    }
    filesystem_predicate_control(
      root,
      work,
      observation_path,
      observations,
      "find",
      [path, "-empty"],
      0,
      "",
      oracle_image?,
    )
    filesystem_predicate_control(
      root,
      work,
      observation_path,
      observations,
      "find",
      [path, "-size", "0c"],
      0,
      path + "\n",
      oracle_image?,
    )
    filesystem_predicate_control(
      root,
      work,
      observation_path,
      observations,
      "test",
      ["-s", path],
      1,
      "",
      oracle_image?,
    )
    assert_eq(filesystem_mode(path), metadata)
  }
  assert_eq(@fs.read_file(work + "/regular").text(), "retained")

  @harness.assert_observation(
    "test/special-kinds",
    "test",
    { "kind_checks": checked, "positive_kinds": 3, "regular_preserved": true },
    { "kind_checks": 18, "positive_kinds": 3, "regular_preserved": true },
  )

  @fs.rmdir(isolated, recursive=true)
  filesystem_record(observation_path, observations, {
    "phase": "owned-fixture-cleaned",
    "path": isolated,
    "absent": !@fs.exists(isolated),
  })
}
