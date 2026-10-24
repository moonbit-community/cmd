///|
async test "benchmark corpus generation preserves chunk boundaries and deterministic binary bytes" {
  let directory = @fs.tmpdir(prefix="cmd-corpus-")
  defer @fs.rmdir(directory, recursive=true)
  let spec : CorpusSpec = {
    bytes: 131075L,
    record_bytes: 80L,
    shape: "high-entropy",
  }
  write_corpus(directory + "/a", spec)
  write_corpus(directory + "/b", spec)
  assert_eq(@fs.file_size(directory + "/a"), spec.bytes)
  assert_true(files_equal(directory + "/a", directory + "/b"))
  let file = @fs.open(directory + "/b", mode=WriteOnly)
  let source = @fs.open(directory + "/a", mode=ReadOnly)
  let tail = source.read_exactly_at(1, position=spec.bytes - 1L)
  source.close()
  file.write_at(
    Bytes::make(1, (tail[0].to_int() ^ 1).to_byte()),
    position=spec.bytes - 1L,
  )
  file.close()
  assert_false(files_equal(directory + "/a", directory + "/b"))
  write_corpus(directory + "/empty", { ..spec, bytes: 0L, })
  assert_eq(@fs.file_size(directory + "/empty"), 0L)
}

///|
async test "benchmark long records retain exact delimiters invalid bytes and final record" {
  let directory = @fs.tmpdir(prefix="cmd-records-")
  defer @fs.rmdir(directory, recursive=true)
  let spec : CorpusSpec = {
    bytes: 131074L,
    record_bytes: 65537L,
    shape: "invalid-utf8",
  }
  let path = directory + "/records"
  write_corpus(path, spec)
  let file = @fs.open(path, mode=ReadOnly)
  assert_eq(file.read_exactly_at(2, position=7L), b"\x80\xff")
  assert_eq(file.read_exactly_at(2, position=65536L), b"\nn")
  assert_eq(file.read_exactly_at(1, position=131073L), b"\n")
  file.close()
  write_corpus(path, { ..spec, shape: "no-final-lf", })
  let file = @fs.open(path, mode=ReadOnly)
  assert_eq(file.read_exactly_at(1, position=65536L), b"\n")
  assert_true(file.read_exactly_at(1, position=131073L) != b"\n")
  file.close()
  write_corpus(path, { ..spec, shape: "nul", })
  let file = @fs.open(path, mode=ReadOnly)
  assert_eq(file.read_exactly_at(1, position=65536L), b"\x00")
  file.close()
}

///|
async test "benchmark corpus sweeps expand fixed sizes without losing behavior ownership" {
  let base : FunctionalWorkload = @json.from_json({
    "id": "cat",
    "command": "cat",
    "reference_behavior_id": "case:compat-stdin-cat",
    "case_id": "compat-stdin-cat",
  })
  let manifest : FunctionalManifest = @json.from_json({
    "schema": 2,
    "published_manifest": "published",
    "case_corpus": "cases",
    "workloads": [],
    "sweeps": [
      {
        "workloads": ["cat"],
        "axes": ["startup", "throughput", "records"],
        "shapes": ["ascii"],
      },
    ],
  })
  let rows = expand_corpus_sweeps(manifest, [base])
  assert_eq(rows.length(), 11)
  assert_eq(rows.map(row => row.corpus.unwrap().bytes), [
    0L, 1L, 4096L, 8388608L, 67108864L, 536870912L, 1024L, 65536L, 1048576L, 8388608L,
    67108864L,
  ])
  assert_true(
    rows.all(row => row.reference_behavior_id == base.reference_behavior_id),
  )
  assert_true(
    rows[6:]
    .iter()
    .all(row => row.corpus.unwrap().bytes == row.corpus.unwrap().record_bytes),
  )
  assert_false(
    corpus_spec_errors({ bytes: -1L, record_bytes: 0L, shape: "ascii", }).is_empty(),
  )
  let absent = Some(expand_corpus_sweeps(manifest, [])) catch { _ => None }
  assert_true(absent is None)
  let manifest : FunctionalManifest = @json.from_json(
    @json.parse(@fs.read_file("benchmark/scaled.json").text()),
  )
  let base : FunctionalManifest = @json.from_json(
    @json.parse(@fs.read_file("benchmark/functional.json").text()),
  )
  let expanded = expand_corpus_sweeps(manifest, base.workloads)
  assert_eq(expanded.length(), 292)
  let unique : Map[String, Bool] = Map([])
  let cases = @testkit.load_cases("../" + manifest.case_corpus)
  for row in expanded {
    assert_false(unique.contains(row.id))
    unique[row.id] = true
    let original = functional_fixture(row, cases, "helper")
    let fixture = corpus_fixture(original, row.corpus.unwrap())
    assert_eq(@testkit.contract_errors(fixture), [])
  }
}

///|
async test "benchmark scaled output replaces small literals with bounded exact comparison" {
  let directory = @fs.tmpdir(prefix="cmd-scaled-output-")
  defer @fs.rmdir(directory, recursive=true)
  let original : @testkit.Case = @json.from_json({
    "id": "small",
    "command": "gunzip",
    "args": [],
    "files": [],
    "environment": {},
    "normalizations": [],
    "expected_status": 0,
    "comparison": "contract",
    "expected_stdout_text": "small",
    "expected_stderr_text": "",
  })
  let spec : CorpusSpec = {
    bytes: 131075L,
    record_bytes: 80L,
    shape: "high-entropy",
  }
  let fixture = corpus_fixture(original, spec)
  assert_eq(
    @testkit.check_contract(
      fixture,
      { status: 0, stdout: b"", stderr: b"", },
      directory,
    ),
    [],
  )
  let workload : FunctionalWorkload = @json.from_json({
    "id": "scaled",
    "command": "gunzip",
    "reference_behavior_id": "case:small",
  })
  let sides = []
  for name in ["left", "right"] {
    let root = directory + "/" + name
    @fs.mkdir(root)
    let stdout = directory + "/" + name + ".stdout"
    let stderr = directory + "/" + name + ".stderr"
    write_corpus(stdout, spec)
    @fs.write_file(stderr, b"")
    sides.push(FunctionalSide::{
      root,
      stdout,
      stderr,
      errors: [],
      observation: {
        elapsed_us: 1.0,
        status: Some(0),
        timed_out: false,
        error: None,
      },
    })
  }
  assert_eq(compare_functional_sides(workload, fixture, sides[0], sides[1]), [])
  let file = @fs.open(sides[1].stdout, mode=WriteOnly)
  let before = @fs.open(sides[0].stdout, mode=ReadOnly)
  let tail = before.read_exactly_at(1, position=spec.bytes - 1L)
  before.close()
  file.write_at(
    Bytes::make(1, (tail[0].to_int() ^ 1).to_byte()),
    position=spec.bytes - 1L,
  )
  file.close()
  assert_eq(compare_functional_sides(workload, fixture, sides[0], sides[1]), [
    "stdout bytes differ",
  ])
}
