///|
async test "case subsets resolve and launch only their selected commands" {
  let fixture : @harness.Case = @json.from_json({
    "id": "cat-case",
    "command": "cat",
    "args": [],
    "files": [],
    "environment": {},
    "normalizations": [],
    "expected_status": 0,
    "comparison": "contract",
  })
  let names = published_case_commands([fixture, fixture])
  assert_eq(names, ["cat"])
  assert_eq(
    published_case_commands([
      { ..fixture, related_commands: Some(["sort", "cat"]), },
    ]),
    ["cat", "sort"],
  )
  let cohort = published_case_commands([
    {
      ..fixture,
      related_commands: Some(@catalog.commands().map(contract => contract.name)),
    },
  ])
  assert_eq(cohort.length(), @catalog.commands().filter(@catalog.releasable).length())
  assert_true(!cohort.contains("timeout"))
  try published_case_commands([{ ..fixture, command: "timeout", }]) catch {
    _ => ()
  } noraise {
    _ => fail("nonreleasable primary command accepted")
  }
  let reads : Array[String] = []
  let coordinates = published_coordinates(names, read_module=name => {
    reads.push(name)
    guard name == "cat" else {
      fail("unselected unpublished dependency was read")
    }
    "name = \"cli/cat\"\nversion = \"0.2.2\"\n"
  })
  @harness.configure_commands(coordinates, "moonx")
  defer @harness.configure_commands(Map([]), "moonrun")
  let calls : Array[Array[String]] = []
  let reports : Array[@harness.CaseReport] = []
  prime_published_commands(names, reports, execute=(_, args, _) => {
    calls.push(args)
    {
      output: { status: 0, stdout: b"cat 0.2.2\n", stderr: b"", },
      timed_out: false,
      cleanup_error: None,
    }
  })
  assert_eq(reads, ["cat"])
  assert_eq(calls, [["cli/cat@0.2.2", "--", "--version"]])
}

///|
test "published selection rejects unsafe or incomplete expectation inventories" {
  let selection : PublishedSelection = {
    candidate: Some(false),
    base_manifest: "latest-cases.json",
    case_ids: ["cat-case"],
    extra_cases: [],
  }
  validate_published_selection(selection)
  validate_published_selection({
    ..selection,
    candidate: Some(true),
    base_manifest: "../cases/manifest.json",
  })
  for
    invalid in [
      { ..selection, case_ids: [], },
      { ..selection, case_ids: ["cat-case", "cat-case"], },
      { ..selection, base_manifest: "../active-cases.json", },
      { ..selection, base_manifest: "../cases/manifest.json", },
      {
        ..selection,
        candidate: Some(true),
        base_manifest: "../../cases/manifest.json",
      },
      { ..selection, extra_cases: [{}], },
    ] {
    try validate_published_selection(invalid) catch {
      _ => ()
    } noraise {
      _ => fail("invalid published selection accepted")
    }
  }
}

///|
async test "acceptance resolves each module once and ignores historical coordinate tables" {
  let legacy : PublishedSelection = @json.from_json({
    "candidate": false,
    "base_manifest": "latest-cases.json",
    "case_ids": ["cat-case"],
    "extra_cases": [],
    "commands": [
      { "name": "cat", "version": "0.0.1", "package_name": "old/cat" },
    ],
  })
  validate_published_selection(legacy)
  let reads = Ref(0)
  let coordinates = published_coordinates(["cat"], read_module=name => {
    assert_eq(name, "cat")
    reads.val += 1
    "name = \"cli/cat\"\nversion = \"0.2.9\"\n"
  })
  assert_eq(coordinates["cat"], "cli/cat@0.2.9")
  assert_eq(reads.val, 1)
  for commands in [[], ["cat", "cat"], ["timeout"], ["unknown"]] {
    try
      published_coordinates(commands, read_module=_ => {
        "name = \"cli/cat\"\nversion = \"0.2.9\"\n"
      })
    catch {
      _ => ()
    } noraise {
      _ => fail("invalid release eligibility accepted")
    }
  }
}

///|
test "module coordinates reject missing duplicate mismatched and mutable declarations" {
  for
    source in [
      "", "name = \"cli/cat\"", "name = \"other/cat\"\nversion = \"0.2.2\"", "name = \"cli/cat\"\nversion = \"0.2.2\"\nversion = \"0.2.3\"",
    ] {
    try module_coordinate("cat", source) catch {
      _ => ()
    } noraise {
      _ => fail("invalid module accepted")
    }
  }
  for
    version in [
      "latest", "", "0.2", "0.2.2 --help", "0.2.2@latest", "../0.2.2", "1.*.3", "01.2.3",
      "1.2.3.4", "1.2.3-", "1.2.3-01", "1.2.3+", "1.2.3+a+b",
    ] {
    try
      module_coordinate(
        "cat",
        "name = \"cli/cat\"\nversion = " + Json(version).stringify(),
      )
    catch {
      _ => ()
    } noraise {
      _ => fail("mutable module version accepted")
    }
  }
  for version in ["0.2.2", "1.2.3-rc.1", "1.2.3-rc-1+build.01"] {
    assert_true(exact_version(version))
  }
}

///|
async test "published startup rejects a missing exact version without a fallback" {
  @harness.configure_commands(Map([("cat", "cli/cat@0.2.9")]), "moonx")
  defer @harness.configure_commands(Map([]), "moonrun")
  let calls : Array[Array[String]] = []
  let reports : Array[@harness.CaseReport] = []
  try
    prime_published_commands(["cat"], reports, execute=(_, args, _) => {
      calls.push(args)
      {
        output: {
          status: 1,
          stdout: b"",
          stderr: b"package version not found",
        },
        timed_out: false,
        cleanup_error: None,
      }
    })
  catch {
    _ => ()
  } noraise {
    _ => fail("unpublished version must fail")
  }
  assert_eq(calls, [["cli/cat@0.2.9", "--", "--version"]])
  assert_eq(reports.length(), 1)
  assert_eq(reports[0].result, "fail")
}

///|
async test "published startup rejects a successful process returning the wrong version" {
  @harness.configure_commands(Map([("cat", "cli/cat@0.2.2")]), "moonx")
  defer @harness.configure_commands(Map([]), "moonrun")
  for output in [b"cat 0.2.1\n", b"cat 0.2.2\n"] {
    let reports : Array[@harness.CaseReport] = []
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
