///|
async test "release fixture failures preserve completed reports and infrastructure evidence" {
  let workspace = workspace_root()
  for phase in ["startup", "cleanup"] {
    let directory = @fs.tmpdir(prefix="mooncmd-release-lifecycle-")
    defer (@fs.rmdir(directory, recursive=true) catch { _ => () })
    let reports : Array[CaseReport] = []
    let fixture = release_case_for_test("completed-case", "echo")
    let started = @async.now()
    retain_release_execution_failure(reports, () => {
      reports.push({
        id: fixture.id,
        command: "echo",
        version: "0.1.5",
        category: "passed",
        detail: "controlled completed report",
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
    assert_eq(reports[0].id, fixture.id)
    assert_eq(reports[0].category, "passed")
    assert_eq(reports[1].category, "runner_infra")
    assert_true(reports[1].detail.contains(phase))
    let infrastructure = shared_report(reports[1], [fixture], false, Map([]))
    assert_eq(infrastructure.result, "infra")
    assert_false(infrastructure.semantic_pass())
    assert_eq(infrastructure.observations, [])
    write_report(
      directory,
      reports,
      [fixture],
      false,
      Map([]),
      workspace + "/tests/release_runner/current/candidate.json",
      workspace + "/tests/release_runner/current/active-cases.json",
      started,
      "",
      "",
    )
    assert_true(@fs.exists(directory + "/run-metadata.json"))
    let rows : Array[Json] = []
    for line in @fs.read_file(directory + "/summary.jsonl").text().split("\n") {
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
