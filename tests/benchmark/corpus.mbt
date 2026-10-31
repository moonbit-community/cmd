///|
priv struct CorpusSpec {
  bytes : Int64
  record_bytes : Int64
  shape : String
} derive(FromJson, ToJson)

///|
let corpus_seed : Bytes = b"0123456789abcdef0123456789abcdef"

///|
fn corpus_variant_key(seed : Int32) -> Bytes {
  Bytes::makei(corpus_seed.length(), i => {
    corpus_seed[i] ^ (seed >> (i % 4 * 8)).to_byte()
  })
}

///|
fn corpus_supports_variants(shape : String) -> Bool {
  [
    "high-entropy", "varied-ascii-v1", "mixed-ascii-v1", "mixed-short-ascii-v1",
    "mixed-short-clustered-ascii-v1", "duplicate-runs-v1", "varied-jsonl-v1", "nested-jsonl-v1",
    "nested-large-jsonl-v1", "sections-ascii-v1", "tabs-spaces-v1", "short-cells-v1",
  ].contains(shape)
}

///|
priv struct CorpusSweep {
  workloads : Array[String]
  axes : Array[String]
  shapes : Array[String]
  record_total_bytes : Array[Int64]?
  shape_total_bytes : Array[Int64]?
  throughput_total_bytes : Array[Int64]?
} derive(FromJson, ToJson)

///|
fn corpus_sizes(axis : String) -> Array[Int64] raise {
  match axis {
    "startup" => [0L, 1L, 4096L]
    "throughput" => [8388608L, 67108864L, 536870912L]
    "records" => [1024L, 65536L, 1048576L, 8388608L, 67108864L]
    "shapes" => [8388608L]
    _ => fail("unknown corpus axis: " + axis)
  }
}

///|
fn expand_corpus_sweeps(
  manifest : FunctionalManifest,
  base : Array[FunctionalWorkload],
) -> Array[FunctionalWorkload] raise {
  let rows = manifest.workloads.copy()
  for sweep in manifest.sweeps.unwrap_or([]) {
    guard !sweep.workloads.is_empty() &&
      !sweep.axes.is_empty() &&
      !sweep.shapes.is_empty() else {
      fail("corpus sweeps require nonempty workload, axis and shape selections")
    }
    for id in sweep.workloads {
      guard base.iter().find_first(row => row.id == id) is Some(workload) else {
        fail("unknown base workload: " + id)
      }
      for axis in sweep.axes {
        let sizes = if axis == "shapes" {
          sweep.shape_total_bytes.unwrap_or(corpus_sizes(axis))
        } else if axis == "throughput" {
          sweep.throughput_total_bytes.unwrap_or(corpus_sizes(axis))
        } else {
          corpus_sizes(axis)
        }
        guard !sizes.is_empty() &&
          (
            !["shapes", "throughput"].contains(axis) ||
            sizes.all(size => size > 0L && size <= 536870912L)
          ) else {
          fail(
            "shape and throughput sizes require a nonempty bounded selection",
          )
        }
        for size in sizes {
          for shape in sweep.shapes {
            if axis == "records" {
              let totals = sweep.record_total_bytes.unwrap_or([])
              guard !totals.is_empty() else {
                fail(
                  "record sweeps require explicit independent record_total_bytes",
                )
              }
              guard shape != "mixed-ascii-v1" &&
                shape != "mixed-short-ascii-v1" &&
                shape != "mixed-short-clustered-ascii-v1" &&
                shape != "varied-jsonl-v1" &&
                shape != "nested-jsonl-v1" &&
                shape != "nested-large-jsonl-v1" &&
                shape != "high-entropy" else {
                fail("record sweeps require a fixed-width record shape")
              }
              for total in totals {
                guard total >= size && total <= 536870912L else {
                  fail(
                    "record sweep totals must contain each record and be at most 512 MiB",
                  )
                }
                rows.push({
                  ..workload,
                  id: id +
                  "-records-total" +
                  total.to_string() +
                  "-width" +
                  size.to_string() +
                  "-" +
                  shape,
                  corpus: Some({ bytes: total, record_bytes: size, shape, }),
                })
              }
              continue
            }
            rows.push({
              ..workload,
              id: id + "-" + axis + "-" + size.to_string() + "-" + shape,
              corpus: Some({
                bytes: size,
                record_bytes: if shape == "mixed-ascii-v1" {
                  65537L
                } else if shape == "mixed-short-ascii-v1" {
                  4096L
                } else if shape == "mixed-short-clustered-ascii-v1" {
                  4096L
                } else if shape == "varied-jsonl-v1" {
                  128L
                } else if shape == "nested-jsonl-v1" {
                  4096L
                } else if shape == "nested-large-jsonl-v1" {
                  131072L
                } else if shape == "short-cells-v1" {
                  16L
                } else if shape == "backref-one-v1" {
                  1L
                } else if shape == "backref-window-v1" {
                  32768L
                } else {
                  80L
                },
                shape,
              }),
            })
          }
        }
      }
    }
  }
  let rows = match manifest.seeds {
    None => rows
    Some(seeds) => {
      let seen : Set[Int32] = Set([])
      guard !seeds.is_empty() else { fail("seed selection must not be empty") }
      for seed in seeds {
        guard seed >= 0 && seed <= 65535 && !seen.contains(seed) else {
          fail("seed selection must be distinct and in0..65535")
        }
        seen.add(seed)
      }
      let expanded : Array[FunctionalWorkload] = []
      for row in rows {
        expanded.append(
          seeds.map(seed => {
            ..row,
            id: row.id + "-seed" + seed.to_string(),
            seed: Some(seed),
          }),
        )
      }
      expanded
    }
  }
  let ids : Map[String, Bool] = Map([])
  for row in rows {
    guard !ids.contains(row.id) else {
      fail("duplicate expanded corpus workload: " + row.id)
    }
    ids[row.id] = true
    if row.corpus is Some(spec) {
      let errors = corpus_spec_errors(spec)
      guard errors.is_empty() else { fail(row.id + ": " + errors.join("; ")) }
    }
  }
  rows
}

///|
fn corpus_spec_errors(spec : CorpusSpec) -> Array[String] {
  let errors = []
  if spec.bytes < 0L || spec.record_bytes <= 0L {
    errors.push("corpus needs a nonnegative size and a positive record size")
  }
  if ![
      "ascii", "nul", "invalid-utf8", "no-final-lf", "high-entropy", "repetition",
      "sorted", "reverse", "random", "skew", "long-prefix", "varied-ascii-v1", "mixed-ascii-v1",
      "duplicate-runs-v1", "varied-jsonl-v1", "mixed-short-ascii-v1", "mixed-short-clustered-ascii-v1",
      "sections-ascii-v1", "tabs-spaces-v1", "short-cells-v1", "nested-jsonl-v1",
      "nested-large-jsonl-v1", "backref-one-v1", "backref-window-v1",
    ].contains(spec.shape) {
    errors.push("unknown corpus shape: " + spec.shape)
  }
  if spec.shape == "mixed-ascii-v1" && spec.record_bytes != 65537L {
    errors.push("mixed-ascii-v1 records declare their 65537-byte maximum width")
  }
  if ["mixed-short-ascii-v1", "mixed-short-clustered-ascii-v1"].contains(
      spec.shape,
    ) &&
    spec.record_bytes != 4096L {
    errors.push(
      "mixed-short-ascii-v1 records declare their 4096-byte maximum width",
    )
  }
  if spec.shape == "short-cells-v1" && spec.record_bytes != 16L {
    errors.push(
      "short-cells-v1 requires 16-byte records for a multi-column grid",
    )
  }
  if spec.shape == "backref-one-v1" && spec.record_bytes != 1L {
    errors.push("backref-one-v1 declares its one-byte raw period")
  }
  if spec.shape == "backref-window-v1" && spec.record_bytes != 32768L {
    errors.push("backref-window-v1 declares its 32768-byte raw period")
  }
  if spec.shape == "varied-jsonl-v1" &&
    (spec.record_bytes != 128L || spec.bytes % 128L != 0L) {
    errors.push("varied-jsonl-v1 requires complete 128-byte JSON records")
  }
  if spec.shape == "nested-jsonl-v1" &&
    (spec.record_bytes != 4096L || spec.bytes % 4096L != 0L) {
    errors.push("nested-jsonl-v1 requires complete 4096-byte JSON records")
  }
  if spec.shape == "nested-large-jsonl-v1" &&
    (spec.record_bytes != 131072L || spec.bytes % 131072L != 0L) {
    errors.push(
      "nested-large-jsonl-v1 requires complete 131072-byte JSON records",
    )
  }
  errors
}

///|
fn corpus_evidence(spec : CorpusSpec, variant~ : Int32 = 0) -> Json {
  {
    "shape": spec.shape,
    "variant_seed": variant,
    "bytes": spec.bytes,
    "record_bytes": spec.record_bytes,
    "record_bytes_role": if [
        "mixed-ascii-v1", "mixed-short-ascii-v1", "mixed-short-clustered-ascii-v1",
      ].contains(spec.shape) {
      "maximum"
    } else if ["high-entropy", "backref-one-v1", "backref-window-v1"].contains(
        spec.shape,
      ) {
      "not-applicable-raw-binary"
    } else if ["varied-jsonl-v1", "nested-jsonl-v1", "nested-large-jsonl-v1"].contains(
        spec.shape,
      ) {
      "fixed-complete-jsonl"
    } else {
      "fixed-except-final-partial"
    },
    "record_widths": if spec.shape == "mixed-ascii-v1" {
      Json([7, 29, 89, 1024, 4097, 65537])
    } else if ["mixed-short-ascii-v1", "mixed-short-clustered-ascii-v1"].contains(
        spec.shape,
      ) {
      Json([32, 64, 96, 128, 512, 4096])
    } else {
      Json::null()
    },
    "generator": "deterministic-synthetic; not natural corpus or independent holdout",
    "seed": if spec.shape == "high-entropy" {
      Json(corpus_variant_key(variant))
    } else if [
        "varied-ascii-v1", "mixed-ascii-v1", "mixed-short-ascii-v1", "mixed-short-clustered-ascii-v1",
        "duplicate-runs-v1", "varied-jsonl-v1", "nested-jsonl-v1", "nested-large-jsonl-v1",
        "sections-ascii-v1", "tabs-spaces-v1", "short-cells-v1", "backref-window-v1",
      ].contains(spec.shape) {
      Json(104729)
    } else {
      Json::null()
    },
    "duplicate_run_lengths": if spec.shape == "duplicate-runs-v1" {
      Json([1, 2, 3, 5, 8, 13, 21, 34])
    } else {
      Json::null()
    },
    "complete_cycle_short_record_byte_share": if [
        "mixed-short-ascii-v1", "mixed-short-clustered-ascii-v1",
      ].contains(spec.shape) {
      Json(0.8)
    } else {
      Json::null()
    },
    "complete_cycle_record_counts": if spec.shape == "mixed-short-ascii-v1" {
      Json([64, 64, 64, 64, 2, 1])
    } else if spec.shape == "mixed-short-clustered-ascii-v1" {
      Json([512, 512, 512, 512, 16, 8])
    } else {
      Json::null()
    },
    "distribution_role": if spec.shape == "mixed-ascii-v1" {
      "long-record-stress"
    } else if ["mixed-short-ascii-v1", "mixed-short-clustered-ascii-v1"].contains(
        spec.shape,
      ) {
      "short-row-byte-dominant; explicitly ordered synthetic control"
    } else {
      "declared-synthetic-control"
    },
    "json_depths": if ["nested-jsonl-v1", "nested-large-jsonl-v1"].contains(
        spec.shape,
      ) {
      Json([4, 8, 16, 32])
    } else {
      Json::null()
    },
    "json_payload_encoded_bytes": if [
        "nested-jsonl-v1", "nested-large-jsonl-v1",
      ].contains(spec.shape) {
      Json(
        nested_json_pattern.length() *
        (if spec.shape == "nested-large-jsonl-v1" { 3072 } else { 64 }),
      )
    } else {
      Json::null()
    },
  }
}

///|
fn corpus_duplicate_identity(record : Int64) -> Int64 {
  let runs = [1L, 2L, 3L, 5L, 8L, 13L, 21L, 34L]
  let mut position = record % 87L
  for index in 0..<runs.length() {
    if position < runs[index] {
      return record / 87L * 8L + index.to_int64()
    }
    position -= runs[index]
  }
  abort("duplicate run layout")
}

///|
fn corpus_varied_byte(identity : Int64, position : Int64) -> Byte {
  let rank = (identity * 1103515245L + 12345L) % 1000000007L
  if position < 10L {
    let places = [
      1000000000L, 100000000L, 10000000L, 1000000L, 100000L, 10000L, 1000L, 100L,
      10L, 1L,
    ]
    return ((rank / places[position.to_int()] % 10L).to_int() + 48).to_byte()
  }
  if position < 17L {
    let tag = if identity % 7L == 0L { b"needle:" } else { b"absent:" }
    return tag[(position - 10L).to_int()]
  }
  let alphabet = b"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 _-./:=\t"
  let value = (rank * 31L + position * 2654435761L + 104729L) % 1000000007L
  alphabet[(value % alphabet.length().to_int64()).to_int()]
}

///|
fn corpus_mixed_width(record : Int64) -> Int64 {
  let widths = [7L, 29L, 89L, 1024L, 4097L, 65537L]
  // Each six-record group contains every width, in a rotated order. This
  // exposes exact coverage while varying placement across chunk boundaries.
  widths[((record % 6L + record / 6L) % 6L).to_int()]
}

///|
fn corpus_short_mixed_width(record : Int64) -> Int64 {
  let position = record % 259L
  if position < 256L {
    [32L, 64L, 96L, 128L][((position + record / 259L) % 4L).to_int()]
  } else if position < 258L {
    512L
  } else {
    4096L
  }
}

///|
fn corpus_clustered_mixed_width(record : Int64) -> Int64 {
  let position = record % 2072L
  if position < 8L {
    4096L
  } else if position < 24L {
    512L
  } else {
    [32L, 64L, 96L, 128L][((position - 24L) / 512L).to_int()]
  }
}

///|
fn corpus_json_byte(record : Int64, position : Int64) -> Byte {
  let prefix = b"{\"id\":\""
  if position < prefix.length().to_int64() {
    return prefix[position.to_int()]
  }
  let key_position = position - prefix.length().to_int64()
  if key_position < 10L {
    return corpus_varied_byte(record, key_position)
  }
  let suffixes = [
    b"\",\"name\":\"alpha\",\"active\":true,\"items\":[1,2],\"meta\":{\"key\":\"value\"}}",
    b"\",\"name\":null,\"active\":false,\"items\":[],\"meta\":{\"nested\":{\"n\":7}}}",
    b"\",\"active\":true,\"items\":[{\"name\":\"omega\"},null],\"meta\":{}}", b"\",\"name\":\"escaped\\tvalue\",\"items\":[\"a\",\"b\"],\"meta\":{\"ok\":true}}",
  ]
  let suffix = suffixes[(record % suffixes.length().to_int64()).to_int()]
  let at = key_position - 10L
  if at < suffix.length().to_int64() {
    suffix[at.to_int()]
  } else {
    b' '
  }
}

///|
let nested_json_pattern = b"payload\\tvalue\\\"quoted\\\\text \\u03c0 "

///|
fn corpus_nested_json_byte(
  record : Int64,
  position : Int64,
  large~ : Bool = false,
) -> Byte {
  let prefix = b"{\"id\":\""
  if position < prefix.length().to_int64() {
    return prefix[position.to_int()]
  }
  let key_position = position - prefix.length().to_int64()
  if key_position < 10L {
    return corpus_varied_byte(record, key_position)
  }
  let suffix = if record % 2L == 0L {
    b"\",\"name\":\"large\",\"active\":true,\"items\":[1,2],\"meta\":"
  } else {
    b"\",\"name\":\"large\",\"active\":false,\"items\":[1,2,3],\"meta\":"
  }
  let mut at = key_position - 10L
  if at < suffix.length().to_int64() {
    return suffix[at.to_int()]
  }
  at -= suffix.length().to_int64()
  let depth = [4L, 8L, 16L, 32L][(record % 4L).to_int()]
  if at < depth * 5L {
    return b"{\"n\":"[(at % 5L).to_int()]
  }
  at -= depth * 5L
  if at == 0L {
    return b'"'
  }
  at -= 1L
  let length = nested_json_pattern.length().to_int64() *
    (if large { 3072L } else { 64L })
  if at < length {
    return nested_json_pattern[(at % nested_json_pattern.length().to_int64()).to_int()]
  }
  at -= length
  if at == 0L {
    return b'"'
  }
  at -= 1L
  if at <= depth {
    b'}'
  } else {
    b' '
  }
}

///|
fn corpus_record_byte(spec : CorpusSpec, offset : Int64) -> Byte {
  if spec.shape == "backref-one-v1" {
    return b'a'
  }
  if spec.shape == "backref-window-v1" {
    return benchmark_window_byte(offset)
  }
  let position = offset % spec.record_bytes
  let last = position == spec.record_bytes - 1L || offset == spec.bytes - 1L
  if last && !(spec.shape == "no-final-lf" && offset == spec.bytes - 1L) {
    return if spec.shape == "nul" { b'\x00' } else { b'\n' }
  }
  let pattern = if spec.shape == "invalid-utf8" {
    b"needle:\x80\xff alpha\tbeta "
  } else {
    b"needle:alpha beta 0123456789\t"
  }
  match spec.shape {
    "repetition" => b'a'
    "sorted" | "reverse" | "random" | "skew" | "long-prefix" => {
      let record = offset / spec.record_bytes
      let count = (spec.bytes + spec.record_bytes - 1L) / spec.record_bytes
      let rank = match spec.shape {
        "reverse" => count - 1L - record
        "random" => (record * 1103515245L + 12345L) % count.max(1L)
        "skew" => if record % 10L == 0L { record } else { 0L }
        _ => record
      }
      // Fixed decimal keys retain bytewise sorted/reverse order. Long-prefix
      // keys move to the end of each record instead of varying its prefix.
      let key_position = if spec.shape == "long-prefix" {
        position - (spec.record_bytes - 12L).max(0L)
      } else {
        position
      }
      if key_position >= 0L && key_position < 10L {
        let places = [
          1000000000L, 100000000L, 10000000L, 1000000L, 100000L, 10000L, 1000L, 100L,
          10L, 1L,
        ]
        ((rank / places[key_position.to_int()] % 10L).to_int() + 48).to_byte()
      } else if spec.shape == "long-prefix" {
        b'a'
      } else {
        pattern[((position - 10L).max(0L) % pattern.length().to_int64()).to_int()]
      }
    }
    _ => pattern[(position % pattern.length().to_int64()).to_int()]
  }
}

///|
// One deterministic input per row is shared read-only by both independent
// fixtures. No input, record or output-sized Bytes allocation is needed.
async fn write_corpus(
  path : String,
  spec : CorpusSpec,
  seed~ : Int32 = 0,
) -> Unit {
  let errors = corpus_spec_errors(spec)
  guard errors.is_empty() else { fail(errors.join("; ")) }
  guard seed >= 0 && seed <= 65535 else {
    fail("corpus seed must be in0..65535")
  }
  guard seed == 0 || corpus_supports_variants(spec.shape) else {
    fail("shape has no declared seed variation: " + spec.shape)
  }
  let output = @fs.create(path)
  defer output.close()
  let random = @random.Rand::chacha8(seed=corpus_variant_key(seed))
  let identity_offset = seed.to_int64() * 104729L
  let mut word = 0UL
  let mut left = 0
  let mut offset = 0L
  let varied = [
    "varied-ascii-v1", "mixed-ascii-v1", "mixed-short-ascii-v1", "mixed-short-clustered-ascii-v1",
    "duplicate-runs-v1", "varied-jsonl-v1", "nested-jsonl-v1", "nested-large-jsonl-v1",
    "sections-ascii-v1", "tabs-spaces-v1", "short-cells-v1",
  ].contains(spec.shape)
  let mut record = 0L
  let mut column = 0L
  let mut width = if spec.shape == "mixed-ascii-v1" {
    corpus_mixed_width(0L)
  } else if spec.shape == "mixed-short-ascii-v1" {
    corpus_short_mixed_width(0L)
  } else if spec.shape == "mixed-short-clustered-ascii-v1" {
    corpus_clustered_mixed_width(0L)
  } else {
    spec.record_bytes
  }
  while offset < spec.bytes {
    let length = (spec.bytes - offset).min(65536L).to_int()
    let chunk = Bytes::makei(length, index => {
      if spec.shape == "high-entropy" {
        if left == 0 {
          word = random.uint64()
          left = 8
        }
        let byte = word.to_byte()
        word = word >> 8
        left -= 1
        byte
      } else if varied {
        let last = column == width - 1L ||
          offset + index.to_int64() == spec.bytes - 1L
        let byte = if last {
          b'\n'
        } else if spec.shape == "varied-jsonl-v1" {
          corpus_json_byte(record + identity_offset, column)
        } else if spec.shape == "nested-jsonl-v1" {
          corpus_nested_json_byte(record + identity_offset, column)
        } else if spec.shape == "nested-large-jsonl-v1" {
          corpus_nested_json_byte(record + identity_offset, column, large=true)
        } else if spec.shape == "sections-ascii-v1" &&
          record % 4096L == 0L &&
          column < 8L {
          b"SECTION "[column.to_int()]
        } else if spec.shape == "tabs-spaces-v1" && column < 18L {
          b"alpha        beta\t"[column.to_int()]
        } else {
          corpus_varied_byte(
            if spec.shape == "duplicate-runs-v1" {
              corpus_duplicate_identity(record) + identity_offset
            } else {
              record + identity_offset
            },
            column,
          )
        }
        if last {
          record += 1L
          column = 0L
          if spec.shape == "mixed-ascii-v1" {
            width = corpus_mixed_width(record)
          } else if spec.shape == "mixed-short-ascii-v1" {
            width = corpus_short_mixed_width(record)
          } else if spec.shape == "mixed-short-clustered-ascii-v1" {
            width = corpus_clustered_mixed_width(record)
          }
        } else {
          column += 1L
        }
        byte
      } else {
        corpus_record_byte(spec, offset + index.to_int64())
      }
    })
    output.write(chunk)
    offset += length.to_int64()
  }
}

///|
fn corpus_fixture(
  fixture : @testkit.Case,
  spec : CorpusSpec,
) -> @testkit.Case raise {
  guard fixture.files.is_empty() else {
    fail("scaled stdin recipe needs a fixture without original files")
  }
  let errors = corpus_spec_errors(spec)
  guard errors.is_empty() else { fail(errors.join("; ")) }
  guard fixture.command != "jq" ||
    ["varied-jsonl-v1", "nested-jsonl-v1", "nested-large-jsonl-v1"].contains(
      spec.shape,
    ) else {
    fail("scaled jq requires a complete valid JSON corpus shape")
  }
  let status = if fixture.command == "grep" || fixture.command == "rg" {
    // The functional grep recipe searches for `needle`. Unknown distributions
    // need their own recipe rather than inheriting a successful tiny example.
    guard fixture.args == ["needle"] ||
      fixture.args == ["-F", "-c", "needle"] ||
      fixture.args == ["-E", "-c", "[0-9]+.*needle"] ||
      fixture.args == ["-E", "-n", "[0-9]+.*needle"] ||
      fixture.args == ["-F", "-c", "needle", "-"] ||
      fixture.args == ["-c", "[0-9]+.*needle", "-"] ||
      fixture.args == ["-n", "[0-9]+.*needle", "-"] else {
      fail("scaled grep needs the registered needle recipe")
    }
    if fixture.args.contains("[0-9]+.*needle") {
      guard [
        "varied-ascii-v1", "mixed-short-ascii-v1", "mixed-short-clustered-ascii-v1",
        "duplicate-runs-v1", "sections-ascii-v1",
      ].contains(spec.shape) else {
        fail(
          "regex benchmark requires a declared digit-leading marker distribution",
        )
      }
    }
    let first_end : Int64? = match spec.shape {
      "ascii" | "nul" | "invalid-utf8" =>
        if spec.record_bytes >= 7L {
          Some(7L)
        } else {
          None
        }
      "no-final-lf" =>
        if spec.record_bytes >= 7L {
          Some(6L)
        } else if spec.record_bytes == 6L &&
          spec.bytes >= 6L &&
          spec.bytes % 6L == 0L {
          Some(spec.bytes)
        } else {
          None
        }
      "varied-ascii-v1"
      | "duplicate-runs-v1"
      | "mixed-short-ascii-v1"
      | "mixed-short-clustered-ascii-v1"
      | "sections-ascii-v1" =>
        if spec.record_bytes >= 17L {
          Some(17L)
        } else {
          None
        }
      "mixed-ascii-v1" => Some(70829L)
      "repetition" => None
      _ => fail("scaled grep shape needs an explicit expected match recipe")
    }
    if first_end is Some(end) && spec.bytes >= end {
      0
    } else {
      1
    }
  } else {
    fixture.expected_status
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
    // The changed payload uses the bounded pair/source relation, not the
    // frozen small Case's literal stdout assertion.
    comparison: Some("exact"),
    expected_files: None,
    expected_status: status,
  }
}

///|
priv struct PreparedCorpus {
  source : String
  input : String
}

///|
async fn corpus_observer(
  program : String,
  args : Array[String],
  input : String,
  output : String,
  environment : Map[String, String],
  timeout_ms : Int32,
  receipt_prefix? : String,
) -> Unit {
  let invocation : BenchmarkInvocation = {
    program,
    args,
    stdin_path: input,
    cwd: @path.Path(output).dirname().to_string(),
    environment,
  }
  // This fixed upstream observer is explicitly outside the candidate timing.
  let receipt = receipt_prefix.unwrap_or(output)
  write_json(receipt + ".invocation.json", ToJson::to_json(invocation))
  let observed = measure_invocation(
    invocation,
    output,
    receipt + ".stderr",
    timeout_ms,
  )
  write_json(receipt + ".observation.json", ToJson::to_json(observed))
  guard observed.status == Some(0) &&
    !observed.timed_out &&
    observed.error is None &&
    finite_positive(observed.elapsed_us) &&
    @fs.file_size(receipt + ".stderr") == 0L else {
    fail("fixed native gzip observation failed: " + output)
  }
}

///|
async fn prepare_row_corpus(
  workload : FunctionalWorkload,
  directory : String,
  oracle : String,
  environment : Map[String, String],
  timeout_ms : Int32,
  completed : Map[String, Bool],
) -> PreparedCorpus? {
  guard workload.corpus is Some(spec) else { return None }
  let errors = corpus_spec_errors(spec)
  guard errors.is_empty() else { fail(errors.join("; ")) }
  let key = spec.bytes.to_string() +
    "-" +
    spec.record_bytes.to_string() +
    "-" +
    spec.shape +
    "-seed" +
    workload.seed.unwrap_or(0).to_string()
  let source = @path.Path(directory)
    .dirname()
    .join(Path("corpora/" + key + ".bin"))
    .to_string()
  if !completed.contains(source) {
    write_corpus(source, spec, seed=workload.seed.unwrap_or(0))
    completed[source] = true
  }
  let input = if workload.command == "gunzip" || workload.command == "zcat" {
    let mode = benchmark_gzip_input_mode(workload.recipe)
    let encoded = source + "-" + mode + ".gz"
    if !completed.contains(encoded) {
      prepare_benchmark_gzip_input(
        mode, source, encoded, oracle, environment, timeout_ms,
      )
      completed[encoded] = true
    }
    encoded
  } else {
    source
  }
  Some({ source, input, })
}
