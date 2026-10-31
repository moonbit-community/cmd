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
test "functional selections reject vacuity duplicates and ambiguous fixture ownership" {
  let manifest : FunctionalManifest = @json.from_json({
    "schema": 2,
    "published_manifest": "published",
    "case_corpus": "frozen",
    "workspace_case_corpus": "active",
    "workloads": [
      {
        "id": "example",
        "command": "cat",
        "reference_behavior_id": "case:cat",
        "case_id": "cat",
      },
    ],
  })
  let row = manifest.workloads[0]
  assert_eq(
    functional_output_sink(row),
    "regular-file-and-declared-filesystem-effects",
  )
  assert_eq(
    functional_output_sink({ ..row, case_id: None, recipe: Some("yes"), }),
    "bounded-pipe-consumer-4096-bytes-then-close",
  )
  assert_eq(functional_case_corpus(manifest, true), "active")
  assert_eq(functional_case_corpus(manifest, false), "frozen")
  assert_eq(functional_workload_errors([row]), [])
  let counter = { ..row, command: "wc", }
  assert_true(functional_metadata_shortcut(counter, ["-c"]))
  assert_false(functional_metadata_shortcut(counter, ["-l"]))
  assert_false(
    functional_metadata_shortcut(
      { ..counter, transport: Some("fragmented-pipe"), chunk_bytes: Some(257), },
      ["-c"],
    ),
  )
  assert_false(functional_workload_errors([]).is_empty())
  assert_false(functional_workload_errors([row, row]).is_empty())
  for
    invalid in [
      { ..row, id: "../escape", },
      { ..row, case_id: None, },
      { ..row, recipe: Some("gzip"), },
      { ..row, reference_behavior_id: "", },
      { ..row, pending: Some(""), },
      { ..row, transport: Some("unknown"), },
      { ..row, chunk_bytes: Some(257), },
      { ..row, transport: Some("fragmented-pipe"), chunk_bytes: Some(257), },
      {
        ..row,
        transport: Some("fragmented-pipe"),
        chunk_bytes: Some(0),
        corpus: Some({ bytes: 1L, record_bytes: 80L, shape: "ascii", }),
      },
      {
        ..row,
        corpus: Some({ bytes: -1L, record_bytes: 80L, shape: "ascii", }),
      },
    ] {
    assert_false(functional_workload_errors([invalid]).is_empty())
  }
  assert_eq(
    functional_workload_errors([
      {
        ..row,
        transport: Some("fragmented-pipe"),
        chunk_bytes: Some(257),
        corpus: Some({ bytes: 1L, record_bytes: 80L, shape: "ascii", }),
      },
    ]),
    [],
  )
}
