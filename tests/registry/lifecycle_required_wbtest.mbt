///|
async fn checked_in_lifecycle_for_test() -> LifecycleRegistry {
  let path = if @fs.exists("tests/registry/lifecycle.json") {
    "tests/registry/lifecycle.json"
  } else if @fs.exists("registry/lifecycle.json") {
    "registry/lifecycle.json"
  } else {
    "../../tests/registry/lifecycle.json"
  }
  @json.from_json(@json.parse(@fs.read_file(path).text()))
}

///|
async test "lifecycle completeness preserves the reviewed minimum and allows additional evidence" {
  let lifecycle = checked_in_lifecycle_for_test()
  assert_true(validate_lifecycle_completeness(lifecycle).is_empty())
  assert_eq(required_lifecycle_assertions().length(), 26)
  assert_true(
    required_lifecycle_assertions().all(required => {
      lifecycle.cases.any(item => {
        item.id == required.0 && item.status == "proven"
      })
    }),
  )
  let extra : LifecycleCase = {
    id: "additional-lifecycle-obligation",
    status: "deferred",
    test_ref: "",
    proves: [],
    limitations: ["additional observation remains deferred"],
  }
  let extended = {
    ..lifecycle,
    cases: [
      ..lifecycle.cases.map(item => {
        if item.status == "proven" {
          { ..item, proves: [..item.proves, "additional-observation"], }
        } else {
          item
        }
      }),
      extra,
    ],
  }
  assert_true(validate_lifecycle_completeness(extended).is_empty())
}

///|
async test "lifecycle completeness rejects deletion demotion and loss of every required assertion" {
  let lifecycle = checked_in_lifecycle_for_test()
  assert_false(
    validate_lifecycle_completeness({ schema: 1, cases: [], }).is_empty(),
  )
  for (id, assertions) in required_lifecycle_assertions() {
    let item = lifecycle.cases.filter(item => item.id == id)[0]
    let removed = {
      ..lifecycle,
      cases: lifecycle.cases.filter(candidate => candidate.id != item.id),
    }
    assert_true(
      validate_lifecycle_completeness(removed).any(failure => {
        failure.contains("must occur exactly once") && failure.contains(item.id)
      }),
    )
    let demoted = {
      ..lifecycle,
      cases: lifecycle.cases.map(candidate => {
        if candidate.id == item.id {
          {
            ..candidate,
            status: "deferred",
            limitations: ["silently weakened"],
          }
        } else {
          candidate
        }
      }),
    }
    assert_true(
      validate_lifecycle_completeness(demoted).any(failure => {
        failure.contains("must remain proven") && failure.contains(item.id)
      }),
    )
    for assertion in assertions {
      let weakened = {
        ..lifecycle,
        cases: lifecycle.cases.map(candidate => {
          if candidate.id == item.id {
            {
              ..candidate,
              proves: candidate.proves.filter(value => value != assertion),
            }
          } else {
            candidate
          }
        }),
      }
      assert_true(
        validate_lifecycle_completeness(weakened).any(failure => {
          failure.contains("missing required assertion") &&
          failure.contains(item.id) &&
          failure.contains(assertion)
        }),
      )
    }
  }
}

///|
async test "lifecycle completeness requires the deferred grandchild ownership boundary" {
  let lifecycle = checked_in_lifecycle_for_test()
  let id = "grandchild-process-boundary"
  let remaining = lifecycle.cases.filter(item => item.id != id)
  let boundary = lifecycle.cases.filter(item => item.id == id)[0]
  assert_false(
    validate_lifecycle_completeness({ ..lifecycle, cases: remaining, }).is_empty(),
  )
  let invalid : Array[LifecycleCase] = [
    { ..boundary, status: "proven", },
    { ..boundary, limitations: ["unrelated limitation"], },
    { ..boundary, proves: ["process-tree-owned"], },
    { ..boundary, test_ref: "tests/testkit/lifecycle_wbtest.mbt::unproven", },
  ]
  for boundary in invalid {
    assert_true(
      validate_lifecycle_completeness({
        ..lifecycle,
        cases: [..remaining, boundary],
      }).any(failure => {
        failure.contains("explicit deferred ownership limitation")
      }),
    )
  }
}

///|
async test "lifecycle completeness does not replace executable reference validation" {
  let lifecycle = checked_in_lifecycle_for_test()
  let broken = {
    ..lifecycle,
    cases: lifecycle.cases.map(item => {
      if item.id == "candidate-start-failure" {
        { ..item, test_ref: "tests/missing.mbt::removed", }
      } else {
        item
      }
    }),
  }
  assert_true(validate_lifecycle_completeness(broken).is_empty())
  let entries = lifecycle.cases
    .filter(item => item.test_ref != "")
    .map(item => {
      ..entry_for_test(item.id, "package-test", ""),
      source: item.test_ref,
    })
  let registry : Registry = { schema: 2, entries, release_commands: [], }
  let failures = validate_lifecycle_bindings(
    broken,
    registry,
    entries.map(entry => entry.source),
  )
  assert_true(
    failures.any(failure => failure.contains("orphan test reference")),
  )
  assert_true(failures.any(failure => failure.contains("not registered")))
}
