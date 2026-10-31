///|
priv struct NaturalSource {
  path : String
  sha256 : String
  split : String
} derive(FromJson, ToJson)

///|
fn natural_source_errors(source : NaturalSource) -> Array[String] {
  let errors : Array[String] = []
  if !@testkit.safe_relative_path(source.path) {
    errors.push("natural source path must remain relative to --corpus-root")
  }
  if source.sha256.length() != 64 ||
    !source.sha256
    .iter()
    .all(c => (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f')) {
    errors.push("natural source requires a lowercase SHA-256 identity")
  }
  if !["ordinary", "holdout"].contains(source.split) {
    errors.push("natural source split must be ordinary or holdout")
  }
  errors
}

///|
// Hashing and freezing are setup work; neither is inside a measured interval.
async fn benchmark_file_sha256(path : String) -> String {
  guard @fs.kind(path) is Regular else {
    fail("benchmark input is not a regular file: " + path)
  }
  let input = @fs.open(path, mode=ReadOnly)
  defer input.close()
  let hash = @crypto.SHA256::new()
  let buffer = FixedArray::make(65536, b'\x00')
  let bytes = buffer.unsafe_reinterpret_as_bytes()
  while input.read(buffer) is count && count > 0 {
    hash.update(bytes[:count])
  }
  @crypto.bytes_to_hex_string(hash.finalize())
}

///|
// Admit only a complete checked copy. Existing evidence is never overwritten.
async fn freeze_benchmark_file(
  source : String,
  target : String,
  expected? : String,
  executable~ : Bool = false,
) -> String {
  guard @fs.kind(source) is Regular else {
    fail("benchmark source is not a regular file: " + source)
  }
  guard !@fs.exists(target) else {
    fail("preserve existing frozen benchmark file: " + target)
  }
  let pending = target + ".pending"
  guard !@fs.exists(pending) else {
    fail("preserve incomplete frozen benchmark file: " + pending)
  }
  let input = @fs.open(source, mode=ReadOnly)
  defer input.close()
  let initial_size = input.size()
  let output = @fs.create(
    pending,
    allow_existing=false,
    permission=if executable { 493 } else { 420 },
  )
  defer (if @fs.exists(pending) { @fs.remove(pending) })
  defer output.close()
  let hash = @crypto.SHA256::new()
  let buffer = FixedArray::make(65536, b'\x00')
  let bytes = buffer.unsafe_reinterpret_as_bytes()
  let mut copied = 0L
  while input.read(buffer) is count && count > 0 {
    let chunk = bytes[:count]
    output.write(chunk)
    hash.update(chunk)
    copied += count.to_int64()
  }
  guard copied == initial_size && input.size() == initial_size else {
    fail("benchmark source changed length while freezing: " + source)
  }
  let digest = @crypto.bytes_to_hex_string(hash.finalize())
  if expected is Some(expected) && digest != expected {
    fail("benchmark source SHA-256 mismatch: " + source)
  }
  output.close()
  @fs.rename(pending, target, replace=false)
  assert_eq(benchmark_file_sha256(target), digest)
  digest
}

///|
fn natural_path_within(root : String, resolved : String) -> Bool {
  let normalize = fn(value : String) {
    let value = value
      .replace_all(old="\\", new="/")
      .trim_end(chars="/")
      .to_owned()
    if @testkit.host_platform() == "windows" {
      value.to_lower()
    } else {
      value
    }
  }
  normalize(resolved).has_prefix(normalize(root) + "/")
}

///|
async fn freeze_natural_input(
  source : NaturalSource,
  root : String,
  directory : String,
  completed : Map[String, Bool],
) -> (String, String) {
  let errors = natural_source_errors(source)
  guard errors.is_empty() else { fail(errors.join("; ")) }
  let input = @fs.realpath(@path.Path(root).join(Path(source.path)).to_string())
  guard natural_path_within(root, input) && @fs.kind(input) is Regular else {
    fail("natural source must be a regular file within --corpus-root")
  }
  guard @fs.file_size(input) <= 16777216L else {
    fail("real source exceeds16MiB limit: " + source.path)
  }
  let frozen = @path.Path(directory)
    .dirname()
    .join(Path("corpora/natural-" + source.sha256 + ".bin"))
    .to_string()
  if !completed.contains(frozen) {
    ignore(freeze_benchmark_file(input, frozen, expected=source.sha256))
    completed[frozen] = true
  }
  (input, frozen)
}

///|
async fn prepare_natural_source(
  workload : FunctionalWorkload,
  directory : String,
  options : Map[String, String],
  oracle : String,
  environment : Map[String, String],
  timeout_ms : Int32,
  completed : Map[String, Bool],
) -> PreparedCorpus? {
  guard workload.source is Some(source) else { return None }
  guard workload.corpus is None else {
    fail("a workload cannot mix generated and natural input")
  }
  let errors = natural_source_errors(source)
  guard errors.is_empty() else { fail(errors.join("; ")) }
  let requested_root = options.get("--corpus-root").unwrap_or("")
  guard @path.Path(requested_root).is_absolute() else {
    fail("natural input requires an absolute --corpus-root")
  }
  let root = @fs.realpath(requested_root)
  let (input, frozen) = freeze_natural_input(source, root, directory, completed)
  let additional : Array[Json] = []
  let secondary : Array[NaturalSource] = workload.inputs
    .unwrap_or([])
    .map(input => input.source)
  if workload.other_source is Some(other) {
    secondary.push(other)
  }
  for other in secondary {
    let (resolved, copy) = freeze_natural_input(
      other, root, directory, completed,
    )
    additional.push({
      "declared_source": Json(other),
      "resolved_source": resolved,
      "frozen_original": copy,
      "sha256": other.sha256,
      "bytes": @fs.file_size(copy),
    })
  }
  let measured = if workload.command == "gunzip" || workload.command == "zcat" {
    let mode = benchmark_gzip_input_mode(workload.recipe)
    let encoded = frozen + "-" + mode + ".gz"
    if !completed.contains(encoded) {
      prepare_benchmark_gzip_input(
        mode, frozen, encoded, oracle, environment, timeout_ms,
      )
      completed[encoded] = true
    }
    encoded
  } else {
    frozen
  }
  // A split label records declared evaluation policy, not proof of blindness.
  guard @fs.file_size(measured) <= 16777216L else {
    fail("prepared real input exceeds16MiB")
  }
  write_json(directory + "/natural-source.json", {
    "declared_source": Json(source),
    "other_sources": additional,
    "resolved_source": input,
    "frozen_original": frozen,
    "sha256": source.sha256,
    "bytes": @fs.file_size(frozen),
    "blind_holdout": false,
    "measured_input": measured,
    "measured_input_sha256": benchmark_file_sha256(measured),
    "transformation": if measured == frozen {
      "none; complete original file copied byte-for-byte"
    } else {
      "declared gzip semantic encoding outside timing; complete genuine payload retained and decoded bytes checked"
    },
    "encoding_mode": if measured == frozen {
      Json::null()
    } else {
      Json(benchmark_gzip_input_mode(workload.recipe))
    },
    "encoder_role": if measured == frozen {
      "none"
    } else if ["stored", "fixed-literals", "members"].contains(
        benchmark_gzip_input_mode(workload.recipe),
      ) {
      "pure MoonBit fixture encoder preserving every source byte; runtime tool identity frozen"
    } else {
      "frozen native gzip observer"
    },
  })
  Some({ source: frozen, input: measured, })
}

///|
fn natural_fixture(
  fixture : @testkit.Case,
  source : NaturalSource,
) -> @testkit.Case raise {
  let errors = natural_source_errors(source)
  guard errors.is_empty() else { fail(errors.join("; ")) }
  guard fixture.files.is_empty() else {
    fail("natural stdin input cannot inherit literal fixture files")
  }
  {
    ..fixture,
    stdin_text: None,
    stdin_hex: None,
    expected_stdout_text: None,
    expected_stdout_hex: None,
    expected_stdout_contains: None,
    expected_stdout_contains_all: None,
    expected_stdout_ends_with_newline: None,
    expected_files: None,
    comparison: Some("exact"),
  }
}
