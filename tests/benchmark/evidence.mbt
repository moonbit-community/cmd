///|
fn require_frozen_timing_backend(options : Map[String, String]) -> Unit raise {
  guard options.contains("--wasm-root") else {
    fail("real-source comparisons require explicit frozen Wasm artifacts")
  }
}

///|
// A timing pass applies only to the exact selected workload.
fn benchmark_evidence_scope(sampled : Bool) -> Json {
  {
    "claim": if sampled {
      "selected-workload-timing"
    } else {
      "selected-workload-correctness"
    },
    "general_performance_acceptance": false,
    "upstream_parity": false,
    "blind_holdout": false,
    "input_transport": "per-row-declared",
    "output_sink": "per-row-declared",
    "startup_included": true,
    "aggregation": "per-row; no weighting by regression count",
  }
}

///|
fn functional_output_sink(workload : FunctionalWorkload) -> String {
  if workload.sink == Some("slow-pipe") {
    "bounded-slow-pipe-consumer; declared chunks/delay included in process interval"
  } else {
    "regular-file-and-declared-filesystem-effects"
  }
}

///|
fn functional_metadata_shortcut(
  workload : FunctionalWorkload,
  args : Array[String],
) -> Bool {
  workload.command == "wc" && args.contains("-c") && workload.transport is None
}

///|
fn functional_workload_errors(
  workloads : Array[FunctionalWorkload],
) -> Array[String] {
  let errors : Array[String] = []
  let ids : Set[String] = Set([])
  if workloads.is_empty() {
    errors.push("empty functional workload selection")
  }
  for row in workloads {
    if !@testkit.safe_relative_path(row.id) || ids.contains(row.id) {
      errors.push("unsafe or duplicate workload ID: " + row.id)
    }
    ids.add(row.id)
    if row.command.is_empty() || row.reference_behavior_id.is_empty() {
      errors.push("missing command or behavior reference: " + row.id)
    }
    if row.source is None ||
      row.recipe is None ||
      row.args is None ||
      row.expected_status is None ||
      row.mode.unwrap_or("").is_empty() {
      errors.push(
        "real workload requires source, recipe, argv, mode and status: " +
        row.id,
      )
    }
    if row.sink is Some(sink) && sink != "slow-pipe" {
      errors.push("unknown output sink: " + row.id)
    }
    if row.sink == Some("slow-pipe") {
      if !(row.sink_chunk_bytes is Some(chunk) && chunk > 0 && chunk <= 65537) ||
        !(row.sink_delay_ms is Some(delay) && delay >= 1 && delay <= 20) ||
        row.transport is Some(_) {
        errors.push(
          "slow pipe requires bounded chunk/delay and regular input: " + row.id,
        )
      }
    } else if row.sink_chunk_bytes is Some(_) || row.sink_delay_ms is Some(_) {
      errors.push("output chunk/delay require slow-pipe sink: " + row.id)
    }
    if row.transport is Some(transport) && transport != "fragmented-pipe" {
      errors.push("unknown benchmark transport: " + row.id)
    }
    if row.transport == Some("fragmented-pipe") {
      if !(row.chunk_bytes is Some(chunk) && chunk > 0 && chunk <= 65537) ||
        benchmark_file_recipe(row.recipe) {
        errors.push(
          "fragmented pipe needs bounded chunks and a genuine stdin source: " +
          row.id,
        )
      }
    } else if row.chunk_bytes is Some(_) {
      errors.push(
        "producer chunk size requires fragmented pipe transport: " + row.id,
      )
    }
    if row.other_source is Some(_) &&
      ![
        Some("bench-join-natural-csv"),
        Some("bench-comm-natural-idsets"),
        Some("real-file-pair"),
      ].contains(row.recipe) {
      errors.push(
        "second source requires an explicit two-source recipe: " + row.id,
      )
    }
    for source in real_sources(row) {
      errors.append(natural_source_errors(source))
    }
  }
  errors
}
