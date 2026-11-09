///|
async fn follow_interval_scenario(root : String, work : String) -> Unit {
  for (label, interval) in [("fast", "0.05"), ("slow", "2")] {
    let source = work + "/" + label
    @fs.write_file(source, "ready\n")
    @async.with_task_group(group => {
      let (reader, stdout) = @process.read_from_process()
      defer reader.close()
      let stderr_path = work + "/../tail-" + label + ".stderr"
      let child = @harness.spawn(
        group,
        @harness.command_program(),
        @harness.command_args(root, "tail", ["-f", "-s", interval, source]),
        stdout~,
        stderr=@process.redirect_to_file(stderr_path),
        cwd=work,
        cancel_handler=@process.hard_cancel(),
      )
      assert_eq(
        @async.with_timeout(5000, () => reader.read_until("\n")),
        Some("ready"),
      )
      let start = @async.now()
      let writer = @fs.open(source, mode=WriteOnly, append=true)
      writer.write("later\n")
      writer.close()
      assert_true(@async.now() - start < 250L, msg="append readiness window")
      let next = @async.with_timeout(5000, () => reader.read_until("\n"))
      let elapsed = @async.now() - start
      child.cancel()
      child.wait() |> ignore
      assert_eq(reader.read_all().binary(), b"")
      let errors = @fs.read_file(stderr_path).text()
      let actual : Json = {
        "record": next.map(value => Json(value)).unwrap_or(Json::null()),
        "stderr": errors,
        "interval_effect": if label == "fast" {
          elapsed < 1200L
        } else {
          elapsed >= 1400L && elapsed < 5000L
        },
        "retained": @fs.read_file(source).text(),
      }
      let expected : Json = {
        "record": "later",
        "stderr": "",
        "interval_effect": true,
        "retained": "ready\nlater\n",
      }
      @fs.write_file(
        work + "/../tail-" + label + ".timing.json",
        ({ "elapsed_ms": elapsed, "requested_seconds": interval } : Json).stringify(
          indent=2,
        ),
      )
      assert_eq(actual, expected)

      @harness.assert_observation("tail/" + label, "tail", actual, expected)
    })
  }
}

///|
async fn failure_prefix_scenario(root : String, work : String) -> Unit {
  let gzip = scenario_run(
    work,
    root,
    "gzip",
    ["-dc"],
    stdin=b"\x1f\x8b\x08\x00\x00\x00\x00\x00\x00\x03\x4b\x4c\x4a\x06\x00\xc2\x41\x24\x35",
    cwd=work,
  )
  let gzip_message = @harness.scenario_text(gzip.stderr)
  let gzip_actual : Json = {
    "status": gzip.status,
    "stdout": @harness.scenario_text(gzip.stdout),
    "truncated_error": gzip_message.has_prefix("gzip: -: ") &&
    gzip_message.contains("unexpected end of file") &&
    gzip_message.has_suffix("\n"),
  }
  let gzip_expected : Json = {
    "status": 1,
    "stdout": "abc",
    "truncated_error": true,
  }
  assert_eq(gzip_actual, gzip_expected)

  @harness.assert_observation(
    "gzip/truncated-prefix", "gzip", gzip_actual, gzip_expected,
  )

  @fs.write_file(work + "/short", "a\n")
  assert_false(@fs.exists(work + "/missing"))
  let wc = scenario_run(work, root, "wc", ["-l", "short", "missing"], cwd=work)
  let wc_message = @harness.scenario_text(wc.stderr)
  let wc_actual : Json = {
    "status": wc.status,
    "stdout": @harness.scenario_text(wc.stdout),
    "missing_operand": wc_message.has_prefix("wc: missing:") &&
    wc_message.has_suffix("\n"),
    "retained": @fs.read_file(work + "/short").text(),
  }
  let wc_expected : Json = {
    "status": 1,
    "stdout": "1 short\n1 total\n",
    "missing_operand": true,
    "retained": "a\n",
  }
  assert_eq(wc_actual, wc_expected)

  @harness.assert_observation("wc/error-prefix", "wc", wc_actual, wc_expected)

  @fs.write_file(work + "/hay", "source\n")
  let rg = scenario_run(
    work,
    root,
    "rg",
    ["--pre", @harness.option_child_path(), "alpha", "hay"],
    cwd=work,
    extra_env={ "CMD_RG_PREPROCESSOR": "partial-failure" },
  )
  let rg_message = @harness.scenario_text(rg.stderr)
  let rg_actual : Json = {
    "status": rg.status,
    "stdout": @harness.scenario_text(rg.stdout),
    "child_error": rg_message.contains("preprocessor failed") &&
    rg_message.has_suffix("\n"),
    "retained": @fs.read_file(work + "/hay").text(),
  }
  let rg_expected : Json = {
    "status": 2,
    "stdout": "alpha\n",
    "child_error": true,
    "retained": "source\n",
  }
  assert_eq(rg_actual, rg_expected)

  @harness.assert_observation(
    "rg/preprocessor-failure", "rg", rg_actual, rg_expected,
  )
}
