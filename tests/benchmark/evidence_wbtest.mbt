///|
test "benchmark claims stay scoped even with all timing rows passing" {
  for sampled in [false, true] {
    let scope = benchmark_evidence_scope(sampled)
    assert_true(
      scope
      is {
        "general_performance_acceptance": False,
        "upstream_parity": False,
        "blind_holdout": False,
        ..
      },
    )
  }
}

///|
test "real selection validation rejects vacuity duplicates missing input and incompatible transports" {
  let row : FunctionalWorkload = @json.from_json({
    "id": "example",
    "command": "cat",
    "reference_behavior_id": "case:cat",
    "recipe": "real-input",
    "args": [],
    "expected_status": 0,
    "mode": "copy",
    "source": {
      "path": "text",
      "sha256": Json("a".repeat(64)),
      "split": "ordinary",
    },
    "facets": ["bytes"],
  })
  assert_eq(functional_workload_errors([row]), [])
  assert_eq(
    functional_output_sink(row),
    "regular-file-and-declared-filesystem-effects",
  )
  assert_false(functional_workload_errors([]).is_empty())
  assert_false(functional_workload_errors([row, row]).is_empty())
  for
    invalid in [
      { ..row, id: "../escape", },
      { ..row, source: None, },
      { ..row, recipe: None, },
      { ..row, args: None, },
      { ..row, mode: None, },
      { ..row, expected_status: None, },
      { ..row, reference_behavior_id: "", },
      { ..row, transport: Some("unknown"), },
      { ..row, chunk_bytes: Some(257), },
      { ..row, transport: Some("fragmented-pipe"), chunk_bytes: Some(0), },
      { ..row, sink: Some("slow-pipe"), },
      { ..row, sink_chunk_bytes: Some(257), },
    ] {
    assert_false(functional_workload_errors([invalid]).is_empty())
  }
  let pipe = {
    ..row,
    transport: Some("fragmented-pipe"),
    chunk_bytes: Some(257),
  }
  assert_eq(functional_workload_errors([pipe]), [])
  let counter = { ..row, command: "wc", }
  assert_true(functional_metadata_shortcut(counter, ["-c"]))
  assert_false(functional_metadata_shortcut(counter, ["-l"]))
  assert_false(
    functional_metadata_shortcut(
      { ..counter, transport: Some("fragmented-pipe"), chunk_bytes: Some(257), },
      ["-c"],
    ),
  )
}
