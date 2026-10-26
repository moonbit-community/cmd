///|
test "published selection rejects mutable versions and incomplete inventories" {
  let selection : PublishedSelection = {
    base_manifest: "latest-cases.json",
    commands: [{ name: "cat", package_name: "cli/cat", version: "0.2.2", }],
    case_ids: ["cat-case"],
    extra_cases: [],
  }
  assert_eq(published_coordinates(selection)["cat"], "cli/cat@0.2.2")
  for
    invalid in [
      { ..selection, commands: [], },
      { ..selection, case_ids: [], },
      { ..selection, case_ids: ["cat-case", "cat-case"], },
      { ..selection, base_manifest: "../active-cases.json", },
      { ..selection, extra_cases: [{}], },
      { ..selection, commands: [selection.commands[0], selection.commands[0]], },
      {
        ..selection,
        commands: [
          { name: "timeout", package_name: "cli/timeout", version: "0.1.0", },
        ],
      },
      {
        ..selection,
        commands: [
          { name: "cat", package_name: "other/cat", version: "0.2.2", },
        ],
      },
    ] {
    try published_coordinates(invalid) catch {
      _ => ()
    } noraise {
      _ => fail("invalid published selection accepted")
    }
  }
  for
    version in ["latest", "", "0.2", "0.2.2 --help", "0.2.2@latest", "../0.2.2"] {
    let invalid = {
      ..selection,
      commands: [{ ..selection.commands[0], version, }],
    }
    try published_coordinates(invalid) catch {
      _ => ()
    } noraise {
      _ => fail("mutable or malformed version accepted")
    }
  }
}

///|
async test "published startup rejects a successful process returning the wrong version" {
  @testkit.configure_commands(Map([("cat", "cli/cat@0.2.2")]), "moonx")
  defer @testkit.configure_commands(Map([]), "moonrun")
  for output in [b"cat 0.2.1\n", b"cat 0.2.2\n"] {
    let reports : Array[@testkit.CaseReport] = []
    let accepted = try {
      prime_published_commands(["cat"], reports, execute=(program, args, _) => {
        assert_eq(program, "moonx")
        assert_eq(args, ["cli/cat@0.2.2", "--", "--version"])
        {
          output: { status: 0, stdout: output, stderr: b"", },
          timed_out: false,
          cleanup_error: None,
        }
      })
      true
    } catch {
      _ => false
    }
    assert_eq(accepted, output == b"cat 0.2.2\n")
    assert_eq(reports.length(), 1)
    assert_eq(reports[0].result, if accepted { "pass" } else { "fail" })
    if !accepted {
      assert_true(reports[0].detail.contains("cat@0.2.2"))
    }
  }
}
