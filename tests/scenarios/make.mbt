///|
async fn make_concurrency_scenario(root : String, work : String) -> Unit {
  @fs.write_file(
    work + "/Makefile",
    "VALUE := $(shell printf 'one\\ntwo\\n')\nall:\n\t@printf '%s\\n' '$(VALUE)'\n",
  )
  let expanded = scenario_run(work, root, "make", ["-C", work], stdin=b"")
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
      scenario_run(work, root, "make", ["-j2", "-C", work], stdin=b"")
    })
    // ACK only after both recipes are running. Scheduler speed is irrelevant.
    while !(@fs.exists(work + "/left.ready") &&
          @fs.exists(work + "/right.ready")) {
      @async.sleep(5)
    }
    assert_eq(@fs.read_file(work + "/events").binary(), b"S")
    assert_false(@fs.exists(work + "/left.done"))
    assert_false(@fs.exists(work + "/right.done"))

    @harness.assert_observation(
      "make/jobs-before-ack",
      "make",
      {
        "ready": [
          @fs.exists(work + "/left.ready"),
          @fs.exists(work + "/right.ready"),
        ],
        "done": [
          @fs.exists(work + "/left.done"),
          @fs.exists(work + "/right.done"),
        ],
        "shared": @fs.read_file(work + "/events").text(),
      },
      { "ready": [true, true], "done": [false, false], "shared": "S" },
    )

    @fs.write_file(work + "/left.ack", "ack")
    @fs.write_file(work + "/right.ack", "ack")
    let result = task.wait()
    assert_eq(result.status, 0)
    assert_eq(result.stdout, b"")
    assert_eq(result.stderr, b"")
    assert_true(@fs.exists(work + "/left.done"))
    assert_true(@fs.exists(work + "/right.done"))
    assert_eq(@fs.read_file(work + "/events").binary(), b"S")

    @harness.assert_observation(
      "make/jobs-after-ack",
      "make",
      {
        "status": result.status,
        "stdout": @harness.scenario_text(result.stdout),
        "stderr": @harness.scenario_text(result.stderr),
        "done": [
          @fs.exists(work + "/left.done"),
          @fs.exists(work + "/right.done"),
        ],
        "shared": @fs.read_file(work + "/events").text(),
      },
      {
        "status": 0,
        "stdout": "",
        "stderr": "",
        "done": [true, true],
        "shared": "S",
      },
    )
  })
  @fs.write_file(
    work + "/Makefile",
    ".PHONY: all broken\nall: broken\n\t@printf wrong > forbidden\nbroken:\n\t@false\n",
  )
  let stopped = scenario_run(work, root, "make", ["-j2", "-C", work], stdin=b"")
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
    "make",
    ["-j2", "-k", "-C", work],
    stdin=b"",
  )
  assert_eq(failed.status, 2)
  assert_eq(failed.stdout, b"")
  assert_false(@fs.exists(work + "/forbidden"))
  assert_eq(@fs.read_file(work + "/independent").binary(), b"done")

  @harness.assert_observation(
    "make/keep-going",
    "make",
    {
      "status": failed.status,
      "stdout": @harness.scenario_text(failed.stdout),
      "forbidden": @fs.exists(work + "/forbidden"),
      "independent": @fs.read_file(work + "/independent").text(),
    },
    { "status": 2, "stdout": "", "forbidden": false, "independent": "done" },
  )

  @fs.write_file(
    work + "/Makefile",
    ".PHONY: all broken independent\nall: broken independent\nbroken:\n\t@false\nindependent:\n\t@printf done > sequential-independent\n",
  )
  let stopped_sequential = scenario_run(work, root, "make", ["-j1", "-C", work])
  assert_eq(stopped_sequential.status, 2)
  assert_eq(stopped_sequential.stdout, b"")
  assert_false(@fs.exists(work + "/sequential-independent"))

  @harness.assert_observation(
    "make/stop-before-independent",
    "make",
    {
      "status": stopped_sequential.status,
      "stdout": @harness.scenario_text(stopped_sequential.stdout),
      "independent_exists": @fs.exists(work + "/sequential-independent"),
    },
    { "status": 2, "stdout": "", "independent_exists": false },
  )

  let continued_sequential = scenario_run(work, root, "make", [
    "-j1", "-k", "-C", work,
  ])
  assert_eq(continued_sequential.status, 2)
  assert_eq(continued_sequential.stdout, b"")
  assert_eq(@fs.read_file(work + "/sequential-independent").text(), "done")

  @harness.assert_observation(
    "make/keep-going-sequential",
    "make",
    {
      "status": continued_sequential.status,
      "stdout": @harness.scenario_text(continued_sequential.stdout),
      "independent": @fs.read_file(work + "/sequential-independent").text(),
    },
    { "status": 2, "stdout": "", "independent": "done" },
  )
}
