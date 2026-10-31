///|
fn benchmark_file_recipe(recipe : String?) -> Bool {
  [
    Some("real-file-pair"),
    Some("bench-join-natural-csv"),
    Some("bench-comm-natural-idsets"),
  ].contains(recipe)
}

///|
async fn copy_recipe_range(
  source : String,
  output : @fs.File,
  start : Int64,
  length : Int64,
) -> Unit {
  let input = @fs.open(source, mode=ReadOnly)
  defer input.close()
  guard start >= 0L && length >= 0L && start + length <= input.size() else {
    fail("invalid recipe source range")
  }
  let mut offset = 0L
  while offset < length {
    let count = (length - offset).min(65536L).to_int()
    output.write(input.read_exactly_at(count, position=start + offset))
    offset += count.to_int64()
  }
}

///|
// Setup is outside timing. Equal-input controls use distinct files; join and
// comm inputs have declared overlap/duplicate regimes rather than self-input.
async fn prepare_benchmark_recipe(
  workload : FunctionalWorkload,
  prepared : PreparedCorpus?,
  root : String,
  oracle~ : String = "",
  environment~ : Map[String, String] = Map([]),
  timeout_ms~ : Int32 = 120000,
) -> Unit {
  guard benchmark_file_recipe(workload.recipe) else { return }
  guard prepared is Some(prepared) else {
    fail("file-mode benchmark requires a declared input corpus")
  }
  let recipe = workload.recipe.unwrap()
  if recipe == "real-file-pair" {
    guard workload.other_source is Some(other) else {
      fail("real file pair requires two declared sources")
    }
    let secondary = @path.Path(prepared.source)
      .dirname()
      .join(Path("natural-" + other.sha256 + ".bin"))
      .to_string()
    assert_eq(benchmark_file_sha256(secondary), other.sha256)
    let left = @fs.create(root + "/left")
    copy_recipe_range(prepared.source, left, 0L, @fs.file_size(prepared.source))
    left.close()
    let right = @fs.create(root + "/right")
    copy_recipe_range(secondary, right, 0L, @fs.file_size(secondary))
    right.close()
    write_json(root + "/recipe-features.json", {
      "recipe": recipe,
      "transformation": "distinct complete copies of declared genuine sources; no generated edits",
      "left_sha256": benchmark_file_sha256(root + "/left"),
      "right_sha256": benchmark_file_sha256(root + "/right"),
    })
    return
  }
  if ["bench-join-natural-csv", "bench-comm-natural-idsets"].contains(recipe) {
    prepare_natural_pair(
      workload, prepared, root, oracle, environment, timeout_ms,
    )
    return
  }
  fail("unregistered genuine file preparation: " + recipe)
}
