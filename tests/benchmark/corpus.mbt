///|
priv struct CorpusSpec {
  bytes : Int64
  record_bytes : Int64
  shape : String
} derive(FromJson, ToJson)

///|
let corpus_seed : Bytes = b"0123456789abcdef0123456789abcdef"

///|
priv struct CorpusSweep {
  workloads : Array[String]
  axes : Array[String]
  shapes : Array[String]
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
    for id in sweep.workloads {
      guard base.iter().find_first(row => row.id == id) is Some(workload) else {
        fail("unknown base workload: " + id)
      }
      for axis in sweep.axes {
        for size in corpus_sizes(axis) {
          for shape in sweep.shapes {
            rows.push({
              ..workload,
              id: id + "-" + axis + "-" + size.to_string() + "-" + shape,
              corpus: Some({
                bytes: size,
                record_bytes: if axis == "records" {
                  size
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
      "sorted", "reverse", "random", "skew", "long-prefix",
    ].contains(spec.shape) {
    errors.push("unknown corpus shape: " + spec.shape)
  }
  errors
}

///|
fn corpus_record_byte(spec : CorpusSpec, offset : Int64) -> Byte {
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
async fn write_corpus(path : String, spec : CorpusSpec) -> Unit {
  let errors = corpus_spec_errors(spec)
  guard errors.is_empty() else { fail(errors.join("; ")) }
  let output = @fs.create(path)
  defer output.close()
  let random = @random.Rand::chacha8(seed=corpus_seed)
  let mut word = 0UL
  let mut left = 0
  let mut offset = 0L
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
  let status = if fixture.command == "grep" && spec.bytes < 6L {
    1
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
) -> Unit {
  let invocation : BenchmarkInvocation = {
    program,
    args,
    stdin_path: input,
    cwd: @path.Path(output).dirname().to_string(),
    environment,
  }
  // This fixed upstream observer is explicitly outside the candidate timing.
  write_json(output + ".invocation.json", ToJson::to_json(invocation))
  let observed = measure_invocation(
    invocation,
    output,
    output + ".stderr",
    timeout_ms,
  )
  write_json(output + ".observation.json", ToJson::to_json(observed))
  guard observed.status == Some(0) &&
    !observed.timed_out &&
    observed.error is None &&
    @fs.file_size(output + ".stderr") == 0L else {
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
    spec.shape
  let source = @path.Path(directory)
    .dirname()
    .join(Path("corpora/" + key + ".bin"))
    .to_string()
  if !completed.contains(source) {
    write_corpus(source, spec)
    completed[source] = true
  }
  let input = if workload.command == "gunzip" || workload.command == "zcat" {
    let encoded = source + ".gz"
    if !completed.contains(encoded) {
      corpus_observer(
        oracle + "/gzip",
        ["-n", "-c"],
        source,
        encoded,
        environment,
        timeout_ms,
      )
      completed[encoded] = true
    }
    encoded
  } else {
    source
  }
  Some({ source, input, })
}
