///|
fn natural_test_workload(source : NaturalSource) -> FunctionalWorkload raise {
  @json.from_json({
    "id": "natural",
    "command": "cat",
    "reference_behavior_id": "case:cat",
    "recipe": "real-input",
    "source": Json(source),
  })
}

///|
test "natural source identities reject ambiguous inputs" {
  let source : NaturalSource = {
    path: "original.bin",
    sha256: @testkit.sha256_bytes(b"original"),
  }
  assert_eq(natural_source_errors(source), [])
  for
    invalid in [
      { ..source, path: "../outside", },
      { ..source, path: "/absolute", },
      { ..source, path: "nested/../outside", },
      { ..source, sha256: "", },
      { ..source, sha256: "a".repeat(63), },
      { ..source, sha256: "A".repeat(64), },
    ] {
    assert_false(natural_source_errors(invalid).is_empty())
  }
  assert_true(natural_path_within("/inputs", "/inputs/file"))
  assert_false(natural_path_within("/inputs", "/inputs-copy/file"))
  assert_false(natural_path_within("/inputs", "/inputs"))
}

///|
async test "benchmark file freezing checks bounded copies and preserves measured bytes" {
  let root = @fs.tmpdir(prefix="cmd-natural-freeze-")
  defer @fs.rmdir(root, recursive=true)
  let input = root + "/source"
  let frozen = root + "/frozen"
  let bytes = Bytes::makei(131075, i => (i % 251).to_byte())
  @fs.write_file(input, bytes)
  let wanted = @testkit.sha256_bytes(bytes)
  assert_eq(benchmark_file_sha256(input), wanted)
  assert_eq(freeze_benchmark_file(input, frozen, expected=wanted), wanted)
  assert_eq(@fs.read_file(frozen).binary(), bytes)
  @fs.write_file(input, b"changed")
  assert_eq(benchmark_file_sha256(frozen), wanted)
  let accepted = try {
    ignore(freeze_benchmark_file(input, frozen))
    true
  } catch {
    _ => false
  }
  assert_false(accepted)
  assert_eq(benchmark_file_sha256(frozen), wanted)
  let bad_target = root + "/wrong-digest"
  let accepted = try {
    ignore(freeze_benchmark_file(input, bad_target, expected=wanted))
    true
  } catch {
    _ => false
  }
  assert_false(accepted)
  assert_false(@fs.exists(bad_target))
  assert_false(@fs.exists(bad_target + ".pending"))
}

///|
async test "natural workload preparation rejects missing changed truncated and escaped inputs" {
  let root = @fs.tmpdir(prefix="cmd-natural-source-")
  defer @fs.rmdir(root, recursive=true)
  let corpus = root + "/inputs"
  @fs.mkdir(corpus)
  let reports = root + "/reports"
  @fs.mkdir(reports)
  @fs.mkdir(reports + "/corpora")
  let source : NaturalSource = {
    path: "original",
    sha256: @testkit.sha256_bytes(b"original\x00\xff\n"),
  }
  let options = Map([("--corpus-root", corpus)])
  let workload = natural_test_workload(source)
  for
    (name, content) in [
      ("missing", None),
      ("changed", Some(b"altered")),
      ("truncated", Some(b"original")),
    ] {
    let row = reports + "/" + name
    @fs.mkdir(row)
    if content is Some(bytes) {
      @fs.write_file(corpus + "/original", bytes)
    }
    let accepted = try {
      ignore(
        prepare_natural_source(
          workload,
          row,
          options,
          "unused",
          Map([]),
          1000,
          Map([]),
        ),
      )
      true
    } catch {
      _ => false
    }
    assert_false(accepted, msg=name)
    assert_eq(@fs.readdir(reports + "/corpora"), [])
  }
  @fs.write_file(corpus + "/original", b"original\x00\xff\n")
  let row = reports + "/complete"
  @fs.mkdir(row)
  let prepared = prepare_natural_source(
    workload,
    row,
    options,
    "unused",
    Map([]),
    1000,
    Map([]),
  ).unwrap()
  assert_eq(@fs.read_file(prepared.input).binary(), b"original\x00\xff\n")
  assert_eq(prepared.input, prepared.source)
  let evidence = @json.parse(@fs.read_file(row + "/natural-source.json").text())
  assert_true(
    evidence
    is {
      "blind_holdout": False,
      "transformation": String(
        "none; complete original file copied byte-for-byte"
      ),
      ..
    },
  )
  let accepted = try {
    ignore(
      prepare_natural_source(
        workload,
        row,
        Map([]),
        "unused",
        Map([]),
        1000,
        Map([]),
      ),
    )
    true
  } catch {
    _ => false
  }
  assert_false(accepted)
  if @testkit.host_platform() != "windows" {
    @fs.write_file(root + "/outside", b"original\x00\xff\n")
    @fs.symlink(target=root + "/outside", corpus + "/escaped")
    let escaped = natural_test_workload({ ..source, path: "escaped", })
    let accepted = try {
      ignore(
        prepare_natural_source(
          escaped,
          row,
          options,
          "unused",
          Map([]),
          1000,
          Map([]),
        ),
      )
      true
    } catch {
      _ => false
    }
    assert_false(accepted)
  }
}
