///|
async fn functional_inventory(
  options : Map[String, String],
) -> Array[FunctionalWorkload] {
  let path = options.get("--manifest").unwrap_or("tests/benchmark/real.json")
  let manifest : FunctionalManifest = @json.from_json(
    @json.parse(@fs.read_file(path).text()),
  )
  guard manifest.schema == 2 || manifest.schema == 3 else {
    fail(
      "benchmark inventory requires schema2 historical definitions or schema3 real workloads",
    )
  }
  let base : Array[FunctionalWorkload] = match manifest.base_manifest {
    Some(path) => {
      let value : FunctionalManifest = @json.from_json(
        @json.parse(@fs.read_file(path).text()),
      )
      value.workloads
    }
    None => []
  }
  let rows = expand_corpus_sweeps(manifest, base)
  if manifest.schema == 3 {
    validate_real_suite(path, rows)
  }
  let rows = match options.get("--commands") {
    Some(selection) => {
      let names = selection.split(",").map(name => name.to_owned()).to_array()
      let seen : Set[String] = Set([])
      for name in names {
        guard !name.is_empty() &&
          !seen.contains(name) &&
          rows.any(row => row.command == name) else {
          fail("unknown, empty or duplicate benchmark command: " + name)
        }
        seen.add(name)
      }
      rows.filter(row => seen.contains(row.command))
    }
    None => rows
  }
  let errors = functional_workload_errors(rows)
  guard errors.is_empty() else { fail(errors.join("; ")) }
  rows
}
