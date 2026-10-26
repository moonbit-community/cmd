///|
async test "workspace fixture failures preserve completed results and infrastructure evidence" {
  for status in [125, 126, 127] {
    assert_true(unexpected_oracle_transport_status(status, 0))
    assert_false(unexpected_oracle_transport_status(status, status))
  }
  assert_false(unexpected_oracle_transport_status(1, 0))
  for phase in ["startup", "cleanup"] {
    let root = @fs.tmpdir(prefix="mooncmd-workspace-lifecycle-")
    defer (@fs.rmdir(root, recursive=true) catch { _ => () })
    let started = @async.now()
    let reports : Array[@testkit.CaseReport] = []
    retain_execution_failure(reports, "native", started, () => {
      reports.push({
        ..suite_report("completed-case", "native", started, []),
        stage: "complete",
      })
      @async.with_task_group(group => {
        if phase == "cleanup" {
          group.add_defer(() => fail("injected fixture cleanup error"))
        } else {
          fail("injected fixture startup error")
        }
      })
    })
    assert_eq(reports.length(), 2)
    assert_eq(reports[0].id, "completed-case")
    assert_eq(reports[0].result, "pass")
    assert_eq(reports[1].result, "infra")
    assert_true(reports[1].detail.contains(phase))
    assert_false(reports[1].semantic_pass())
    assert_eq(reports[1].observations, [])
    @testkit.write_reports(root, reports)
    assert_true(@fs.exists(root + "/run.json"))
    let rows : Array[Json] = []
    for line in @fs.read_file(root + "/summary.jsonl").text().split("\n") {
      if line != "" {
        rows.push(@json.parse(line.to_owned()))
      }
    }
    assert_eq(rows.length(), 2)
    assert_true(
      rows[0]
      is { "id": String("completed-case"), "result": String("pass"), .. },
    )
    assert_true(
      rows[1]
      is {
        "result": String("infra"),
        "verification": String("availability"),
        ..
      },
    )
  }
}

///|
async test "retained cohort direct child wait errors cannot report cancellation success" {
  for label in ["tail follow", "sleep cancellation"] {
    let calls = Ref(0)
    try
      wait_for_direct_child(label, () => {
        calls.val += 1
        fail("injected direct child wait failure")
      })
    catch {
      error => {
        assert_true(error.to_string().contains("cleanup infrastructure"))
        assert_true(error.to_string().contains(label))
      }
    } noraise {
      _ => fail("a failed direct child wait must not pass cancellation")
    }
    assert_eq(calls.val, 1)
  }
  wait_for_direct_child("completed child", () => 0)
}
