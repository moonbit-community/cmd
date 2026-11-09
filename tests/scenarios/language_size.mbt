///|
async fn shell_size_platform_scenario(
  root : String,
  work : String,
  observation_path : String,
) -> Unit {
  guard !@fs.exists(observation_path) else {
    fail("preserve previous size observations")
  }
  let observations : Array[Json] = []
  @fs.write_file(work + "/empty", "")
  @fs.write_file(work + "/full", "payload")
  for name in ["empty", "full"] {
    @fs.symlink(
      work + "/absolute-" + name,
      target=@fs.realpath(work + "/" + name),
      force_symlink=true,
    )
    assert_eq(
      @fs.kind(work + "/absolute-" + name, follow_symlink=false),
      SymLink,
    )
  }
  let result = scenario_run(
    work,
    root,
    "sh",
    [
      "-c", "test -s absolute-empty; printf '%s|' $?; test -s absolute-full; printf '%s' $?",
    ],
    cwd=work,
  )
  let snapshot = @harness.snapshot(
    work,
    observe=["symlink-target"],
    content=false,
  )
  let mut targets_preserved = true
  for name in ["empty", "full"] {
    let selected = snapshot.filter(entry => entry.path == "absolute-" + name)
    guard selected is [entry] else { fail("absolute link observation missing") }
    let expected_target = if @async.platform is Windows {
      "${WORK}/" + name
    } else {
      @fs.realpath(work + "/" + name)
    }
    let actual_target = entry.metadata.get("symlink-target")
    observations.push({
      "path": entry.path,
      "kind": entry.kind,
      "target": actual_target.map(value => Json(value)).unwrap_or(Json(null)),
      "expected_target": expected_target,
    })
    targets_preserved = targets_preserved &&
      entry.kind == "symlink" &&
      actual_target == Some(expected_target)
  }
  @fs.write_file(
    observation_path,
    Json(observations).stringify(indent=2) + "\n",
  )
  let actual : Json = {
    "status": result.status,
    "stdout": @harness.scenario_text(result.stdout),
    "stderr": @harness.scenario_text(result.stderr),
    "targets_preserved": targets_preserved,
  }
  let expected : Json = {
    "status": 0,
    "stdout": "1|0",
    "stderr": "",
    "targets_preserved": true,
  }
  assert_eq(actual, expected)

  @harness.assert_observation("sh/size-absolute-links", "sh", actual, expected)

  @fs.mkdir(work + "/directory")
  let directory_target = @fs.realpath(work + "/directory")
  let directory_link = work + "/directory-link"
  observations.push({
    "link_path": directory_link,
    "requested_target": directory_target,
  })
  @fs.write_file(
    observation_path,
    Json(observations).stringify(indent=2) + "\n",
  )
  @fs.symlink(directory_link, target=directory_target, force_symlink=true)
  if @async.platform is Windows {
    let observed = @harness.run_with_deadline(
      "powershell.exe",
      [
        "-NoProfile", "-NonInteractive", "-Command", "$ErrorActionPreference = 'Stop'; [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false); $item = Get-Item -LiteralPath $env:CMD_SIZE_DIRECTORY_LINK -Force; [pscustomobject]@{kind=$item.LinkType; target=@($item.Target)[0]; attributes=$item.Attributes.ToString(); directory=(($item.Attributes -band [IO.FileAttributes]::Directory) -ne 0)} | ConvertTo-Json -Compress",
      ],
      10000,
      stdin=b"",
      extra_env={ "CMD_SIZE_DIRECTORY_LINK": directory_link },
    )
    observations.push({
      "observer": "Windows directory symlink attributes",
      "status": observed.output.status,
      "stdout": @harness.scenario_text(observed.output.stdout),
      "stderr": @harness.scenario_text(observed.output.stderr),
      "timed_out": observed.timed_out,
      "cleanup_error": observed.cleanup_error
      .map(value => Json(value))
      .unwrap_or(Json(null)),
    })
    @fs.write_file(
      observation_path,
      Json(observations).stringify(indent=2) + "\n",
    )
    assert_false(observed.timed_out)
    assert_eq(observed.cleanup_error, None)
    assert_eq(observed.output.status, 0)
    assert_eq(observed.output.stderr, b"")
    assert_true(
      @json.parse(@harness.scenario_text(observed.output.stdout))
      is { "kind": String("SymbolicLink"), "directory": True, .. },
      msg="real Windows directory symlink required",
    )
  }
  assert_eq(@fs.kind(directory_link, follow_symlink=false), SymLink)
  let resolved_directory = @fs.realpath(directory_link)
  observations.push({
    "link_path": directory_link,
    "resolved_target": resolved_directory,
    "expected_target": directory_target,
  })
  @fs.write_file(
    observation_path,
    Json(observations).stringify(indent=2) + "\n",
  )
  assert_eq(resolved_directory, directory_target)
  // The Native observer records the host API capability independently of the
  // Wasm product. Linux also has sealed Dash comparison; macOS has fixed
  // rejection cases. An unexpected observer error is an infrastructure failure.
  let available = try @fs.file_size(work + "/directory") catch {
    @os_error.OSError(code, ..) if code == @os_error.errno_ENOTSUP => None
    error => raise error
  } noraise {
    size => Some(size)
  }
  for name in ["directory", "directory-link"] {
    let kind = @fs.kind(work + "/" + name) catch {
      @os_error.OSError(_) as error => {
        observations.push({
          "path": name,
          "native_kind_error": error.to_string(),
        })
        @fs.write_file(
          observation_path,
          Json(observations).stringify(indent=2) + "\n",
        )
        raise error
      }
      error => raise error
    }
    assert_eq(kind, Directory, msg=name)
    let result = scenario_run(
      work,
      root,
      "sh",
      ["-c", "test -s " + name],
      cwd=work,
    )
    let (status, error) = match available {
      Some(size) => (if size > 0L { 0 } else { 1 }, "")
      None =>
        (
          2,
          "sh: test: '-s' target size is unavailable through the public filesystem API: '" +
          name +
          "'\n",
        )
    }
    observations.push({
      "path": name,
      "native_size": available
      .map(size => Json(size.to_string()))
      .unwrap_or(Json(null)),
      "native_unsupported": available is None,
      "status": result.status,
      "stdout": @harness.scenario_text(result.stdout),
      "stderr": @harness.scenario_text(result.stderr),
      "expected_status": status,
      "expected_stderr": error,
    })
    @fs.write_file(
      observation_path,
      Json(observations).stringify(indent=2) + "\n",
    )
    let actual : Json = {
      "status_matches_native_metadata": result.status == status,
      "stdout_empty": result.stdout == b"",
      "diagnostic_matches_capability": @harness.scenario_text(result.stderr) ==
      error,
    }
    let expected : Json = {
      "status_matches_native_metadata": true,
      "stdout_empty": true,
      "diagnostic_matches_capability": true,
    }
    assert_eq(actual, expected)

    @harness.assert_observation(
      "sh/size-platform-" + name,
      "sh",
      actual,
      expected,
    )
  }
}

///|
async fn shell_size_posix_scenario(root : String, work : String) -> Unit {
  guard !(@async.platform is Windows) else {
    fail("POSIX size scenario selected on Windows")
  }
  let unreadable = work + "/opaque"
  @fs.write_file(unreadable, "payload")
  @fs.chmod(unreadable, 0)
  defer @async.protect_from_cancel(() => @fs.chmod(unreadable, 0o600))
  assert_false(@fs.can_read(unreadable), msg="unreadable-file precondition")
  assert_eq(@fs.file_size(unreadable), 7L)
  let result = scenario_run(
    work,
    root,
    "sh",
    ["-c", "test -s opaque"],
    cwd=work,
  )
  @fs.chmod(unreadable, 0o600)
  let actual : Json = {
    "status": result.status,
    "stdout": @harness.scenario_text(result.stdout),
    "stderr": @harness.scenario_text(result.stderr),
    "preserved_content": @fs.read_file(unreadable).text(),
  }
  let expected : Json = {
    "status": 0,
    "stdout": "",
    "stderr": "",
    "preserved_content": "payload",
  }
  assert_eq(actual, expected)

  @harness.assert_observation("sh/size-unreadable", "sh", actual, expected)

  // This fixed host utility creates a fixture only; the product never delegates
  // its predicate to a host command or opens the FIFO to obtain its size.
  let setup = @harness.run_with_deadline(
    "/usr/bin/mkfifo",
    [work + "/pipe"],
    5000,
    stdin=b"",
  )
  assert_false(setup.timed_out)
  assert_eq(setup.cleanup_error, None)
  assert_eq(setup.output.status, 0)
  assert_eq(setup.output.stderr, b"")
  assert_eq(@fs.kind(work + "/pipe"), Pipe)
  assert_eq(@fs.file_size(work + "/pipe"), 0L)
  let result = scenario_run(work, root, "sh", ["-c", "test -s pipe"], cwd=work)
  let actual : Json = {
    "status": result.status,
    "stdout": @harness.scenario_text(result.stdout),
    "stderr": @harness.scenario_text(result.stderr),
    "still_fifo": @fs.kind(work + "/pipe") == Pipe,
  }
  let expected : Json = {
    "status": 1,
    "stdout": "",
    "stderr": "",
    "still_fifo": true,
  }
  assert_eq(actual, expected)

  @harness.assert_observation("sh/size-fifo", "sh", actual, expected)
}
