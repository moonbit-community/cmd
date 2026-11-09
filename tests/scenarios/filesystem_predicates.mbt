///|
async fn filesystem_record(
  destination : String,
  observations : Array[Json],
  observation : Json,
) -> Unit {
  observations.push(observation)
  @fs.write_file(destination, Json(observations).stringify(indent=2) + "\n")
}

///|
async fn filesystem_mode(path : String) -> (Int32, String) {
  let (flag, format) = if @async.platform is MacOS {
    ("-f", "%Op:%d:%i")
  } else {
    ("-c", "%a:%d:%i")
  }
  let result = @harness.run("/usr/bin/stat", [flag, format, path], extra_env={
    "LC_ALL": "C",
  })
  guard result.status == 0 && result.stderr == b"" else {
    fail(
      "required mode/identity observation failed: " +
      @harness.scenario_text(result.stderr),
    )
  }
  let raw = @harness.scenario_text(result.stdout).trim().to_owned()
  let mode = @string.parse_int(raw.split(":").nth(0).unwrap(), base=8) & 0o7777
  (mode, raw)
}

///|
async fn mkdir_umask_event(
  root : String,
  work : String,
  report_dir : String,
  id : String,
  oracle_image? : String,
) -> Unit {
  if oracle_image is Some(image) {
    @fs.mkdir(work + "/candidate")
    @fs.mkdir(work + "/oracle")
    mkdir_umask_scenario(
      root,
      work + "/candidate",
      report_dir + "/" + id + ".candidate.json",
    )
    mkdir_umask_scenario(
      root,
      work + "/oracle",
      report_dir + "/" + id + ".gnu.json",
      oracle_image=image,
    )
  } else {
    mkdir_umask_scenario(
      root,
      work,
      report_dir + "/" + id + ".observations.json",
    )
  }
}

///|
async fn mkdir_umask_scenario(
  root : String,
  work : String,
  observation_path : String,
  oracle_image? : String,
) -> Unit {
  guard !(@async.platform is Windows) else {
    fail("POSIX umask fixture required")
  }
  guard !@fs.exists(observation_path) else {
    fail("preserve previous umask observations")
  }
  let observations : Array[Json] = []
  let oracle_user = if oracle_image is Some(_) {
    @harness.docker_user()
  } else {
    ""
  }
  let mut checked = 0
  for
    (mask, ordinary_mode, boundary) in [
      ("000", 0o777, false),
      ("077", 0o700, false),
      ("100", 0o677, true),
      ("177", 0o600, true),
      ("277", 0o500, true),
      ("777", 0o000, true),
    ] {
    for explicit in [false, true] {
      let name = mask + (if explicit { "-explicit" } else { "-default" })
      let directory = work + "/" + name
      @fs.mkdir(directory)
      @fs.mkdir(directory + "/existing", permission=0o700)
      @fs.chmod(directory + "/existing", 0o750)
      @fs.write_file(directory + "/existing/sentinel", "retained")
      let existing_before = filesystem_mode(directory + "/existing")
      let before_time = (
        @fs.atime(directory + "/existing"),
        @fs.mtime(directory + "/existing"),
        @fs.ctime(directory + "/existing"),
      )
      // Confirm that this runner observes denied owner access; root/ACL bypass
      // must be an infrastructure failure, not a successful boundary test.
      @fs.mkdir(directory + "/access-control")
      @fs.chmod(directory + "/access-control", ordinary_mode)
      let writable = @fs.can_write(directory + "/access-control")
      let searchable = @fs.can_execute(directory + "/access-control")
      filesystem_record(observation_path, observations, {
        "phase": "umask-precondition",
        "fixture": name,
        "mode": ordinary_mode,
        "can_write": writable,
        "can_execute": searchable,
      })
      @fs.chmod(directory + "/access-control", 0o700)
      @fs.rmdir(directory + "/access-control")
      guard (writable && searchable) == !boundary else {
        fail("umask infrastructure: access-control precondition differs")
      }
      let args = if explicit {
        ["-p", "-v", "-m", "750", "parent/child/leaf", "later", "existing"]
      } else {
        ["-p", "-v", "parent/child/leaf", "later", "existing"]
      }
      let completed = if oracle_image is Some(image) {
        @harness.run_oracle_with_deadline(
          "docker",
          [
            "run",
            "--rm",
            "-i",
            "--user",
            oracle_user,
            "-v",
            directory + ":" + directory,
            "-w",
            directory,
            "-e",
            "LC_ALL=C",
            "-e",
            "LANG=C",
            image,
            "/bin/sh",
            "-c",
            "umask \"$1\"; shift; exec \"$@\"",
            "fixture",
            mask,
            "/oracle/bin/mkdir",
            ..args,
          ],
          15000,
          evidence_dir=work + "/../oracle-" + name,
          stdin=b"",
        )
      } else {
        @harness.run_with_deadline(
          "/bin/sh",
          [
            "-c",
            "umask \"$1\"; shift; exec \"$@\"",
            "fixture",
            mask,
            @harness.command_program(),
            ..@harness.command_args(root, "mkdir", args),
          ],
          15000,
          cwd=directory,
          stdin=b"",
          extra_env={ "LC_ALL": "C", "LANG": "C" },
        )
      }
      filesystem_record(observation_path, observations, {
        "phase": "mkdir-result",
        "fixture": name,
        "oracle": oracle_image,
        "args": args,
        "status": completed.output.status,
        "stdout": @harness.scenario_text(completed.output.stdout),
        "stderr": @harness.scenario_text(completed.output.stderr),
        "timed_out": completed.timed_out,
        "cleanup_error": completed.cleanup_error,
      })
      assert_false(completed.timed_out)
      assert_eq(completed.cleanup_error, None)
      let refused = boundary && oracle_image is None
      let prefix = if oracle_image is Some(_) {
        "/oracle/bin/mkdir"
      } else {
        "mkdir"
      }
      let expected_stdout = prefix +
        ": created directory 'parent'\n" +
        (if refused {
          ""
        } else {
          prefix +
          ": created directory 'parent/child'\n" +
          prefix +
          ": created directory 'parent/child/leaf'\n"
        }) +
        prefix +
        ": created directory 'later'\n"
      assert_eq(completed.output.status, if refused { 2 } else { 0 })
      assert_eq(completed.output.stdout, @utf8.encode(expected_stdout))
      assert_eq(
        completed.output.stderr,
        if refused {
          b"mkdir: unsupported capability: parent permission adjustment for 'parent'; created parents are retained\n"
        } else {
          b""
        },
      )
      // Restore ancestors only after recording their actual original metadata.
      // This makes inaccessible descendants observable without calling them absent.
      for path in ["parent", "parent/child", "parent/child/leaf", "later"] {
        if refused && path.has_prefix("parent/") {
          let exists = @fs.exists(directory + "/" + path)
          filesystem_record(observation_path, observations, {
            "phase": "mkdir-absent-after-ancestor-restoration",
            "fixture": name,
            "path": path,
            "exists": exists,
          })
          assert_false(exists)
          continue
        }
        let absolute = directory + "/" + path
        let (mode, raw) = filesystem_mode(absolute)
        let kind = @fs.kind(absolute, follow_symlink=false)
        let timestamps = (
          @fs.atime(absolute),
          @fs.mtime(absolute),
          @fs.ctime(absolute),
        )
        let parent = path == "parent" || path == "parent/child"
        let expected_mode = if parent {
          if oracle_image is Some(_) {
            ordinary_mode | 0o300
          } else {
            ordinary_mode
          }
        } else if explicit {
          0o750
        } else {
          ordinary_mode
        }
        filesystem_record(observation_path, observations, {
          "phase": "mkdir-metadata",
          "fixture": name,
          "path": path,
          "raw_mode_identity": raw,
          "mode": mode,
          "timestamps": timestamps,
          "directory": kind is Directory,
          "expected_mode": expected_mode,
        })
        assert_eq(mode, expected_mode)
        assert_true(kind is Directory)
        @fs.chmod(absolute, 0o700)
        filesystem_record(observation_path, observations, {
          "phase": "observer-adjustment",
          "fixture": name,
          "path": path,
          "mode": Json(0o700),
          "reason": "inspect descendants and permit cleanup after retaining original metadata",
        })
      }
      assert_eq(filesystem_mode(directory + "/existing"), existing_before)
      assert_eq(
        (
          @fs.atime(directory + "/existing"),
          @fs.mtime(directory + "/existing"),
          @fs.ctime(directory + "/existing"),
        ),
        before_time,
      )
      assert_eq(
        @fs.read_file(directory + "/existing/sentinel").text(),
        "retained",
      )
      checked += 1
    }
  }
  mkdir_mixed_error_controls(
    root,
    work,
    observation_path,
    observations,
    oracle_image?,
  )

  @harness.assert_observation(
    "mkdir/umask-effects",
    "mkdir",
    {
      "checked": checked,
      "mixed_error_orders": 2,
      "masks": 6,
      "explicit_and_default": true,
      "existing_preserved": true,
    },
    {
      "checked": 12,
      "mixed_error_orders": 2,
      "masks": 6,
      "explicit_and_default": true,
      "existing_preserved": true,
    },
  )
}

///|
async fn mkdir_mixed_error_controls(
  root : String,
  work : String,
  observation_path : String,
  observations : Array[Json],
  oracle_image? : String,
) -> Unit {
  for
    index, operands in [
      ["obstacle/leaf", "parent/leaf", "later"],
      ["parent/leaf", "obstacle/leaf", "later"],
    ] {
    let directory = work + "/mixed-" + index.to_string()
    @fs.mkdir(directory)
    @fs.write_file(directory + "/obstacle", "retained")
    let before = @harness.snapshot(
      directory,
      observe=["mode", "identity", "atime", "mtime", "ctime"],
      content=false,
      preserve_identity=true,
    )
    let args = ["-p", "-v", ..operands]
    let completed = if oracle_image is Some(image) {
      @harness.run_oracle_with_deadline(
        "docker",
        [
          "run",
          "--rm",
          "-i",
          "--user",
          @harness.docker_user(),
          "-v",
          directory + ":" + directory,
          "-w",
          directory,
          "-e",
          "LC_ALL=C",
          "-e",
          "LANG=C",
          image,
          "/bin/sh",
          "-c",
          "umask 277; exec \"$@\"",
          "fixture",
          "/oracle/bin/mkdir",
          ..args,
        ],
        15000,
        evidence_dir=observation_path + ".mixed-oracle-" + index.to_string(),
        stdin=b"",
      )
    } else {
      @harness.run_with_deadline(
        "/bin/sh",
        [
          "-c",
          "umask 277; exec \"$@\"",
          "fixture",
          @harness.command_program(),
          ..@harness.command_args(root, "mkdir", args),
        ],
        15000,
        cwd=directory,
        stdin=b"",
        extra_env={ "LC_ALL": "C", "LANG": "C" },
      )
    }
    filesystem_record(observation_path, observations, {
      "phase": "mkdir-mixed-result",
      "order": index,
      "oracle": oracle_image,
      "args": args,
      "status": completed.output.status,
      "stdout": @harness.scenario_text(completed.output.stdout),
      "stderr": @harness.scenario_text(completed.output.stderr),
      "timed_out": completed.timed_out,
      "cleanup_error": completed.cleanup_error,
    })
    assert_false(completed.timed_out)
    assert_eq(completed.cleanup_error, None)
    let oracle = oracle_image is Some(_)
    let prefix = if oracle { "/oracle/bin/mkdir" } else { "mkdir" }
    let stdout = prefix +
      ": created directory 'parent'\n" +
      (if oracle { prefix + ": created directory 'parent/leaf'\n" } else { "" }) +
      prefix +
      ": created directory 'later'\n"
    let ordinary_error = "mkdir: cannot create directory 'obstacle/leaf': Not a directory\n"
    let boundary_error = "mkdir: unsupported capability: parent permission adjustment for 'parent'; created parents are retained\n"
    let stderr = if oracle {
      "mkdir: cannot create directory 'obstacle': Not a directory\n"
    } else if index == 0 {
      ordinary_error + boundary_error
    } else {
      boundary_error + ordinary_error
    }
    assert_eq(completed.output.status, if oracle { 1 } else { 2 })
    assert_eq(completed.output.stdout, @utf8.encode(stdout))
    assert_eq(completed.output.stderr, @utf8.encode(stderr))
    for path in ["parent", "parent/leaf", "later"] {
      if !oracle && path == "parent/leaf" {
        assert_false(@fs.exists(directory + "/" + path))
        filesystem_record(observation_path, observations, {
          "phase": "mkdir-mixed-absence",
          "order": index,
          "path": path,
          "exists": false,
        })
        continue
      }
      let absolute = directory + "/" + path
      let (mode, raw) = filesystem_mode(absolute)
      let kind = @fs.kind(absolute, follow_symlink=false)
      filesystem_record(observation_path, observations, {
        "phase": "mkdir-mixed-metadata",
        "order": index,
        "path": path,
        "mode": mode,
        "raw_mode_identity": raw,
        "directory": kind is Directory,
        "timestamps": (
          @fs.atime(absolute),
          @fs.mtime(absolute),
          @fs.ctime(absolute),
        ),
      })
      assert_true(kind is Directory)
      assert_eq(mode, if oracle && path == "parent" { 0o700 } else { 0o500 })
      @fs.chmod(absolute, 0o700)
      filesystem_record(observation_path, observations, {
        "phase": "observer-adjustment",
        "order": index,
        "path": path,
        "mode": Json(0o700),
        "reason": "inspect descendants and clean up after recording original modes",
      })
    }
    let after = @harness.snapshot(
      directory,
      observe=["mode", "identity", "atime", "mtime", "ctime"],
      content=false,
      preserve_identity=true,
    )
    let obstacle_after = after.filter(entry => entry.path == "obstacle")
    filesystem_record(observation_path, observations, {
      "phase": "mkdir-mixed-obstacle-preserved",
      "order": index,
      "before": before.map(entry => {
        (
          { "path": entry.path, "kind": entry.kind, "metadata": entry.metadata } :
          Json)
      }),
      "after": obstacle_after.map(entry => {
        (
          { "path": entry.path, "kind": entry.kind, "metadata": entry.metadata } :
          Json)
      }),
    })
    assert_true(@harness.snapshots_equal(before, obstacle_after))
    assert_eq(@fs.read_file(directory + "/obstacle").text(), "retained")
  }
}
