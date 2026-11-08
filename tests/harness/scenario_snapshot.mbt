///|
async fn scenario_source_files(
  directory : String,
  files : Array[String],
) -> Unit {
  for name in @fs.readdir(repository_path(directory)) {
    let path = directory + "/" + name
    match @fs.kind(repository_path(path), follow_symlink=false) {
      Directory => scenario_source_files(path, files)
      Regular if name.has_suffix(".mbt") || name == "moon.pkg" =>
        files.push(path)
      _ => ()
    }
  }
}

///|
pub async fn scenario_contract_snapshot(cases : Array[Case]) -> Json {
  let catalog = @json.parse(
    @fs.read_file(repository_path("tests/coverage/review/scenarios.json")).text(),
  )
  let errors = scenario_catalog_errors(catalog)
  guard errors.is_empty() else { fail(errors.join("\n")) }
  let selected : Array[Json] = []
  for fixture in cases {
    if fixture.comparison == Some("scenario") &&
      scenario_definition(catalog, fixture.id) is Some(definition) {
      selected.push(definition)
    }
  }
  selected.sort_by((a, b) => {
    match (scenario_field(a, "case_id"), scenario_field(b, "case_id")) {
      (String(a), String(b)) => a.lexical_compare(b)
      _ => 0
    }
  })
  let files = [
    "tests/moon.mod", "tests/run.mbtx", "tests/tools/validate.mbtx", "tests/coverage/review/scenarios.json",
    "tests/tools/public_suffix.mbtx", "tests/fixtures/psl/public_suffix_list.dat",
    "tests/fixtures/psl/test_psl.txt", "tests/tools/idna.mbtx", "tests/fixtures/idna/IdnaMappingTable.txt",
    "tests/fixtures/idna/Idna2008.txt", "tests/fixtures/idna/UnicodeData.txt", "tests/fixtures/idna/DerivedJoiningType.txt",
    "tests/fixtures/idna/NormalizationTest.txt", "tests/fixtures/idna/LICENSE.txt",
  ]
  for directory in ["tests/harness", "tests/scenarios", "tests/coverage"] {
    scenario_source_files(directory, files)
  }
  files.sort()
  let sources : Array[Json] = []
  for path in files {
    sources.push({
      "path": path,
      "sha256": sha256_bytes(@fs.read_file(repository_path(path)).binary()),
    })
  }
  { "schema": 1, "scenarios": selected, "assertion_sources": sources }
}
