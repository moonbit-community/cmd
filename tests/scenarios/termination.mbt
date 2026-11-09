///|
async fn timeout_command_scenario(root : String, work : String) -> Unit {
  let helper = @harness.option_child_path()
  for
    (label, args, stdout, stderr, status) in [
      (
        "complete",
        ["5s", helper, "--option-test-helper", "printf", "finished\\n"],
        "finished\n",
        "",
        0,
      ),
      (
        "child-failure",
        ["5s", helper, "--option-test-helper", "false"],
        "",
        "",
        1,
      ),
      (
        "expire",
        ["2s", helper, "--test-helper", "wait-ready"],
        "ready\n",
        "timeout: command timed out\n",
        124,
      ),
      (
        "invalid",
        ["nonsense", helper, "--test-helper", "wait-ready"],
        "",
        "timeout: invalid duration: nonsense\n",
        125,
      ),
      (
        "range",
        ["999999999d", helper, "--test-helper", "wait-ready"],
        "",
        "timeout: invalid duration: 999999999d\n",
        125,
      ),
      (
        "negative",
        ["--", "-1", helper, "--test-helper", "wait-ready"],
        "",
        "timeout: invalid duration: -1\n",
        125,
      ),
    ] {
    let result = scenario_run(work, root, "timeout", args, cwd=work)
    let actual : Json = {
      "status": result.status,
      "stdout": @harness.scenario_text(result.stdout),
      "stderr": @harness.scenario_text(result.stderr),
    }
    let expected : Json = {
      "status": status,
      "stdout": stdout,
      "stderr": stderr,
    }
    assert_eq(actual, expected)

    @harness.assert_observation("timeout/" + label, "timeout", actual, expected)
  }
  let missing = work + "/missing-program"
  let failed = scenario_run(work, root, "timeout", ["5s", missing], cwd=work)
  assert_eq(failed.status, 127)
  assert_eq(failed.stdout, b"")
  assert_true(
    @harness.scenario_text(failed.stderr).has_prefix(
      "timeout: cannot run '" + missing + "': ",
    ),
  )
  assert_false(@fs.exists(missing))
}

///|
async fn csplit_retention_scenario(root : String, work : String) -> Unit {
  for keep in [false, true] {
    let directory = work + (if keep { "/keep" } else { "/remove" })
    @fs.mkdir(directory)
    let result = scenario_run(
      work,
      root,
      "csplit",
      [..if keep { ["-k"] } else { [] }, "-", "2", "/missing/"],
      stdin=b"a\nb\n",
      cwd=directory,
    )
    let diagnostic = @harness.scenario_text(result.stderr)
    let prefix = "csplit: Failure(main.mbt:"
    let suffix = "@cli/csplit FAILED: match not found)\n"
    assert_true(diagnostic.has_prefix(prefix) && diagnostic.has_suffix(suffix))
    let position = diagnostic[prefix.length():diagnostic.length() -
      suffix.length()]
    assert_true(
      !position.is_empty() &&
      position.iter().all(ch => ch is ('0'..<='9' | ':' | '-')),
    )
    let names = @fs.readdir(directory)
    names.sort()
    let contents : Array[String] = []
    for name in names {
      contents.push(@fs.read_file(directory + "/" + name).text())
    }
    let actual : Json = {
      "status": result.status,
      "stdout": @harness.scenario_text(result.stdout),
      "diagnostic": diagnostic.has_prefix(prefix) &&
      diagnostic.has_suffix(suffix),
      "files": Json(names),
      "contents": Json(contents),
    }
    let expected : Json = {
      "status": 1,
      "stdout": "2\n2\n",
      "diagnostic": true,
      "files": Json(if keep { ["xx00", "xx01"] } else { [] }),
      "contents": Json(if keep { ["a\n", "b\n"] } else { [] }),
    }
    assert_eq(actual, expected)

    @harness.assert_observation(
      "csplit/" + (if keep { "keep" } else { "remove" }),
      "csplit",
      actual,
      expected,
    )
  }
}
