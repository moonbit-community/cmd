///|
fn require_frozen_timing_backend(
  options : Map[String, String],
  sample : Bool,
) -> Unit raise {
  guard !sample || options.contains("--wasm-root") else {
    fail(
      "new timing requires explicit frozen Wasm artifacts; use baseline for published MoonX correctness or report for historical timing",
    )
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
  } else if workload.recipe == Some("yes") {
    "bounded-pipe-consumer-4096-bytes-then-close"
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
  let sources : Map[String, String] = Map([])
  if workloads.is_empty() {
    errors.push("empty functional workload selection")
  }
  for row in workloads {
    if !@testkit.safe_relative_path(row.id) || ids.contains(row.id) {
      errors.push("unsafe or duplicate workload ID: " + row.id)
    }
    ids.add(row.id)
    if row.sink is Some(sink) && sink != "slow-pipe" {
      errors.push("unknown output sink: " + row.id)
    }
    if row.sink == Some("slow-pipe") {
      if !(row.sink_chunk_bytes is Some(chunk) && chunk > 0 && chunk <= 65537) ||
        !(row.sink_delay_ms is Some(delay) && delay >= 1 && delay <= 20) ||
        row.recipe == Some("yes") ||
        row.transport is Some(_) {
        errors.push(
          "slow pipe requires bounded chunk/delay and regular input: " + row.id,
        )
      }
    } else if row.sink_chunk_bytes is Some(_) || row.sink_delay_ms is Some(_) {
      errors.push("output chunk/delay require slow-pipe sink: " + row.id)
    }
    if row.command.is_empty() || row.reference_behavior_id.is_empty() {
      errors.push("missing command or behavior reference: " + row.id)
    }
    if (row.case_id is Some(_)) == (row.recipe is Some(_)) {
      errors.push("workload requires exactly one case or recipe: " + row.id)
    }
    if row.pending == Some("") {
      errors.push("empty pending reason: " + row.id)
    }
    if row.transport is Some(transport) && transport != "fragmented-pipe" {
      errors.push("unknown benchmark transport: " + row.id)
    }
    if row.transport == Some("fragmented-pipe") {
      if !(row.chunk_bytes is Some(chunk) && chunk > 0 && chunk <= 65537) ||
        benchmark_file_recipe(row.recipe) ||
        row.recipe == Some("yes") ||
        (row.corpus is None && row.source is None) {
        errors.push(
          "fragmented pipe needs bounded chunks and a full stdin corpus: " +
          row.id,
        )
      }
    } else if row.chunk_bytes is Some(_) {
      errors.push(
        "producer chunk size requires fragmented pipe transport: " + row.id,
      )
    }
    if row.corpus is Some(spec) {
      errors.append(corpus_spec_errors(spec))
    }
    if row.seed is Some(seed) {
      if seed < 0 || seed > 65535 || row.corpus is None || row.source is Some(_) {
        errors.push(
          "generated seed requires a generated corpus and range0..65535: " +
          row.id,
        )
      }
      if seed != 0 &&
        row.corpus is Some(spec) &&
        !corpus_supports_variants(spec.shape) {
        errors.push("seed would not vary actual corpus bytes: " + row.id)
      }
    }
    if row.source is Some(source) {
      errors.append(natural_source_errors(source))
      if row.corpus is Some(_) {
        errors.push(
          "generated and natural source cannot be combined: " + row.id,
        )
      }
      if sources.get(source.sha256) is Some(split) && split != source.split {
        errors.push(
          "natural data leaks across ordinary/holdout splits: " + row.id,
        )
      }
      sources[source.sha256] = source.split
    }
    if row.other_source is Some(other) {
      errors.append(natural_source_errors(other))
      if row.source is None ||
        ![
          Some("bench-join-natural-csv"),
          Some("bench-comm-natural-idsets"),
          Some("real-file-pair"),
        ].contains(row.recipe) {
        errors.push(
          "second natural source requires an explicit two-source recipe: " +
          row.id,
        )
      }
      if sources.get(other.sha256) is Some(split) && split != other.split {
        errors.push(
          "secondary natural input leaks across evaluation splits: " + row.id,
        )
      }
      sources[other.sha256] = other.split
    }
  }
  errors
}

///|
fn functional_case_corpus(
  manifest : FunctionalManifest,
  workspace : Bool,
) -> String {
  if workspace {
    manifest.workspace_case_corpus.unwrap_or(manifest.case_corpus)
  } else {
    manifest.case_corpus
  }
}
