///|
async fn scenario_read_exact(
  reader : &@io.Reader,
  trace : String,
  expected : String,
) -> Unit {
  let expected = @utf8.encode(expected)
  let mut offset = 0
  while offset < expected.length() {
    guard reader.read_some(max_len=expected.length() - offset) is Some(bytes) else {
      fail("unexpected stream EOF")
    }
    @fs.write_file(trace, bytes, append=true)
    assert_eq(bytes, expected[offset:offset + bytes.length()].to_owned())
    offset += bytes.length()
  }
}

///|
async fn scenario_run(
  work : String,
  root : String,
  wasm : Bool,
  command : String,
  args : Array[String],
  stdin? : Bytes = b"",
  cwd? : String,
  extra_env? : Map[String, String] = Map([]),
) -> @testkit.RunResult {
  let traces = @path.Path(work).dirname().join(Path("streams")).to_string()
  if !@fs.exists(traces) {
    @fs.mkdir(traces, recursive=true)
  }
  let prefix = traces + "/" + command + "-\{@fs.readdir(traces).length()}"
  let completed = @testkit.run_with_deadline(
    if wasm {
      "moonrun"
    } else {
      @testkit.executable_path(root, command)
    },
    if wasm {
      [@testkit.wasm_path(root, command), "--", ..args]
    } else {
      args
    },
    15000,
    stdin~,
    cwd?,
    extra_env~,
  )
  @fs.write_file(prefix + ".stdout.bin", completed.output.stdout)
  @fs.write_file(prefix + ".stderr.bin", completed.output.stderr)
  if completed.cleanup_error is Some(error) {
    fail("cleanup infrastructure: " + error)
  }
  if completed.timed_out {
    fail("scenario command deadline expired; streams are partial")
  }
  completed.output
}

///|
fn shell_quote(value : String) -> String {
  "'" + value.replace_all(old="'", new="'\\''") + "'"
}

///|
async fn run_test_helper(args : ArrayView[String]) -> Unit {
  match args {
    ["environment", name] =>
      @stdio.stdout.write(@env.get_env_var(name).unwrap_or("") + "\n")
    ["wait-ready"] => {
      @stdio.stdout.write("ready\n")
      @async.sleep(60000)
    }
    ["capture-then-wait"] => {
      @stdio.stdout.write("partial stdout\n")
      @stdio.stderr.write("partial stderr\n")
      @async.sleep(60000)
    }
    ["status-124"] => @sys.exit(124)
    ["read-line"] =>
      for ;; {
        guard @stdio.stdin.read_some(max_len=1) is Some(byte) else { break }
        @stdio.stdout.write(byte)
        if byte == b"\n" {
          break
        }
      }
    ["ready", root, name] => {
      @fs.write_file(root + "/" + name + ".ready", "ready")
      @async.with_timeout(10000, () => {
        while !@fs.exists(root + "/" + name + ".ack") {
          @async.sleep(5)
        }
      })
      @fs.write_file(root + "/" + name + ".done", "done")
    }
    _ => fail("unknown test helper")
  }
}

///|
async fn shell_interactive_scenario(
  root : String,
  wasm : Bool,
  work : String,
) -> Unit {
  let startup = work + "/startup.sh"
  @fs.write_file(startup, "STARTUP=loaded\n")
  let program = if wasm {
    "moonrun"
  } else {
    @testkit.executable_path(root, "sh")
  }
  let args = if wasm {
    [@testkit.wasm_path(root, "sh"), "--", "-i"]
  } else {
    ["-i"]
  }
  @async.with_task_group(group => {
    let (stdin, writer) = @process.write_to_process()
    let (stdout, output) = @process.read_from_process()
    let (stderr, error) = @process.read_from_process()
    let child = @process.spawn(
      group,
      program,
      args,
      stdin~,
      stdout=output,
      stderr=error,
      cwd=work,
      extra_env={ "PS1": "P> ", "PS2": "C> ", "ENV": startup },
      cancel_handler=@process.hard_cancel(),
    )
    group.add_defer(() => {
      writer.close()
      stdout.close()
      stderr.close()
      child.cancel()
      @async.protect_from_cancel(() => ignore(child.wait()))
    })
    scenario_read_exact(stderr, work + "/../stderr.bin", "P> ")
    writer.write("VALUE=kept\n")
    scenario_read_exact(stderr, work + "/../stderr.bin", "P> ")
    writer.write("printf '%s|%s\\n' \"$VALUE\" \"$STARTUP\"\n")
    scenario_read_exact(stdout, work + "/../stdout.bin", "kept|loaded\n")
    scenario_read_exact(stderr, work + "/../stderr.bin", "P> ")
    for
      (line, prompt) in [
        ("if true; then\n", "C> "),
        ("printf 'multiline\\n'\n", "C> "),
      ] {
      writer.write(line)
      scenario_read_exact(stderr, work + "/../stderr.bin", prompt)
    }
    writer.write("fi\n")
    scenario_read_exact(stdout, work + "/../stdout.bin", "multiline\n")
    scenario_read_exact(stderr, work + "/../stderr.bin", "P> ")
    writer.write("read ANSWER\nhello foreground\n")
    scenario_read_exact(stderr, work + "/../stderr.bin", "P> ")
    writer.write("printf 'read=<%s>\\n' \"$ANSWER\"\n")
    scenario_read_exact(
      stdout,
      work + "/../stdout.bin",
      "read=<hello foreground>\n",
    )
    scenario_read_exact(stderr, work + "/../stderr.bin", "P> ")
    writer.write(
      shell_quote(@fs.realpath(@env.args()[0])) +
      " --test-helper read-line\nchild input\n",
    )
    scenario_read_exact(stdout, work + "/../stdout.bin", "child input\n")
    scenario_read_exact(stderr, work + "/../stderr.bin", "P> ")
    writer.write("f() { printf 'function:%s\\n' \"$VALUE\"; }\n")
    scenario_read_exact(stderr, work + "/../stderr.bin", "P> ")
    writer.write("f\n")
    scenario_read_exact(stdout, work + "/../stdout.bin", "function:kept\n")
    scenario_read_exact(stderr, work + "/../stderr.bin", "P> ")
    @fs.mkdir(work + "/sub")
    writer.write("cd sub\n")
    scenario_read_exact(stderr, work + "/../stderr.bin", "P> ")
    writer.write("pwd\n")
    scenario_read_exact(
      stdout,
      work + "/../stdout.bin",
      @path.Path(work).join(Path("sub")).to_string() + "\n",
    )
    scenario_read_exact(stderr, work + "/../stderr.bin", "P> ")
    writer.write(")\n")
    scenario_read_exact(
      stderr,
      work + "/../stderr.bin",
      "sh: unexpected closing token\nP> ",
    )
    writer.write("printf 'recovered\\n'\n")
    scenario_read_exact(stdout, work + "/../stdout.bin", "recovered\n")
    scenario_read_exact(stderr, work + "/../stderr.bin", "P> ")
    writer.close()
    assert_eq(child.wait(), 0)
    assert_eq(stdout.read_all().binary(), b"")
    assert_eq(stderr.read_all().binary(), b"")
  })
  let exited = scenario_run(
    work,
    root,
    wasm,
    "sh",
    ["-i"],
    stdin=b"exit 7\nprintf never",
    cwd=work,
    extra_env={ "PS1": "P> ", "PS2": "C> ", "ENV": startup },
  )
  assert_eq(exited.status, 7)
  assert_eq(exited.stdout, b"")
  assert_eq(exited.stderr, b"P> ")
}

///|
async fn make_concurrency_scenario(
  root : String,
  wasm : Bool,
  work : String,
) -> Unit {
  @fs.write_file(
    work + "/Makefile",
    "VALUE := $(shell printf 'one\\ntwo\\n')\nall:\n\t@printf '%s\\n' '$(VALUE)'\n",
  )
  let expanded = scenario_run(work, root, wasm, "make", ["-C", work], stdin=b"")
  assert_eq(expanded.status, 0)
  assert_eq(expanded.stdout, b"one two\n")
  assert_eq(expanded.stderr, b"")
  let helper = shell_quote(@fs.realpath(@env.args()[0])) +
    " --test-helper ready " +
    shell_quote(work)
  @fs.write_file(
    work + "/Makefile",
    ".PHONY: all shared left right\nall: left right\nshared:\n\t@printf S >> events\nleft: shared\n\t@" +
    helper +
    " left\nright: shared\n\t@" +
    helper +
    " right\n",
  )
  @async.with_task_group(group => {
    let task = group.spawn(() => {
      scenario_run(work, root, wasm, "make", ["-j2", "-C", work], stdin=b"")
    })
    // ACK only after both recipes are running. Scheduler speed is irrelevant.
    while !(@fs.exists(work + "/left.ready") &&
          @fs.exists(work + "/right.ready")) {
      @async.sleep(5)
    }
    assert_eq(@fs.read_file(work + "/events").binary(), b"S")
    assert_false(@fs.exists(work + "/left.done"))
    assert_false(@fs.exists(work + "/right.done"))
    @fs.write_file(work + "/left.ack", "ack")
    @fs.write_file(work + "/right.ack", "ack")
    let result = task.wait()
    assert_eq(result.status, 0)
    assert_eq(result.stdout, b"")
    assert_eq(result.stderr, b"")
    assert_true(@fs.exists(work + "/left.done"))
    assert_true(@fs.exists(work + "/right.done"))
    assert_eq(@fs.read_file(work + "/events").binary(), b"S")
  })
  @fs.write_file(
    work + "/Makefile",
    ".PHONY: all broken\nall: broken\n\t@printf wrong > forbidden\nbroken:\n\t@false\n",
  )
  let stopped = scenario_run(
    work,
    root,
    wasm,
    "make",
    ["-j2", "-C", work],
    stdin=b"",
  )
  assert_eq(stopped.status, 2)
  assert_eq(stopped.stdout, b"")
  assert_false(@fs.exists(work + "/forbidden"))
  @fs.write_file(
    work + "/Makefile",
    ".PHONY: all broken after independent\nall: after independent\nafter: broken\n\t@printf wrong > forbidden\nbroken:\n\t@false\nindependent:\n\t@printf done > independent\n",
  )
  let failed = scenario_run(
    work,
    root,
    wasm,
    "make",
    ["-j2", "-k", "-C", work],
    stdin=b"",
  )
  assert_eq(failed.status, 2)
  assert_eq(failed.stdout, b"")
  assert_false(@fs.exists(work + "/forbidden"))
  assert_eq(@fs.read_file(work + "/independent").binary(), b"done")
}

///|
async fn execute_scenario(
  fixture : OracleCase,
  root : String,
  wasm : Bool,
  report_dir : String,
  oracle_image? : String,
) -> @testkit.CaseReport {
  let start = @async.now()
  if !fixture.platform_applies() {
    let report = suite_report(
      fixture.id,
      if wasm {
        "wasm"
      } else {
        "native"
      },
      start,
      [],
    )
    return {
      ..report,
      command: fixture.command,
      result: "skip",
      verification: if oracle_image is Some(_) {
        "differential"
      } else {
        "contract"
      },
      stage: "platform",
      detail: "case applies only to: " +
      fixture.host_platforms.unwrap_or([]).join(", "),
      observations: [],
    }
  }
  guard @testkit.safe_relative_path(fixture.id) else { fail("unsafe case ID") }
  let evidence = report_dir + "/" + fixture.id
  if @fs.exists(evidence) {
    fail("evidence already exists; use a fresh report directory")
  }
  let work = evidence + "/work"
  @fs.mkdir(work, recursive=true)
  let failures : Array[String] = []
  let completed = @async.with_timeout_opt(
    fixture.timeout_ms.unwrap_or(
      if oracle_image is Some(_) {
        120000
      } else {
        15000
      },
    ),
    () => {
      match fixture.id {
        "sh-interactive-session" => shell_interactive_scenario(root, wasm, work)
        "make-ready-ack" => make_concurrency_scenario(root, wasm, work)
        "filesystem-fidelity" => filesystem_fidelity_scenario(root, wasm, work)
        "process-lifecycle" => process_lifecycle_scenario(root, wasm, work)
        "network-auth-cookie" => network_cli_scenario(root, wasm, work)
        "network-auth-cookie-oracle" =>
          network_cli_scenario(root, wasm, work, oracle_image?)
        _ => fail("unknown scenario: " + fixture.id)
      }
    },
  ) catch {
    error => {
      failures.push(error.to_string())
      Some(())
    }
  }
  if completed is None {
    failures.push("scenario deadline expired")
  }
  let report = suite_report(
    fixture.id,
    if wasm {
      "wasm"
    } else {
      "native"
    },
    start,
    failures,
  )
  let mut cleanup_error = false
  if failures.is_empty() {
    @async.protect_from_cancel(() => @fs.rmdir(evidence, recursive=true)) catch {
      error => {
        cleanup_error = true
        failures.push(error.to_string())
      }
    }
  }
  let infrastructure = cleanup_error ||
    failures.any(error => {
      error.contains("infrastructure") ||
      error.contains("no such file") ||
      error.contains("No such file")
    })
  {
    ..report,
    command: fixture.command,
    result: if infrastructure {
      "infra"
    } else {
      report.result
    },
    verification: if oracle_image is Some(_) {
      "differential"
    } else {
      "contract"
    },
    source_version: fixture.source_version.unwrap_or("workspace 0.2.0"),
    detail: failures.join("; "),
    stage: if cleanup_error {
      "cleanup"
    } else if completed is None {
      "timeout"
    } else if infrastructure {
      "infrastructure"
    } else if failures.is_empty() {
      "complete"
    } else {
      "assertion"
    },
    evidence: if failures.is_empty() {
      None
    } else {
      Some(evidence)
    },
  }
}
