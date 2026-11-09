///|
test "worker reuse requires compatible scoped mounts and no leftover processes" {
  let image = "sha256:" + "a".repeat(64)
  let plan = oracle_exec_plan(
    [
      "run", "--rm", "-i", "-v", "/reports/case:/reports/case:rw", "-w", "/reports/case",
      "-e", "LANG=C", image, "cat",
    ],
    "/reports",
    image,
  ).unwrap()
  assert_eq(plan.command, ["cat"])
  assert_eq(plan.directory, Some("/reports/case"))
  assert_eq(plan.environment, ["-e", "LANG=C"])
  for
    volume in [
      "/reports/case:/work:rw", "/outside:/outside:rw", "/reports:/reports:ro", "/reports/case/../other:/reports/case/../other:rw",
    ] {
    assert_true(
      oracle_exec_plan(
        ["run", "--rm", "-v", volume, image, "cat"],
        "/reports",
        image,
      )
      is None,
    )
  }
  for source in ["/reports/case", "/isolated/metadata"] {
    let volume = source + ":" + source + ":ro"
    let plan = oracle_exec_plan(
      ["run", "--rm", "-v", volume, "-w", source, image, "find", "."],
      "/reports",
      image,
    ).unwrap()
    assert_true(plan.configuration.contains(volume))
    assert_false(plan.configuration.contains(source + ":" + source + ":rw"))
    assert_eq(plan.directory, Some(source))
    assert_true(
      oracle_exec_plan(
        [
          "run",
          "--rm",
          "-v",
          volume,
          "-w",
          source + "/../other",
          image,
          "find",
          ".",
        ],
        "/reports",
        image,
      )
      is None,
    )
  }
  assert_true(
    oracle_exec_plan(
      ["run", "--rm", "-w", "/undeclared", image, "cat"],
      "/reports",
      image,
    )
    is None,
  )
  assert_true(oracle_worker_is_idle(b"PID\n 123\n"))
  for output in [b"PID\n123\n456\n", b"PID\n", b"PID\ninvalid\n", b""] {
    assert_false(oracle_worker_is_idle(output))
  }
}

///|
async test "worker reuses clean invocations and destroys timed out or leaking workers" {
  for mode in ["clean", "timeout", "leak", "observation", "cleanup"] {
    let root = @fs.tmpdir(prefix="oracle-pool-test-")
    defer @fs.rmdir(root, recursive=true)
    let root = @fs.realpath(root)
    let image = "sha256:" + "a".repeat(64)
    let id = "b".repeat(64)
    let active = Ref(false)
    let starts = Ref(0)
    let executions = Ref(0)
    let removals = Ref(0)
    let name = Ref("")
    let control : async (OracleProcessInvocation) -> TimedRun = invocation => {
      match invocation.args {
        ["run", "-d", "--name", token, ..] => {
          active.val = true
          starts.val += 1
          name.val = token
          oracle_container_test_result(stdout=@utf8.encode(id + "\n"))
        }
        ["container", "inspect", ..] =>
          oracle_container_test_result(
            stdout=oracle_container_test_inspect(name.val, name.val, id),
          )
        ["exec", ..] => {
          executions.val += 1
          oracle_container_test_result(
            stdout=b"observed\n",
            timed_out=mode == "timeout",
          )
        }
        ["top", ..] =>
          oracle_container_test_result(
            status=if mode == "observation" { 1 } else { 0 },
            stdout=if mode == "leak" {
              b"PID\n123\n456\n"
            } else {
              b"PID\n123\n"
            },
          )
        ["ps", ..] =>
          oracle_container_test_result(
            stdout=if active.val { @utf8.encode(id + "\n") } else { b"" },
          )
        ["rm", "--force", ..] => {
          if mode != "cleanup" {
            active.val = false
          }
          removals.val += 1
          oracle_container_test_result(
            status=if mode == "cleanup" { 1 } else { 0 },
          )
        }
        _ => fail("unexpected Docker control")
      }
    }
    let result = try {
      with_oracle_workers_using(root, image, 1, control, () => {
        for index in 0..<2 {
          let observed = run_oracle_with_deadline(
            "docker",
            ["run", "--rm", "-i", image, "cat"],
            1000,
            evidence_dir=root + "/case-" + index.to_string(),
          )
          assert_eq(observed.timed_out, mode == "timeout")
          assert_eq(observed.output.stdout, b"observed\n")
        }
      })
      true
    } catch {
      _ => false
    }
    assert_eq(result, ["clean", "timeout"].contains(mode))
    assert_eq(active.val, mode == "cleanup")
    assert_eq(starts.val, if mode == "timeout" { 2 } else { 1 })
    assert_eq(removals.val, starts.val)
    assert_eq(
      executions.val,
      if ["leak", "observation"].contains(mode) {
        1
      } else {
        2
      },
    )
    assert_true(oracle_pool.val is None)
    if mode == "cleanup" {
      clear_oracle_test_reservation(root + "/oracle-workers/" + name.val)
    }
  }
}
