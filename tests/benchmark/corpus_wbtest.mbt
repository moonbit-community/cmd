// Synthetic fixtures below test observer and fixture semantics only. They are
// excluded from the real-source timing inventory and its coverage claims.

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
        "record_total_bytes": ["67108864", "134217728"],
      },
    ],
  })
  let rows = expand_corpus_sweeps(manifest, [base])
  assert_eq(rows.length(), 16)
  assert_eq(rows.map(row => row.corpus.unwrap().bytes), [
    0L, 1L, 4096L, 8388608L, 67108864L, 536870912L, 67108864L, 134217728L, 67108864L,
    134217728L, 67108864L, 134217728L, 67108864L, 134217728L, 67108864L, 134217728L,
  ])
  assert_true(
    rows.all(row => row.reference_behavior_id == base.reference_behavior_id),
  )
  for index in 0..<5 {
    let a = rows[6 + index * 2].corpus.unwrap()
    let b = rows[7 + index * 2].corpus.unwrap()
    assert_eq(a.record_bytes, corpus_sizes("records")[index])
    assert_eq(a.record_bytes, b.record_bytes)
    assert_eq(a.bytes, 67108864L)
    assert_eq(b.bytes, 134217728L)
  }
  assert_false(
    corpus_spec_errors({ bytes: -1L, record_bytes: 0L, shape: "ascii", }).is_empty(),
  )
  let absent = Some(expand_corpus_sweeps(manifest, [])) catch { _ => None }
  assert_true(absent is None)
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

///|
async test "varied text retains distinct records sparse markers exact sizes and reproducibility" {
  let directory = @fs.tmpdir(prefix="cmd-varied-")
  defer @fs.rmdir(directory, recursive=true)
  let spec : CorpusSpec = {
    bytes: 131120L,
    record_bytes: 80L,
    shape: "varied-ascii-v1",
  }
  write_corpus(directory + "/a", spec)
  write_corpus(directory + "/b", spec)
  assert_eq(@fs.file_size(directory + "/a"), 131120L)
  assert_true(files_equal(directory + "/a", directory + "/b"))
  let records = @fs.read_file(directory + "/a")
    .text()
    .split("\n")
    .filter(line => !line.is_empty())
    .map(line => line.to_owned())
    .to_array()
  assert_eq(records.length(), 1639)
  let distinct : Map[String, Bool] = Map([])
  let mut hits = 0
  for record in records {
    assert_eq(record.length(), 79)
    assert_false(distinct.contains(record))
    distinct[record] = true
    if record.contains("needle") {
      hits += 1
    }
  }
  assert_eq(hits, 235)
  assert_true(records[0].contains("needle"))
  assert_false(records[1].contains("needle"))
  assert_eq(corpus_evidence(spec), {
    "shape": "varied-ascii-v1",
    "variant_seed": 0,
    "bytes": "131120",
    "record_bytes": "80",
    "record_bytes_role": "fixed-except-final-partial",
    "record_widths": Json::null(),
    "generator": "deterministic-synthetic; not natural corpus or independent holdout",
    "seed": 104729,
    "duplicate_run_lengths": Json::null(),
    "complete_cycle_short_record_byte_share": Json::null(),
    "complete_cycle_record_counts": Json::null(),
    "distribution_role": "declared-synthetic-control",
    "json_depths": Json::null(),
    "json_payload_encoded_bytes": Json::null(),
  })
}

///|
async test "mixed records retain every declared width across physical chunks" {
  let directory = @fs.tmpdir(prefix="cmd-mixed-")
  defer @fs.rmdir(directory, recursive=true)
  let spec : CorpusSpec = {
    bytes: 212349L,
    record_bytes: 65537L,
    shape: "mixed-ascii-v1",
  }
  write_corpus(directory + "/mixed", spec)
  assert_eq(@fs.file_size(directory + "/mixed"), spec.bytes)
  let records = @fs.read_file(directory + "/mixed")
    .text()
    .split("\n")
    .filter(line => !line.is_empty())
    .to_array()
  assert_eq(records.length(), 18)
  let widths : Map[Int32, Int32] = Map([])
  for index in 0..<records.length() {
    let width = records[index].length() + 1
    assert_eq(width.to_int64(), corpus_mixed_width(index.to_int64()))
    widths[width] = widths.get(width).unwrap_or(0) + 1
  }
  for width in [7, 29, 89, 1024, 4097, 65537] {
    assert_eq(widths[width], 3)
  }
  assert_true(records[7].contains("needle"))
  assert_false(corpus_spec_errors({ ..spec, record_bytes: 80L, }).is_empty())
}

///|
async test "duplicate runs include singleton and varied adjacent run lengths" {
  let directory = @fs.tmpdir(prefix="cmd-duplicates-")
  defer @fs.rmdir(directory, recursive=true)
  let spec : CorpusSpec = {
    bytes: 6960L,
    record_bytes: 80L,
    shape: "duplicate-runs-v1",
  }
  write_corpus(directory + "/runs", spec)
  let records = @fs.read_file(directory + "/runs")
    .text()
    .split("\n")
    .filter(line => !line.is_empty())
    .map(line => line.to_owned())
    .to_array()
  assert_eq(records.length(), 87)
  let mut at = 0
  let distinct : Map[String, Bool] = Map([])
  for count in [1, 2, 3, 5, 8, 13, 21, 34] {
    let record = records[at]
    assert_false(distinct.contains(record))
    distinct[record] = true
    for index in at..<(at + count) {
      assert_eq(records[index], record)
    }
    at += count
  }
  assert_eq(at, records.length())
}

///|
async test "varied JSON records parse independently and invalid lengths preserve existing files" {
  let directory = @fs.tmpdir(prefix="cmd-jsonl-")
  defer @fs.rmdir(directory, recursive=true)
  let spec : CorpusSpec = {
    bytes: 2048L,
    record_bytes: 128L,
    shape: "varied-jsonl-v1",
  }
  let path = directory + "/jsonl"
  write_corpus(path, spec)
  let records = @fs.read_file(path)
    .text()
    .split("\n")
    .filter(line => !line.is_empty())
    .to_array()
  assert_eq(records.length(), 16)
  let parsed : Array[Json] = []
  for record in records {
    assert_eq(record.length(), 127)
    parsed.push(@json.parse(record))
  }
  assert_true(
    parsed[0]
    is {
      "name": String("alpha"),
      "active": True,
      "items": Array(_),
      "meta": Object(_),
      ..
    },
  )
  assert_true(parsed[1] is { "name": Null, "active": False, .. })
  assert_true(parsed[2] is Object(object) && !object.contains("name"))
  assert_true(parsed[3] is { "name": String("escaped\tvalue"), .. })
  assert_true(parsed[0] != parsed[4])
  let original = @fs.read_file(path).binary()
  for bytes in [127L, 129L, 2047L] {
    let outcome = Some(write_corpus(path, { ..spec, bytes, })) catch {
      _ => None
    }
    assert_true(outcome is None)
    assert_eq(@fs.read_file(path).binary(), original)
  }
}

///|
async test "scaled grep status follows marker location and rejects an unknown recipe" {
  let directory = @fs.tmpdir(prefix="cmd-grep-corpus-")
  defer @fs.rmdir(directory, recursive=true)
  let fixture : @testkit.Case = @json.from_json({
    "id": "grep",
    "command": "grep",
    "args": ["needle"],
    "files": [],
    "environment": {},
    "normalizations": [],
    "expected_status": 0,
  })
  for
    (shape, width, absent_bytes, present_bytes) in [
      ("ascii", 80L, 6L, 7L),
      ("no-final-lf", 80L, 5L, 6L),
      ("varied-ascii-v1", 80L, 16L, 17L),
      ("duplicate-runs-v1", 80L, 16L, 17L),
      ("mixed-ascii-v1", 65537L, 70828L, 70829L),
    ] {
    let spec : CorpusSpec = { bytes: absent_bytes, record_bytes: width, shape, }
    assert_eq(corpus_fixture(fixture, spec).expected_status, 1)
    assert_eq(
      corpus_fixture(fixture, { ..spec, bytes: present_bytes, }).expected_status,
      0,
    )
    write_corpus(directory + "/absent", spec)
    write_corpus(directory + "/present", { ..spec, bytes: present_bytes, })
    assert_false(
      @testkit.contains_bytes(
        @fs.read_file(directory + "/absent").binary(),
        "needle",
      ),
    )
    assert_true(
      @testkit.contains_bytes(
        @fs.read_file(directory + "/present").binary(),
        "needle",
      ),
    )
  }
  assert_eq(
    corpus_fixture(fixture, {
      bytes: 4096L,
      record_bytes: 80L,
      shape: "repetition",
    }).expected_status,
    1,
  )
  let invalid = Some(
    corpus_fixture({ ..fixture, args: ["other"], }, {
      bytes: 4096L,
      record_bytes: 80L,
      shape: "ascii",
    }),
  ) catch {
    _ => None
  }
  assert_true(invalid is None)
  let jq = Some(
    corpus_fixture({ ..fixture, command: "jq", }, {
      bytes: 4096L,
      record_bytes: 80L,
      shape: "ascii",
    }),
  ) catch {
    _ => None
  }
  assert_true(jq is None)
}

///|
test "record sweeps reject omitted empty duplicated or undersized dimensions" {
  let base : FunctionalWorkload = @json.from_json({
    "id": "cat",
    "command": "cat",
    "reference_behavior_id": "case:cat",
    "case_id": "cat",
  })
  let manifest : FunctionalManifest = @json.from_json({
    "schema": 2,
    "published_manifest": "published",
    "case_corpus": "cases",
    "workloads": [],
    "sweeps": [
      { "workloads": ["cat"], "axes": ["records"], "shapes": ["ascii"] },
    ],
  })
  for totals in [None, Some([]), Some([67108864L, 67108864L]), Some([1024L])] {
    let sweep = { ..manifest.sweeps.unwrap()[0], record_total_bytes: totals, }
    let outcome = Some(
      expand_corpus_sweeps({ ..manifest, sweeps: Some([sweep]), }, [base]),
    ) catch {
      _ => None
    }
    assert_true(outcome is None)
  }
}
