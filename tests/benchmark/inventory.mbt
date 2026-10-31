///|
async fn functional_inventory(
  options : Map[String, String],
) -> Array[FunctionalWorkload] {
  let path = options.get("--manifest").unwrap_or("tests/benchmark/real.json")
  let manifest : FunctionalManifest = @json.from_json(
    @json.parse(@fs.read_file(path).text()),
  )
  guard manifest.schema == 3 else {
    fail("benchmark inventory requires schema3 complete real-source workloads")
  }
  validate_real_suite(path, manifest.workloads)
  let rows = match options.get("--commands") {
    Some(selection) => {
      let names = selection.split(",").map(name => name.to_owned()).to_array()
      let seen : Set[String] = Set([])
      for name in names {
        guard !name.is_empty() &&
          !seen.contains(name) &&
          manifest.workloads.any(row => row.command == name) else {
          fail("unknown, empty or duplicate benchmark command: " + name)
        }
        seen.add(name)
      }
      manifest.workloads.filter(row => seen.contains(row.command))
    }
    None => manifest.workloads
  }
  let errors = functional_workload_errors(rows)
  guard errors.is_empty() else { fail(errors.join("; ")) }
  rows
}
