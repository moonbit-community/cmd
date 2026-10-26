///|
pub fn supports(id : String) -> Bool {
  id == "mv-windows-wasm-links-boundary"
}

///|
// Public filesystem APIs classify both reparse-point types as SymLink. The
// fixed observer supplies their actual type and target; it never changes paths.
async fn windows_mv_snapshot(
  directory : String,
  trace : String,
) -> Array[@testkit.SnapshotEntry] {
  let entries = @testkit.snapshot(directory)
  entries.sort_by_key(entry => entry.path)
  let links = entries
    .filter(entry => entry.kind == "symlink")
    .map(entry => entry.path)
  if !links.is_empty() {
    let script =
      #|$ErrorActionPreference = 'Stop'
      #|[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
      #|$items = @(foreach ($relative in (ConvertFrom-Json $env:MOONCMD_OBSERVED_LINKS)) {
      #|  $item = Get-Item -LiteralPath (Join-Path $env:MOONCMD_OBSERVED_ROOT $relative) -Force
      #|  [pscustomobject]@{path=$relative; kind=$item.LinkType; target=@($item.Target)[0]}
      #|})
      #|[pscustomobject]@{observer_version=$PSVersionTable.PSVersion.ToString(); links=$items} | ConvertTo-Json -Depth 4 -Compress
    let observed = @testkit.run_with_deadline(
      "powershell.exe",
      ["-NoProfile", "-NonInteractive", "-Command", script],
      15000,
      extra_env={
        "MOONCMD_OBSERVED_ROOT": directory,
        "MOONCMD_OBSERVED_LINKS": ToJson::to_json(links).stringify(),
      },
    ) catch {
      error =>
        fail(
          "infrastructure: required Windows mv link observer unavailable: \{error}",
        )
    }
    @fs.write_file(trace + ".observer.stdout.json", observed.output.stdout)
    @fs.write_file(trace + ".observer.stderr.bin", observed.output.stderr)
    @fs.write_file(
      trace + ".observer.status.txt",
      observed.output.status.to_string(),
    )
    guard !observed.timed_out &&
      observed.cleanup_error is None &&
      observed.output.status == 0 else {
      fail(
        "infrastructure: required Windows mv link observer failed; see " + trace,
      )
    }
    let json = @json.parse(@utf8.decode(observed.output.stdout)) catch {
      error =>
        fail("infrastructure: invalid Windows mv observer JSON: \{error}")
    }
    guard json
      is {
        "observer_version": String(version),
        "links": Array(observations),
        ..
      } &&
      version != "" else {
      fail("infrastructure: Windows mv observer omitted its version or links")
    }
    guard observations.length() == links.length() else {
      fail(
        "infrastructure: Windows mv observer returned an incomplete link inventory",
      )
    }
    let seen : Map[String, Bool] = Map([])
    for observation in observations {
      guard observation
        is {
          "path": String(path),
          "kind": String(kind),
          "target": String(target),
          ..
        } &&
        (kind == "SymbolicLink" || kind == "Junction") &&
        target != "" &&
        links.contains(path) &&
        !seen.contains(path) else {
        fail(
          "infrastructure: Windows mv observer returned invalid link properties",
        )
      }
      seen[path] = true
      for entry in entries {
        if entry.path == path {
          entry.metadata["link-type"] = kind
          entry.metadata["symlink-target"] = target.replace_all(
            old="\\",
            new="/",
          )
        }
      }
    }
  }
  @fs.write_file(
    trace + ".snapshot.txt",
    @testkit.snapshot_fingerprint(entries),
  )
  entries
}

///|
async fn prepare_windows_mv_link(
  directory : String,
  name : String,
  link_kind : String,
) -> String {
  let referent = directory + "/" + name + "-referent"
  match link_kind {
    "file" => @fs.write_file(referent, "\{name} file referent must stay\n")
    "directory" | "junction" => {
      @fs.mkdir(referent)
      @fs.write_file(
        referent + "/payload",
        "\{name} directory referent must stay\n",
      )
    }
    "dangling" => ()
    _ => fail("unknown Windows mv link fixture")
  }
  @fs.symlink(
    target=referent,
    directory + "/" + name,
    force_symlink=link_kind != "junction",
  ) catch {
    error =>
      fail(
        "infrastructure: Windows mv link fixture could not be created: \{error}",
      )
  }
  referent.replace_all(old="\\", new="/")
}

///|
fn assert_windows_mv_link(
  entries : ArrayView[@testkit.SnapshotEntry],
  path : String,
  link_kind : String,
  referent : String,
) -> Unit raise {
  guard entries.iter().find_first(entry => entry.path == path) is Some(entry) else {
    fail("missing Windows mv fixture link: " + path)
  }
  assert_eq(entry.kind, "symlink")
  assert_eq(
    entry.metadata.get("link-type"),
    Some(if link_kind == "junction" { "Junction" } else { "SymbolicLink" }),
  )
  // Junction targets may use the extended Windows path prefix.
  let target = entry.metadata.get("symlink-target").unwrap()
  let normalized = if target.has_prefix("//?/") {
    target[4:].to_owned()
  } else {
    target
  }
  assert_eq(normalized.to_lower(), referent.to_lower())
}

///|
fn expected_windows_mv_success(
  before : ArrayView[@testkit.SnapshotEntry],
  backup : Bool,
) -> Array[@testkit.SnapshotEntry] {
  let expected = before.filter(entry => {
    entry.path != "source" && entry.path != "target"
  })
  for entry in before {
    if entry.path == "source" {
      expected.push({ ..entry, path: "target", })
    } else if entry.path == "target" && backup {
      expected.push({ ..entry, path: "target~", })
    }
  }
  expected.sort_by_key(entry => entry.path)
  expected
}

///|
pub(all) struct OpenStdinObservation {
  run : @testkit.TimedRun
  exited_before_stdin_close : Bool
}

///|
pub fn open_stdin_observation_failures(
  observed : OpenStdinObservation,
) -> Array[String] {
  let failures = []
  if observed.run.timed_out {
    failures.push("child exceeded the open-stdin deadline")
  }
  if observed.run.cleanup_error is Some(error) {
    failures.push("child cleanup failed: " + error)
  }
  if !observed.exited_before_stdin_close {
    failures.push("exit was not observed before closing stdin")
  }
  failures
}

///|
// Retain the stdin writer until after child exit. Redirecting the two output
// streams to evidence files also retains any prompt if the deadline expires.
async fn observe_exit_with_open_stdin(
  program : String,
  args : Array[String],
  directory : String,
  trace : String,
  timeout_ms~ : Int32 = 5000,
) -> OpenStdinObservation {
  let (input, writer) = @process.write_to_process()
  defer writer.close()
  let output = @process.redirect_to_file(trace + ".stdout.bin")
  let error_output = @process.redirect_to_file(trace + ".stderr.bin")
  let status = Ref(-1)
  let exited_with_stdin_open = Ref(false)
  let cleanup_error : Ref[String?] = Ref(None)
  let started = @async.now()
  let finished = @async.with_timeout_opt(timeout_ms, () => {
    @async.with_task_group(group => {
      let child = @process.spawn(
        group,
        program,
        args,
        stdin=input,
        stdout=output,
        stderr=error_output,
        cwd=directory,
        no_wait=true,
        no_console_window=true,
        cancel_handler=@process.hard_cancel(),
      )
      group.add_defer(() => {
        child.cancel()
        @async.protect_from_cancel(() => {
          status.val = child.wait() catch {
            error => {
              cleanup_error.val = Some(error.to_string())
              -1
            }
          }
        })
      })
      status.val = child.wait()
      exited_with_stdin_open.val = true
    })
  })
  @fs.write_file(trace + ".status.txt", status.val.to_string())
  @fs.write_file(
    trace + ".stdin-lifecycle.json",
    @testkit.canonical_json({
      "stdin_bytes_sent": 0,
      "deadline_ms": timeout_ms,
      "elapsed_ms": @async.now() - started,
      "exit_observed_before_stdin_close": exited_with_stdin_open.val,
      "timed_out": finished is None,
      "cleanup_error": cleanup_error.val,
    }),
  )
  {
    run: {
      output: {
        status: status.val,
        stdout: @fs.read_file(trace + ".stdout.bin").binary(),
        stderr: @fs.read_file(trace + ".stderr.bin").binary(),
      },
      timed_out: finished is None,
      cleanup_error: cleanup_error.val,
    },
    exited_before_stdin_close: exited_with_stdin_open.val,
  }
}

///|
async fn windows_mv_open_stdin_controls(work : String) -> Unit {
  let program = @fs.realpath(@env.args()[0])
  let exited = observe_exit_with_open_stdin(
    program,
    ["--mv-test-helper", "status-124"],
    work,
    work + "/../stdin-control-exit",
  )
  assert_eq(open_stdin_observation_failures(exited), [])
  assert_eq(exited.run.output.status, 124)
  assert_eq(exited.run.output.stdout, b"")
  assert_eq(exited.run.output.stderr, b"")
  for mode in ["read-line", "capture-then-wait"] {
    let blocked = observe_exit_with_open_stdin(
      program,
      ["--mv-test-helper", mode],
      work,
      work + "/../stdin-control-" + mode,
      timeout_ms=1000,
    )
    assert_true(blocked.run.timed_out)
    assert_false(blocked.exited_before_stdin_close)
    assert_eq(blocked.run.cleanup_error, None)
    assert_false(open_stdin_observation_failures(blocked).is_empty())
    assert_eq(
      blocked.run.output.stdout,
      if mode == "read-line" {
        b""
      } else {
        b"partial stdout\n"
      },
    )
    assert_eq(
      blocked.run.output.stderr,
      if mode == "read-line" {
        b""
      } else {
        b"partial stderr\n"
      },
    )
  }
}

///|
async fn windows_mv_link_round(
  launch : Launch,
  work : String,
  link_kind : String,
  operation : String,
) -> Unit {
  let label = link_kind + "-" + operation
  let directory = work + "/" + label
  @fs.mkdir(directory)
  let directory = @fs.realpath(directory)
  let trace = work + "/../" + label
  let source_referent = if [
      "destination-link-backup", "destination-link-replace", "destination-link-interactive-refusal",
    ].contains(operation) {
    @fs.write_file(
      directory + "/source",
      b"regular source replaces destination link\n",
    )
    None
  } else {
    Some(prepare_windows_mv_link(directory, "source", link_kind))
  }
  let target_referent = if operation == "absent" {
    None
  } else {
    Some(prepare_windows_mv_link(directory, "target", link_kind))
  }
  let before = windows_mv_snapshot(directory, trace + ".before")
  if source_referent is Some(referent) {
    assert_windows_mv_link(before, "source", link_kind, referent)
  }
  if target_referent is Some(referent) {
    assert_windows_mv_link(before, "target", link_kind, referent)
  }
  let args = ["-T"]
  match operation {
    "no-clobber" => args.push("-n")
    "backup" | "destination-link-backup" => args.push("--backup=simple")
    "interactive-refusal" | "destination-link-interactive-refusal" => {
      args.push("-i")
      args.push("--backup=simple")
    }
    "backup-failure-recovery" => {
      args.push("--backup=simple")
      args.push("--suffix=/missing-parent/backup")
    }
    "absent" | "replace" | "destination-link-replace" => ()
    _ => fail("unknown Windows mv scenario operation")
  }
  args.push("source")
  args.push("target")
  let interactive = operation == "interactive-refusal" ||
    operation == "destination-link-interactive-refusal"
  let observed : OpenStdinObservation = if interactive {
    retain_launch(launch, args, trace)
    observe_exit_with_open_stdin(
      launch.program,
      launch.prefix + args,
      directory,
      trace,
    )
  } else {
    {
      run: {
        output: run_mv(launch, work, args, directory),
        timed_out: false,
        cleanup_error: None,
      },
      exited_before_stdin_close: false,
    }
  }
  let result = observed.run.output
  let after = windows_mv_snapshot(directory, trace + ".after")
  @fs.write_file(
    trace + ".command.json",
    @testkit.canonical_json({
      "operation": operation,
      "link_kind": link_kind,
      "backend": "wasm",
      "status": result.status,
      "args": args,
    }),
  )
  if interactive {
    let failures = open_stdin_observation_failures(observed)
    guard failures.is_empty() else {
      fail(
        "mv open-stdin observation failed: " +
        failures.join("; ") +
        "; see " +
        trace,
      )
    }
  }
  assert_eq(result.stdout, b"")
  if operation == "no-clobber" {
    assert_eq(result.status, 0)
    assert_eq(result.stderr, b"")
    assert_true(@testkit.snapshots_equal(before, after))
  } else if operation != "destination-link-replace" {
    assert_eq(result.status, 1)
    assert_true(
      @utf8.decode(result.stderr).contains(
        "unsupported capability: Windows Wasm symlink/junction rename requires a verified host fix",
      ),
    )
    if interactive {
      assert_false(@utf8.decode(result.stderr).contains("overwrite '"))
    }
    assert_true(@testkit.snapshots_equal(before, after))
  } else {
    assert_eq(result.status, 0)
    assert_eq(result.stderr, b"")
    assert_true(
      @testkit.snapshots_equal(
        expected_windows_mv_success(
          before,
          operation == "backup" || operation == "destination-link-backup",
        ),
        after,
      ),
    )
  }
}

///|
pub async fn run(launch : Launch, work : String) -> Unit {
  guard @async.platform is Windows else {
    fail("Windows mv scenario selected on another platform")
  }
  windows_mv_open_stdin_controls(work)
  for link_kind in ["file", "directory", "dangling", "junction"] {
    for
      operation in [
        "absent", "replace", "no-clobber", "backup", "destination-link-backup", "destination-link-replace",
        "backup-failure-recovery", "interactive-refusal", "destination-link-interactive-refusal",
      ] {
      windows_mv_link_round(launch, work, link_kind, operation) catch {
        error => fail("\{link_kind}/\{operation}: \{error}")
      }
    }
  }
}
