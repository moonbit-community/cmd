///|
async fn shell_interactive_scenario(
  root : String,
  work : String,
  proof? : @harness.ScenarioProof,
) -> Unit {
  let startup = work + "/startup.sh"
  @fs.write_file(startup, "STARTUP=loaded\n")
  let program = @harness.command_program()
  let args = @harness.command_args(root, "sh", ["-i"])
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
    scenario_read_exact(
      stderr,
      work + "/../stderr.bin",
      "P> ",
      proof?,
      assertion_id="sh/prompt",
    )
    writer.write("VALUE=kept\n")
    scenario_read_exact(stderr, work + "/../stderr.bin", "P> ")
    writer.write("printf '%s|%s\\n' \"$VALUE\" \"$STARTUP\"\n")
    scenario_read_exact(
      stdout,
      work + "/../stdout.bin",
      "kept|loaded\n",
      proof?,
      assertion_id="sh/startup-state",
    )
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
    scenario_read_exact(
      stdout,
      work + "/../stdout.bin",
      "multiline\n",
      proof?,
      assertion_id="sh/multiline",
    )
    scenario_read_exact(stderr, work + "/../stderr.bin", "P> ")
    writer.write("read ANSWER\nhello foreground\n")
    scenario_read_exact(stderr, work + "/../stderr.bin", "P> ")
    writer.write("printf 'read=<%s>\\n' \"$ANSWER\"\n")
    scenario_read_exact(
      stdout,
      work + "/../stdout.bin",
      "read=<hello foreground>\n",
      proof?,
      assertion_id="sh/foreground-read",
    )
    scenario_read_exact(stderr, work + "/../stderr.bin", "P> ")
    writer.write(
      shell_quote(@fs.realpath(@env.args()[0])) +
      " --test-helper read-line\nchild input\n",
    )
    scenario_read_exact(
      stdout,
      work + "/../stdout.bin",
      "child input\n",
      proof?,
      assertion_id="sh/child-stdin",
    )
    scenario_read_exact(stderr, work + "/../stderr.bin", "P> ")
    writer.write("f() { printf 'function:%s\\n' \"$VALUE\"; }\n")
    scenario_read_exact(stderr, work + "/../stderr.bin", "P> ")
    writer.write("f\n")
    scenario_read_exact(
      stdout,
      work + "/../stdout.bin",
      "function:kept\n",
      proof?,
      assertion_id="sh/function-state",
    )
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
    scenario_read_exact(
      stdout,
      work + "/../stdout.bin",
      "recovered\n",
      proof?,
      assertion_id="sh/recovery",
    )
    scenario_read_exact(stderr, work + "/../stderr.bin", "P> ")
    writer.close()
    let status = child.wait()
    @fs.write_file(work + "/../interactive.status.txt", status.to_string())
    assert_eq(status, 0)
    let remaining_stdout = stdout.read_all().binary()
    let remaining_stderr = stderr.read_all().binary()
    assert_eq(remaining_stdout, b"")
    assert_eq(remaining_stderr, b"")
    if proof is Some(proof) {
      proof.observe_equal(
        "sh/eof",
        "sh",
        {
          "status": status,
          "stdout": @harness.scenario_text(remaining_stdout),
          "stderr": @harness.scenario_text(remaining_stderr),
        },
        { "status": 0, "stdout": "", "stderr": "" },
      )
    }
  })
  let exited = scenario_run(
    work,
    root,
    "sh",
    ["-i"],
    stdin=b"exit 7\nprintf never",
    cwd=work,
    extra_env={ "PS1": "P> ", "PS2": "C> ", "ENV": startup },
  )
  assert_eq(exited.status, 7)
  assert_eq(exited.stdout, b"")
  assert_eq(exited.stderr, b"P> ")
  if proof is Some(proof) {
    proof.observe_equal(
      "sh/exit",
      "sh",
      {
        "status": exited.status,
        "stdout": @harness.scenario_text(exited.stdout),
        "stderr": @harness.scenario_text(exited.stderr),
      },
      { "status": 7, "stdout": "", "stderr": "P> " },
    )
  }
}
