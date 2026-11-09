///|
async fn type_listing_scenario(root : String, work : String) -> Unit {
  let result = scenario_run(
    work,
    root,
    "rg",
    ["--type-add", "proof:*.proof", "--type-list"],
    cwd=work,
  )
  assert_eq(result.status, 0)
  assert_eq(result.stderr, b"")
  let text = @harness.scenario_text(result.stdout)
  assert_true(text.has_suffix("\n"))
  let names : Array[String] = []
  for line in text.split("\n") {
    if line == "" {
      continue
    }
    guard line.find(": ") is Some(separator) && separator > 0 else {
      fail("malformed type stanza")
    }
    let name = line[:separator].to_owned()
    assert_false(names.contains(name))
    assert_true(line[separator + 2:].length() > 0)
    names.push(name)
  }
  let sorted = names.copy()
  sorted.sort_by((a, b) => {
    let left = @utf8.encode(a)
    let right = @utf8.encode(b)
    for i in 0..<left.length().min(right.length()) {
      if left[i] != right[i] {
        return left[i].to_int() - right[i].to_int()
      }
    }
    left.length() - right.length()
  })
  assert_eq(names, sorted)
  let custom = text
    .split("\n")
    .filter(line => line.has_prefix("proof:"))
    .map(line => line.to_owned())
    .collect()
  let rust = text
    .split("\n")
    .filter(line => line.has_prefix("rust:"))
    .map(line => line.to_owned())
    .collect()
  let actual : Json = {
    "status": result.status,
    "stderr": @harness.scenario_text(result.stderr),
    "custom": Json(custom),
    "rust": Json(rust),
    "sorted_unique": names == sorted && names.length() > 2,
    "final_lf": text.has_suffix("\n"),
  }
  let expected : Json = {
    "status": 0,
    "stderr": "",
    "custom": ["proof: *.proof"],
    "rust": ["rust: *.rs"],
    "sorted_unique": true,
    "final_lf": true,
  }
  assert_eq(actual, expected)

  @harness.assert_observation("rg/type-list", "rg", actual, expected)
}

///|
async fn sort_spill_scenario(root : String, work : String) -> Unit {
  let temporary = work + "/selected"
  let fallback = work + "/fallback"
  @fs.mkdir(temporary)
  @fs.mkdir(fallback)
  @async.with_task_group(group => {
    let (stdin, writer) = @process.write_to_process()
    defer writer.close()
    let stdout_path = work + "/../sort.stdout"
    let stderr_path = work + "/../sort.stderr"
    let child = @process.spawn(
      group,
      @harness.command_program(),
      @harness.command_args(root, "sort", [
        "-S", "128b", "-T", temporary, "--batch-size=2",
      ]),
      stdin~,
      stdout=@process.redirect_to_file(stdout_path),
      stderr=@process.redirect_to_file(stderr_path),
      cwd=work,
      extra_env={ "TMPDIR": fallback, "TMP": fallback, "TEMP": fallback },
      cancel_handler=@process.hard_cancel(),
    )
    // Hold stdin open until a real disk run is observed, before completion.
    writer.write("z\na\n".repeat(4096))
    let seen = @async.with_timeout(5000, () => {
      for ;; {
        let names = @fs.readdir(temporary)
        if !names.is_empty() {
          break names
        }
        @async.sleep(5)
      }
    })
    assert_true(!seen.is_empty())
    assert_true(@fs.readdir(fallback).is_empty())
    @fs.write_file(
      work + "/../sort-live-files.json",
      Json(seen).stringify(indent=2),
    )
    writer.close()
    // Thousands of small merge files take over 14 seconds on Windows CI.
    // Leave headroom within this case's existing 60-second overall deadline;
    // the live-run, exact output and cleanup requirements remain mandatory.
    let status = @async.with_timeout(30000, () => child.wait())
    let stdout = @fs.read_file(stdout_path).binary()
    let stderr = @fs.read_file(stderr_path).binary()
    let actual : Json = {
      "status": status,
      "stdout_exact": stdout ==
      @utf8.encode("a\n".repeat(4096) + "z\n".repeat(4096)),
      "stderr": @harness.scenario_text(stderr),
      "live_runs": !seen.is_empty(),
      "selected_clean": @fs.readdir(temporary).is_empty(),
      "fallback_clean": @fs.readdir(fallback).is_empty(),
    }
    let expected : Json = {
      "status": 0,
      "stdout_exact": true,
      "stderr": "",
      "live_runs": true,
      "selected_clean": true,
      "fallback_clean": true,
    }
    assert_eq(actual, expected)

    @harness.assert_observation(
      "sort/temporary-directory", "sort", actual, expected,
    )
  })
}

///|
async fn removal_guard_scenario(root : String, work : String) -> Unit {
  let policy = work + "/deny-all.json"
  @fs.write_file(policy, "{}\n")
  @fs.write_file(work + "/sentinel", "retained")
  // No filesystem capability is granted even if the product guard regresses.
  let denied = @harness.run_with_deadline(
    @harness.command_program(),
    @harness.command_args(root, "rm", ["-f", work + "/sentinel"], policy~),
    5000,
    cwd=work,
  )
  assert_false(denied.timed_out)
  assert_eq(denied.cleanup_error, None)
  assert_true(denied.output.status != 0)
  assert_eq(@fs.read_file(work + "/sentinel").binary(), b"retained")
  let result = @harness.run_with_deadline(
    @harness.command_program(),
    @harness.command_args(root, "rm", ["-rf", "--preserve-root", "/"], policy~),
    5000,
    cwd=work,
  )
  assert_false(result.timed_out)
  assert_eq(result.cleanup_error, None)
  let actual : Json = {
    "status": result.output.status,
    "stdout": @harness.scenario_text(result.output.stdout),
    "stderr": @harness.scenario_text(result.output.stderr),
    "sentinel": @fs.read_file(work + "/sentinel").text(),
  }
  let expected : Json = {
    "status": 1,
    "stdout": "",
    "stderr": "rm: refusing to remove protected path '/'\n",
    "sentinel": "retained",
  }
  assert_eq(actual, expected)

  @harness.assert_observation("rm/preserve-root", "rm", actual, expected)
}

///|
async fn xargs_verbose_scenario(root : String, work : String) -> Unit {
  let helper = @harness.option_child_path()
  let result = scenario_run(
    work,
    root,
    "xargs",
    ["-t", "-0", helper, "--option-test-helper", "printf", "<%s>\\n"],
    stdin=b"two words\x00a'b\x00\x00",
    cwd=work,
  )
  let expected_display = helper +
    " --option-test-helper printf <%s>\\n two words a'b \n"
  let actual : Json = {
    "status": result.status,
    "stdout": @harness.scenario_text(result.stdout),
    "display": @harness.scenario_text(result.stderr) == expected_display,
  }
  let expected : Json = {
    "status": 0,
    "stdout": "<two words>\n<a'b>\n<>\n",
    "display": true,
  }
  assert_eq(actual, expected)

  @harness.assert_observation("xargs/verbose", "xargs", actual, expected)
}
