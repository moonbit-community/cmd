///|
fn natural_key_less(left : String, right : String) -> Bool {
  for i in 0..<left.length().min(right.length()) {
    if left[i] != right[i] {
      return left[i] < right[i]
    }
  }
  left.length() < right.length()
}

///|
async fn natural_key_overlap(left : String, right : String) -> Json {
  guard @fs.file_size(left) <= 4194304L && @fs.file_size(right) <= 4194304L else {
    fail("natural key-set observation exceeds4MiB bound")
  }
  let a = @fs.read_file(left)
    .text()
    .split("\n")
    .filter(line => !line.is_empty())
    .map(line => line.to_owned())
    .to_array()
  let b = @fs.read_file(right)
    .text()
    .split("\n")
    .filter(line => !line.is_empty())
    .map(line => line.to_owned())
    .to_array()
  let mut i = 0
  let mut j = 0
  let mut common = 0
  let mut left_only = 0
  let mut right_only = 0
  while i < a.length() && j < b.length() {
    if a[i] == b[j] {
      common += 1
      i += 1
      j += 1
    } else if natural_key_less(a[i], b[j]) {
      left_only += 1
      i += 1
    } else {
      right_only += 1
      j += 1
    }
  }
  left_only += a.length() - i
  right_only += b.length() - j
  guard common > 0 && left_only > 0 && right_only > 0 else {
    fail("natural pair must activate shared and both unpaired key regimes")
  }
  {
    "common_keys": common,
    "left_only_keys": left_only,
    "right_only_keys": right_only,
  }
}

///|
async fn prepare_natural_pair(
  workload : FunctionalWorkload,
  prepared : PreparedCorpus,
  root : String,
  oracle : String,
  environment : Map[String, String],
  timeout_ms : Int32,
) -> Unit {
  guard workload.other_source is Some(other) && @path.Path(oracle).is_absolute() else {
    fail(
      "natural pair requires a frozen second source and explicit fixed observers",
    )
  }
  let secondary = @path.Path(prepared.source)
    .dirname()
    .join(Path("natural-" + other.sha256 + ".bin"))
    .to_string()
  assert_eq(benchmark_file_sha256(secondary), other.sha256)
  let parent = @path.Path(root).dirname().to_string()
  let prefix = parent +
    "/" +
    @path.Path(root).basename().to_owned() +
    "-prepare-"
  let observe = async fn(command, args, input, output, tag) {
    corpus_observer(
      oracle + "/" + command,
      args,
      input,
      output,
      environment,
      timeout_ms,
      receipt_prefix=prefix + tag,
    )
  }
  observe(
    "cut",
    ["-d", ",", "-f", "1"],
    prepared.source,
    root + "/airport-keys",
    "cut-left",
  )
  observe(
    "cut",
    ["-d", ",", "-f", "4"],
    secondary,
    root + "/route-keys",
    "cut-right",
  )
  observe(
    "sort",
    ["-u"],
    root + "/airport-keys",
    root + "/airport-set",
    "set-left",
  )
  observe(
    "sort",
    ["-u"],
    root + "/route-keys",
    root + "/route-set",
    "set-right",
  )
  let overlap = natural_key_overlap(root + "/airport-set", root + "/route-set")
  if workload.command == "join" {
    observe(
      "sort",
      ["-t", ",", "-k1,1"],
      prepared.source,
      root + "/left",
      "sort-left",
    )
    observe(
      "sort",
      ["-t", ",", "-k4,4"],
      secondary,
      root + "/right",
      "sort-right",
    )
  } else {
    let a = @fs.create(root + "/left")
    copy_recipe_range(
      root + "/airport-set",
      a,
      0L,
      @fs.file_size(root + "/airport-set"),
    )
    a.close()
    let b = @fs.create(root + "/right")
    copy_recipe_range(
      root + "/route-set",
      b,
      0L,
      @fs.file_size(root + "/route-set"),
    )
    b.close()
  }
  write_json(root + "/recipe-features.json", {
    "recipe": workload.recipe.unwrap(),
    "input_transport": "distinct-named-files",
    "same_file_identity": false,
    "transformation": "fixed native cut and bytewise sort outside timing; complete originals retained",
    "primary_sha256": benchmark_file_sha256(prepared.source),
    "secondary_sha256": other.sha256,
    "left_sha256": benchmark_file_sha256(root + "/left"),
    "right_sha256": benchmark_file_sha256(root + "/right"),
    "key_overlap": overlap,
  })
}
