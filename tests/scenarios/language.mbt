///|
async fn shell_language_session_scenario(root : String, work : String) -> Unit {
  @async.with_task_group(group => {
    let (stdin, writer) = @process.write_to_process()
    let (stdout, output) = @process.read_from_process()
    let (stderr, error) = @process.read_from_process()
    let child = @process.spawn(
      group,
      @harness.command_program(),
      @harness.command_args(root, "sh", ["-i"]),
      stdin~,
      stdout=output,
      stderr=error,
      cwd=work,
      extra_env={ "PS1": "P> ", "PS2": "C> ", "ENV": "" },
      cancel_handler=@process.hard_cancel(),
    )
    group.add_defer(() => {
      writer.close()
      stdout.close()
      stderr.close()
      child.cancel()
      @async.protect_from_cancel(() => ignore(child.wait()))
    })
    let out_trace = work + "/../language.stdout.bin"
    let err_trace = work + "/../language.stderr.bin"
    scenario_read_exact(stderr, err_trace, "P> ")
    writer.write("value=$(case x in\n")
    scenario_read_exact(stderr, err_trace, "C> ")
    writer.write("x)\n")
    scenario_read_exact(stderr, err_trace, "C> ")
    writer.write("printf case-ok;;\n")
    scenario_read_exact(stderr, err_trace, "C> ")
    writer.write("esac); printf '<%s>' \"$value\"\n")
    scenario_read_exact(
      stdout,
      out_trace,
      "<case-ok>",
      assertion_id="sh/language-case-continuation",
    )
    scenario_read_exact(stderr, err_trace, "P> ")
    writer.write("a=2; : $((a+=3))\n")
    scenario_read_exact(stderr, err_trace, "P> ")
    writer.write("value=`printf '%s' \\\n")
    scenario_read_exact(stderr, err_trace, "C> ")
    writer.write(" ready`; printf '%s|%s\\n' \"$a\" \"$value\"\n")
    scenario_read_exact(
      stdout,
      out_trace,
      "5|ready\n",
      assertion_id="sh/language-backtick-state",
    )
    scenario_read_exact(stderr, err_trace, "P> ")
    writer.write(
      "copy() { while IFS= read -r line; do printf '%s\\n' \"$line\"; done; }; copy <<EOF\n",
    )
    scenario_read_exact(stderr, err_trace, "C> ")
    writer.write("$a|$(printf body)|$((a+1))\n")
    scenario_read_exact(stderr, err_trace, "C> ")
    writer.write("EOF\n")
    scenario_read_exact(
      stdout,
      out_trace,
      "5|body|6\n",
      assertion_id="sh/language-heredoc-state",
    )
    scenario_read_exact(stderr, err_trace, "P> ")
    writer.write("printf before; : $((1/0))\n")
    scenario_read_exact(
      stdout,
      out_trace,
      "before",
      assertion_id="sh/language-prefix-before-failure",
    )
    scenario_read_exact(
      stderr,
      err_trace,
      "sh: arithmetic division by zero\nP> ",
      assertion_id="sh/language-arithmetic-recovery",
    )
    writer.write("printf '%s|%s\\n' \"$?\" \"$a\"\n")
    scenario_read_exact(
      stdout,
      out_trace,
      "2|5\n",
      assertion_id="sh/language-preserved-status",
    )
    scenario_read_exact(stderr, err_trace, "P> ")
    writer.write(
      "a=parent; printf 'child\\n' | read a; printf '%s\\n' \"$a\"\n",
    )
    scenario_read_exact(
      stdout,
      out_trace,
      "parent\n",
      assertion_id="sh/language-pipeline-scope",
    )
    scenario_read_exact(stderr, err_trace, "P> ")
    writer.write("test bad -eq 1\n")
    scenario_read_exact(stderr, err_trace, "sh: test: integer expected\nP> ")
    writer.write("printf 'recovered:%s\\n' \"$?\"\n")
    scenario_read_exact(
      stdout,
      out_trace,
      "recovered:2\n",
      assertion_id="sh/language-test-recovery",
    )
    scenario_read_exact(stderr, err_trace, "P> ")
    writer.close()
    let status = child.wait()
    let trailing_output = stdout.read_all().binary()
    let trailing_error = stderr.read_all().binary()
    assert_eq(status, 0)
    assert_eq(trailing_output, b"")
    assert_eq(trailing_error, b"")

    @harness.assert_observation(
      "sh/language-eof",
      "sh",
      {
        "status": status,
        "stdout": @harness.scenario_text(trailing_output),
        "stderr": @harness.scenario_text(trailing_error),
      },
      { "status": 0, "stdout": "", "stderr": "" },
    )
  })
}

///|
async fn shell_merged_child_scenario(root : String, work : String) -> Unit {
  let helper = @fs.realpath(@env.args()[0])
  let expected = StringBuilder()
  for _ in 0..<64 {
    expected.write_string("out-one\nerr-one\nout-two\nerr-two\n")
  }
  for (name, redirect) in [("output", "2>&1"), ("input", "2<&1")] {
    let result = scenario_run(
      work,
      root,
      "sh",
      [
        "-c",
        shell_quote(helper) + " --test-helper alternating-streams " + redirect,
      ],
      cwd=work,
    )
    assert_eq(result.status, 7)
    assert_eq(result.stdout, @utf8.encode(expected.to_string()))
    assert_eq(result.stderr, b"")

    @harness.assert_observation(
      "sh/merged-" + name,
      "sh",
      {
        "status": result.status,
        "stdout": @harness.scenario_text(result.stdout),
        "stderr": @harness.scenario_text(result.stderr),
      },
      { "status": 7, "stdout": expected.to_string(), "stderr": "" },
    )
  }
  let result = scenario_run(
    work,
    root,
    "sh",
    [
      "-c",
      "a=1; export a; " +
      shell_quote(helper) +
      " --test-helper environment a >$((a=2)); printf '|%s' \"$a\"",
    ],
    cwd=work,
  )
  let actual = @fs.read_file(work + "/2").binary()
  assert_eq(result.status, 0)
  assert_eq(result.stdout, b"|2")
  assert_eq(result.stderr, b"")
  assert_eq(actual, b"2\n")

  @harness.assert_observation(
    "sh/redirect-child-environment",
    "sh",
    {
      "status": result.status,
      "stdout": @harness.scenario_text(result.stdout),
      "stderr": @harness.scenario_text(result.stderr),
      "file": @harness.scenario_text(actual),
    },
    { "status": 0, "stdout": "|2", "stderr": "", "file": "2\n" },
  )
}

///|
async fn make_recursive_language_scenario(root : String, work : String) -> Unit {
  @fs.write_file(work + "/Makefile", "all:\n\t@$(MAKE) -f Child.mk\n")
  @fs.write_file(
    work + "/Child.mk",
    "all:\n\t@printf '%s|%s|<%s>|<%s>\\n' '$(MAKELEVEL)' \"$$MAKELEVEL\" '$(VALUE)' '$(-X)'\n\t@printf done > marker\n",
  )
  let result = scenario_run(
    work,
    root,
    "make",
    ["--", "VALUE=$$MARK", "-X=two words", "all"],
    cwd=work,
    extra_env={ "MAKELEVEL": "0", "MAKEFLAGS": "" },
  )
  let marker = @fs.read_file(work + "/marker").text()
  assert_eq(result.status, 0)
  assert_eq(result.stdout, b"1|2|<$MARK>|<two words>\n")
  assert_eq(result.stderr, b"")
  assert_eq(marker, "done")

  @harness.assert_observation(
    "make/recursive-language",
    "make",
    {
      "status": result.status,
      "stdout": @harness.scenario_text(result.stdout),
      "stderr": @harness.scenario_text(result.stderr),
      "marker": marker,
    },
    {
      "status": 0,
      "stdout": "1|2|<$MARK>|<two words>\n",
      "stderr": "",
      "marker": "done",
    },
  )
}
