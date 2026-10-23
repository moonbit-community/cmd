///|
test "scope canonical rejection requirements reject stale prose and use current unlock conditions" {
  let entry = {
    ..sel_test_entry("rejection", "cat"),
    status: "boundary",
    required_backends: ["native"],
    required_evidence: ["boundary"],
  }
  let registry = sel_test_registry([entry])
  let row : ScopeBoundary = {
    behavior_id: entry.behavior_id,
    support_record: "docs/compatibility.md",
    adr: "docs/adr/0001-evidence.md",
    current_limit: "the current rejection",
    unlock_condition: "prove the selected replacement semantics",
    rejection_tests: [entry.behavior_id],
    replacement_behaviors: [],
  }
  let index : Json = { "schema": 1, "entries": [row.to_json()] }
  let snapshot = sel_test_tree(files=[
    sel_test_file(
      "tests/registry/boundaries.json",
      content=@testkit.canonical_json(index),
    ),
    sel_test_file(row.support_record, content="support"),
    sel_test_file(row.adr, content="decision"),
  ])
  let selection = {
    ..intent_fixture_selection(),
    mode: "scoped",
    behaviors: [entry.behavior_id],
  }
  assert_eq(
    selected_boundaries(snapshot, snapshot, selection, [], registry, registry),
    [row],
  )
  let stale = { ..row, unlock_condition: "an obsolete unlock", }
  try
    selected_boundaries(
      snapshot,
      snapshot,
      selection,
      [stale],
      registry,
      registry,
    )
  catch {
    _ => ()
  } noraise {
    _ =>
      fail(
        "a previously prepared canonical record cannot override current policy",
      )
  }
  let replaced_index : Json = {
    "schema": 1,
    "entries": [
      { ..row, replacement_behaviors: [entry.behavior_id], }.to_json(),
    ],
  }
  let invalid = {
    ..snapshot,
    files: snapshot.files.map(file => {
      if file.path == "tests/registry/boundaries.json" {
        {
          ..file,
          content: @utf8.encode(@testkit.canonical_json(replaced_index)),
        }
      } else {
        file
      }
    }),
  }
  try
    selected_boundaries(invalid, invalid, selection, [], registry, registry)
  catch {
    _ => ()
  } noraise {
    _ => fail("canonical current execution cannot be replaced")
  }
}

///|
test "scope full regression derives current requirements without parsing a stale PR intent" {
  let entry = sel_test_entry("test", "cat")
  let registry = sel_test_registry([entry])
  let snapshot = sel_test_tree(files=[
    sel_test_file(
      "tests/registry/registry.json",
      content=@testkit.canonical_json(registry.to_json()),
    ),
    sel_test_file(
      "tests/coverage/ci-change.json",
      content="this is not a regression input",
    ),
    sel_test_file("commands/cat/moon.pkg"),
  ])
  let graph = sel_test_graph(["commands/cat"])
  let full = full_regression_requirements(snapshot, graph, "a".repeat(40))
  assert_eq(full.transition, "regression-only/full")
  assert_eq(full.selection.behaviors, [entry.behavior_id])
  assert_true(full.changes.is_empty())
  assert_true(full.selection.changed_paths.is_empty())
  try parse_intent(full.to_json()) catch {
    _ => ()
  } noraise {
    _ =>
      fail(
        "execution-only full requirements cannot masquerade as an authored PR intent",
      )
  }
}
