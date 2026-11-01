///|
priv struct BenchmarkFeatureObserver {
  byte_histogram : FixedArray[Int64]
  record_rows : FixedArray[Int64]
  record_bytes : FixedArray[Int64]
  record_payload_bytes : FixedArray[Int64]
  run_rows : FixedArray[Int64]
  run_records : FixedArray[Int64]
  distinct : Map[String, Bool]
  record_hash : @crypto.SHA256
  mut bytes : Int64
  mut lfs : Int64
  mut records : Int64
  mut record_length : Int64
  mut shortest : Int64?
  mut longest : Int64?
  mut ascii : Int64
  mut non_ascii : Int64
  mut nul : Int64
  mut whitespace : Int64
  mut tabs : Int64
  mut spaces : Int64
  mut marker_prefix : Int32
  mut marker_occurrences : Int64
  mut marker_records : Int64
  mut marker_first_byte_candidates : Int64
  mut marker_candidate_records : Int64
  mut record_has_marker : Bool
  mut record_has_candidate : Bool
  mut previous_digest : String?
  mut current_run : Int64
  mut runs : Int64
  mut longest_run : Int64
  mut adjacent_duplicate_pairs : Int64
  mut distinct_truncated : Bool
}

///|
fn BenchmarkFeatureObserver::new() -> BenchmarkFeatureObserver {
  {
    byte_histogram: FixedArray::make(256, 0L),
    record_rows: FixedArray::make(4, 0L),
    record_bytes: FixedArray::make(4, 0L),
    record_payload_bytes: FixedArray::make(4, 0L),
    run_rows: FixedArray::make(5, 0L),
    run_records: FixedArray::make(5, 0L),
    distinct: Map([]),
    record_hash: @crypto.SHA256::new(),
    bytes: 0L,
    lfs: 0L,
    records: 0L,
    record_length: 0L,
    shortest: None,
    longest: None,
    ascii: 0L,
    non_ascii: 0L,
    nul: 0L,
    whitespace: 0L,
    tabs: 0L,
    spaces: 0L,
    marker_prefix: 0,
    marker_occurrences: 0L,
    marker_records: 0L,
    marker_first_byte_candidates: 0L,
    marker_candidate_records: 0L,
    record_has_marker: false,
    record_has_candidate: false,
    previous_digest: None,
    current_run: 0L,
    runs: 0L,
    longest_run: 0L,
    adjacent_duplicate_pairs: 0L,
    distinct_truncated: false,
  }
}

///|
fn BenchmarkFeatureObserver::finish_run(
  self : BenchmarkFeatureObserver,
) -> Unit {
  if self.current_run == 0L {
    return
  }
  let bin = if self.current_run == 1L {
    0
  } else if self.current_run == 2L {
    1
  } else if self.current_run <= 8L {
    2
  } else if self.current_run <= 64L {
    3
  } else {
    4
  }
  self.run_rows[bin] += 1L
  self.run_records[bin] += self.current_run
  self.runs += 1L
  if self.current_run > self.longest_run {
    self.longest_run = self.current_run
  }
}

///|
fn BenchmarkFeatureObserver::finish_record(
  self : BenchmarkFeatureObserver,
  terminated : Bool,
) -> Unit {
  let length = self.record_length
  let bin = if length <= 128L {
    0
  } else if length <= 1024L {
    1
  } else if length <= 65536L {
    2
  } else {
    3
  }
  self.record_rows[bin] += 1L
  self.record_payload_bytes[bin] += length
  self.record_bytes[bin] += length + (if terminated { 1L } else { 0L })
  self.records += 1L
  if self.shortest is None || (self.shortest is Some(value) && length < value) {
    self.shortest = Some(length)
  }
  if self.longest is None || (self.longest is Some(value) && length > value) {
    self.longest = Some(length)
  }
  if self.record_has_marker {
    self.marker_records += 1L
  }
  if self.record_has_candidate {
    self.marker_candidate_records += 1L
  }
  let digest = @crypto.bytes_to_hex_string(self.record_hash.finalize())
  if self.previous_digest is Some(previous) && previous == digest {
    self.current_run += 1L
    self.adjacent_duplicate_pairs += 1L
  } else {
    self.finish_run()
    self.current_run = 1L
  }
  self.previous_digest = Some(digest)
  if !self.distinct.contains(digest) {
    if self.distinct.length() < 4096 {
      self.distinct[digest] = true
    } else {
      self.distinct_truncated = true
    }
  }
  @crypto.CryptoHasher::reset(self.record_hash)
  self.record_length = 0L
  self.record_has_marker = false
  self.record_has_candidate = false
  self.marker_prefix = 0
}

///|
// A record is hashed in slices from the fixed input buffer. No complete
// record, including an unterminated record, is retained in memory.
fn BenchmarkFeatureObserver::update(
  self : BenchmarkFeatureObserver,
  chunk : BytesView,
) -> Unit {
  let marker = b"needle"
  let mut segment = 0
  self.bytes += chunk.length().to_int64()
  for index in 0..<chunk.length() {
    let byte = chunk[index]
    self.byte_histogram[byte.to_int()] += 1L
    if byte < b'\x80' {
      self.ascii += 1L
    } else {
      self.non_ascii += 1L
    }
    if byte == b'\x00' {
      self.nul += 1L
    }
    if byte == b' ' {
      self.spaces += 1L
    }
    if byte == b'\t' {
      self.tabs += 1L
    }
    if byte == b' ' || (byte >= b'\t' && byte <= b'\r') {
      self.whitespace += 1L
    }
    if byte == b'n' {
      self.marker_first_byte_candidates += 1L
      self.record_has_candidate = true
    }
    // The marker has no proper suffix that is also a prefix. Falling back
    // to a single 'n' therefore preserves all nonoverlapping occurrences.
    if byte == marker[self.marker_prefix] {
      self.marker_prefix += 1
      if self.marker_prefix == marker.length() {
        self.marker_occurrences += 1L
        self.record_has_marker = true
        self.marker_prefix = 0
      }
    } else {
      self.marker_prefix = if byte == b'n' { 1 } else { 0 }
    }
    if byte == b'\n' {
      self.record_hash.update(chunk[segment:index])
      self.lfs += 1L
      self.finish_record(true)
      segment = index + 1
    } else {
      self.record_length += 1L
    }
  }
  self.record_hash.update(chunk[segment:])
}

///|
fn BenchmarkFeatureObserver::report(
  self : BenchmarkFeatureObserver,
  path : String,
  sha256 : String,
) -> Json {
  let tail = self.record_length
  if tail > 0L {
    self.finish_record(false)
  }
  self.finish_run()
  let lengths = ["<=128", "129..1024", "1025..65536", ">65536"]
  let runs = ["1", "2", "3..8", "9..64", ">64"]
  {
    "schema": 1,
    "observation": "complete-file streaming byte observation",
    "observed_path": path,
    "sha256": sha256,
    "bytes": self.bytes,
    "stream_buffer_bytes": 65536,
    "retained_record_bytes": 0,
    "records": {
      "count": self.records,
      "lf_count": self.lfs,
      "unterminated_tail": tail > 0L,
      "unterminated_tail_bytes": tail,
      "length_excludes_lf": true,
      "min_bytes": match self.shortest {
        Some(value) => Json(value)
        None => Json::null()
      },
      "max_bytes": match self.longest {
        Some(value) => Json(value)
        None => Json::null()
      },
      "histogram_byte_weight_includes_lf": true,
      "length_histogram": Array::makei(4, index => {
        (
          {
            "bin": lengths[index],
            "records": self.record_rows[index],
            "bytes": self.record_bytes[index],
            "payload_bytes": self.record_payload_bytes[index],
          } : Json)
      }),
    },
    "byte_distribution": {
      "histogram": Array::makei(256, index => self.byte_histogram[index]),
      "distinct_byte_values": self.byte_histogram
      .iter()
      .filter(value => value > 0L)
      .count(),
      "ascii_bytes": self.ascii,
      "non_ascii_bytes": self.non_ascii,
      "nul_bytes": self.nul,
      "ascii_whitespace_bytes": self.whitespace,
      "tab_bytes": self.tabs,
      "space_bytes": self.spaces,
    },
    "literal_marker": {
      "literal": "needle",
      "nonoverlapping_occurrences": self.marker_occurrences,
      "records_with_literal": self.marker_records,
      "first_byte_candidates": self.marker_first_byte_candidates,
      "records_with_first_byte_candidate": self.marker_candidate_records,
      "scope": "literal byte observations; no regex or DFA route inference",
    },
    "record_repetition": {
      "digest": "SHA-256 of record payload excluding LF",
      "runs": self.runs,
      "max_run_records": self.longest_run,
      "adjacent_duplicate_pairs": self.adjacent_duplicate_pairs,
      "run_length_histogram": Array::makei(5, index => {
        (
          {
            "bin": runs[index],
            "runs": self.run_rows[index],
            "records": self.run_records[index],
          } : Json)
      }),
      "distinct_digest_capacity": 4096,
      "retained_distinct_record_digests": self.distinct.length(),
      "distinct_records_lower_bound": self.distinct.length() +
      (if self.distinct_truncated { 1 } else { 0 }),
      "distinct_records_exact": !self.distinct_truncated,
      "distinct_digest_capacity_exceeded": self.distinct_truncated,
    },
  }
}

///|
// This observation is setup/evidence work and must stay outside timing.
async fn observe_benchmark_features(path : String) -> Json {
  guard @fs.kind(path) is Regular else {
    fail("benchmark features require a regular file: " + path)
  }
  let input = @fs.open(path, mode=ReadOnly)
  defer input.close()
  let size = input.size()
  let hash = @crypto.SHA256::new()
  let observer = BenchmarkFeatureObserver::new()
  let buffer = FixedArray::make(65536, b'\x00')
  let bytes = buffer.unsafe_reinterpret_as_bytes()
  while input.read(buffer) is count && count > 0 {
    let chunk = bytes[:count]
    hash.update(chunk)
    observer.update(chunk)
  }
  guard observer.bytes == size && input.size() == size else {
    fail("benchmark input changed length during feature observation: " + path)
  }
  observer.report(path, @crypto.bytes_to_hex_string(hash.finalize()))
}

///|
// The cache belongs to a fresh run's frozen input. Callers validate the
// reported SHA-256 before and after execution; a filename is not an identity.
async fn ensure_benchmark_features(path : String) -> Json {
  let cached = path + ".observed-features.json"
  if @fs.exists(cached) {
    guard @fs.file_size(cached) <= 65536L else {
      fail("oversized benchmark feature cache: " + cached)
    }
    let observed = @json.parse(@fs.read_file(cached).text())
    guard observed is Object(fields) &&
      fields.get("schema") == Some(Json(1)) &&
      fields.get("observed_path") == Some(Json(path)) else {
      fail("invalid benchmark feature cache: " + cached)
    }
    observed
  } else {
    let observed = observe_benchmark_features(path)
    write_json(cached, observed)
    observed
  }
}
