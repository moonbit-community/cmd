///|
fn feature_field(value : Json, key : String) -> Json raise {
  guard value is Object(fields) && fields.get(key) is Some(found) else {
    fail("missing observed feature: " + key)
  }
  found
}

///|
fn feature_histogram(value : Json, key : String) -> Array[Json] raise {
  guard feature_field(value, key) is Array(items) else {
    fail("feature histogram is not an array")
  }
  items
}

///|
async test "observed feature histograms retain both row and complete-byte weights" {
  let root = @fs.tmpdir(prefix="cmd-feature-weights-")
  defer @fs.rmdir(root, recursive=true)
  let path = root + "/mixed"
  let text = "\n" +
    "a".repeat(128) +
    "\nbb\n" +
    "c".repeat(129) +
    "\n" +
    "d".repeat(1025) +
    "\n"
  @fs.write_file(path, text)
  let observed = observe_benchmark_features(path)
  assert_eq(feature_field(observed, "bytes"), Json(1289L))
  assert_eq(
    feature_field(observed, "sha256"),
    Json(benchmark_file_sha256(path)),
  )
  let records = feature_field(observed, "records")
  assert_eq(feature_field(records, "count"), Json(5L))
  assert_eq(feature_field(records, "lf_count"), Json(5L))
  assert_eq(feature_field(records, "unterminated_tail"), Json(false))
  assert_eq(feature_field(records, "min_bytes"), Json(0L))
  assert_eq(feature_field(records, "max_bytes"), Json(1025L))
  let bins = feature_histogram(records, "length_histogram")
  for
    (index, rows, bytes, payload) in [
      (0, 3L, 133L, 130L),
      (1, 1L, 130L, 129L),
      (2, 1L, 1026L, 1025L),
      (3, 0L, 0L, 0L),
    ] {
    assert_eq(feature_field(bins[index], "records"), Json(rows))
    assert_eq(feature_field(bins[index], "bytes"), Json(bytes))
    assert_eq(feature_field(bins[index], "payload_bytes"), Json(payload))
  }
  @fs.write_file(root + "/empty", b"")
  let empty = feature_field(
    observe_benchmark_features(root + "/empty"),
    "records",
  )
  assert_eq(feature_field(empty, "count"), Json(0L))
  assert_eq(feature_field(empty, "min_bytes"), Json::null())
  assert_eq(feature_field(empty, "max_bytes"), Json::null())
}

///|
async test "observed markers cross read boundaries and long records retain all bytes" {
  let root = @fs.tmpdir(prefix="cmd-feature-boundaries-")
  defer @fs.rmdir(root, recursive=true)
  let path = root + "/split-marker"
  @fs.write_file(path, "x".repeat(65534) + "needle\nnexneedle")
  let observed = observe_benchmark_features(path)
  assert_eq(feature_field(observed, "bytes"), Json(65550L))
  let marker = feature_field(observed, "literal_marker")
  assert_eq(feature_field(marker, "nonoverlapping_occurrences"), Json(2L))
  assert_eq(feature_field(marker, "records_with_literal"), Json(2L))
  assert_eq(feature_field(marker, "first_byte_candidates"), Json(3L))
  assert_eq(
    feature_field(marker, "records_with_first_byte_candidate"),
    Json(2L),
  )
  let records = feature_field(observed, "records")
  assert_eq(feature_field(records, "count"), Json(2L))
  assert_eq(feature_field(records, "unterminated_tail_bytes"), Json(9L))
  assert_eq(feature_field(records, "max_bytes"), Json(65540L))
  let bins = feature_histogram(records, "length_histogram")
  assert_eq(feature_field(bins[0], "bytes"), Json(9L))
  assert_eq(feature_field(bins[3], "bytes"), Json(65541L))
  let long = root + "/long"
  let bytes = Bytes::make(196613, b'z')
  @fs.write_file(long, bytes)
  let observed = observe_benchmark_features(long)
  assert_eq(feature_field(observed, "bytes"), Json(196613L))
  assert_eq(
    feature_field(observed, "sha256"),
    Json(@testkit.sha256_bytes(bytes)),
  )
  assert_eq(feature_field(observed, "stream_buffer_bytes"), Json(65536))
  assert_eq(feature_field(observed, "retained_record_bytes"), Json(0))
  let records = feature_field(observed, "records")
  assert_eq(feature_field(records, "count"), Json(1L))
  assert_eq(feature_field(records, "lf_count"), Json(0L))
  assert_eq(feature_field(records, "unterminated_tail_bytes"), Json(196613L))
  assert_eq(feature_field(records, "min_bytes"), Json(196613L))
  assert_eq(
    feature_field(feature_histogram(records, "length_histogram")[3], "bytes"),
    Json(196613L),
  )
}

///|
async test "observed binary bytes and unterminated tails remain byte based" {
  let root = @fs.tmpdir(prefix="cmd-feature-binary-")
  defer @fs.rmdir(root, recursive=true)
  let path = root + "/binary"
  @fs.write_file(path, b"\x00\xff \t\r\n\x80")
  let observed = observe_benchmark_features(path)
  let distribution = feature_field(observed, "byte_distribution")
  for
    (name, count) in [
      ("ascii_bytes", 5L),
      ("non_ascii_bytes", 2L),
      ("nul_bytes", 1L),
      ("ascii_whitespace_bytes", 4L),
      ("tab_bytes", 1L),
      ("space_bytes", 1L),
    ] {
    assert_eq(feature_field(distribution, name), Json(count))
  }
  assert_eq(feature_field(distribution, "distinct_byte_values"), Json(7))
  let histogram = feature_histogram(distribution, "histogram")
  assert_eq(histogram.length(), 256)
  assert_eq(histogram[0], Json(1L))
  assert_eq(histogram[128], Json(1L))
  assert_eq(histogram[255], Json(1L))
  let records = feature_field(observed, "records")
  assert_eq(feature_field(records, "count"), Json(2L))
  assert_eq(feature_field(records, "unterminated_tail"), Json(true))
  assert_eq(feature_field(records, "unterminated_tail_bytes"), Json(1L))
  assert_eq(feature_field(records, "max_bytes"), Json(5L))
}

///|
async test "observed SHA record runs distinguish repetition from distinct records" {
  let root = @fs.tmpdir(prefix="cmd-feature-runs-")
  defer @fs.rmdir(root, recursive=true)
  for
    (name, bytes, runs, max_run, pairs, distinct) in [
      ("repeated", b"same\nsame\nother\nother\nother\nsame", 3L, 3L, 3L, 2),
      (
        "different", b"first\nsecond\nthird\nfourth\nfifth\nsixth", 6L, 1L, 0L, 6,
      ),
    ] {
    let path = root + "/" + name
    @fs.write_file(path, bytes)
    let repetition = feature_field(
      observe_benchmark_features(path),
      "record_repetition",
    )
    assert_eq(feature_field(repetition, "runs"), Json(runs))
    assert_eq(feature_field(repetition, "max_run_records"), Json(max_run))
    assert_eq(
      feature_field(repetition, "adjacent_duplicate_pairs"),
      Json(pairs),
    )
    assert_eq(
      feature_field(repetition, "distinct_records_lower_bound"),
      Json(distinct),
    )
    assert_eq(feature_field(repetition, "distinct_records_exact"), Json(true))
  }
  let path = root + "/capacity"
  @fs.write_file(
    path,
    Array::makei(4100, index => index.to_string()).join("\n"),
  )
  let repetition = feature_field(
    observe_benchmark_features(path),
    "record_repetition",
  )
  assert_eq(
    feature_field(repetition, "retained_distinct_record_digests"),
    Json(4096),
  )
  assert_eq(
    feature_field(repetition, "distinct_records_lower_bound"),
    Json(4097),
  )
  assert_eq(feature_field(repetition, "distinct_records_exact"), Json(false))
  assert_eq(feature_field(repetition, "runs"), Json(4100L))
  assert_eq(feature_field(repetition, "adjacent_duplicate_pairs"), Json(0L))
}

///|
async test "frozen input feature caching preserves actual identity and rejects malformed evidence" {
  let root = @fs.tmpdir(prefix="cmd-feature-cache-")
  defer @fs.rmdir(root, recursive=true)
  let path = root + "/frozen"
  @fs.write_file(path, b"needle\nneedle")
  let encoder_metadata : Json = {
    "deflate_block": "fixed",
    "source_validated": true,
  }
  @fs.write_file(path + ".features.json", encoder_metadata.stringify())
  let observed = ensure_benchmark_features(path)
  assert_true(@fs.exists(path + ".observed-features.json"))
  assert_eq(
    @json.parse(@fs.read_file(path + ".features.json").text()),
    encoder_metadata,
  )
  assert_eq(ensure_benchmark_features(path), observed)
  assert_eq(
    feature_field(observed, "sha256"),
    Json(benchmark_file_sha256(path)),
  )
  @fs.write_file(path + ".observed-features.json", "{}")
  let accepted = try {
    ignore(ensure_benchmark_features(path))
    true
  } catch {
    _ => false
  }
  assert_false(accepted)
}
