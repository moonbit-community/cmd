///|
pub async fn check_tee_modes(
  program : String,
  prefix : Array[String],
  work : String,
  default_only~ : Bool = false,
) -> Unit {
  let modes = if default_only {
    [
      (
        "default",
        [],
        2,
        b"",
        "tee: unsupported capability: SIGPIPE termination\n",
      ),
    ]
  } else {
    [
      ("p", ["-p"], 0, b"abc", ""),
      (
        "warn",
        ["--output-error=warn"],
        1,
        b"abc",
        "tee: 'standard output': Broken pipe\n",
      ),
      ("warn-nopipe", ["--output-error=warn-nopipe"], 0, b"abc", ""),
      (
        "exit",
        ["--output-error=exit"],
        1,
        b"",
        "tee: 'standard output': Broken pipe\n",
      ),
      ("exit-nopipe", ["--output-error=exit-nopipe"], 0, b"abc", ""),
    ]
  }
  let receipts : Array[Json] = []
  for (name, flags, status, expected, diagnostic) in modes {
    let cwd = work + "/" + name
    @fs.mkdir(cwd)
    let run = @async.with_timeout(15000, () => {
      @async.with_task_group(group => {
        let (input, writer) = @process.write_to_process()
        let (closed, output) = @process.read_from_process()
        let (errors, error_output) = @process.read_from_process()
        closed.close()
        let args = [..prefix, ..flags, "sink"]
        @fs.write_file(
          work + "/" + name + ".launch.json",
          canonical_json({
            "program": Json(program),
            "args": Json(args),
            "cwd": Json(cwd),
          }),
        )
        let child = @process.spawn(
          group,
          program,
          args,
          stdin=input,
          stdout=output,
          stderr=error_output,
          cwd~,
          extra_env=controlled_environment(Map([])),
          cancel_handler=@process.hard_cancel(),
        )
        group.add_defer(() => {
          writer.close()
          errors.close()
          child.cancel()
          @async.protect_from_cancel(() => ignore(child.wait()))
        })
        writer.write(b"abc")
        writer.close()
        let code = child.wait()
        let stderr = errors.read_all().binary()
        { status: code, stdout: b"", stderr, }
      })
    })
    @fs.write_file(work + "/" + name + ".status", run.status.to_string())
    @fs.write_file(work + "/" + name + ".stderr", run.stderr)
    assert_eq(run.status, status)
    assert_eq(run.stderr, @utf8.encode(diagnostic))
    let kind = @fs.kind(cwd + "/sink", follow_symlink=false)
    let content = @fs.read_file(cwd + "/sink").binary()
    assert_eq(kind, Regular)
    assert_eq(content, expected)
    receipts.push({
      "mode": Json(name),
      "flags": Json(flags),
      "status": Json(run.status),
      "stderr": Json(@utf8.decode(run.stderr)),
      "sink_kind": Json(kind_name(kind)),
      "sink_content": Json(@utf8.decode(content)),
    })
  }
  @fs.write_file(
    work + "/tee-relations.json",
    canonical_json({ "modes": Json(receipts) }),
  )
}

///|
pub async fn check_tee_oracle(work : String, image : String) -> Unit {
  @fs.mkdir(work)
  let helper = option_child_path()
  let run = run_oracle_with_deadline(
    "docker",
    [
      "run",
      "--rm",
      "-i",
      "--user",
      docker_user(),
      "-v",
      work + ":" + work + ":rw",
      "-v",
      helper + ":" + helper + ":ro",
      "-w",
      work,
      image,
      helper,
      "--option-test-helper",
      "tee-modes",
      "/oracle/bin/tee",
      work,
    ],
    30000,
    evidence_dir=work + "-lifecycle",
    stdin=b"",
  )
  @fs.write_file(work + ".stdout", run.output.stdout)
  @fs.write_file(work + ".stderr", run.output.stderr)
  guard !run.timed_out && run.cleanup_error is None else {
    fail("tee oracle lifecycle infrastructure failure")
  }
  assert_eq(run.output.status, 0)
  assert_eq(run.output.stdout, b"")
  assert_eq(run.output.stderr, b"")
}
