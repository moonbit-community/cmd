///|
async test "independent seeds change actual bytes while retaining valid complete data" {
  let root = @fs.tmpdir(prefix="cmd-variant-evidence-")
  defer @fs.rmdir(root, recursive=true)
  for
    (shape, width) in [
      ("high-entropy", 80L),
      ("varied-ascii-v1", 80L),
      ("mixed-short-ascii-v1", 4096L),
      ("varied-jsonl-v1", 128L),
      ("nested-large-jsonl-v1", 131072L),
    ] {
    let spec : CorpusSpec = { bytes: 262144L, record_bytes: width, shape, }
    write_corpus(root + "/a", spec, seed=17)
    write_corpus(root + "/b", spec, seed=17)
    write_corpus(root + "/c", spec, seed=239)
    assert_true(files_equal(root + "/a", root + "/b"), msg=shape)
    assert_false(files_equal(root + "/a", root + "/c"), msg=shape)
    assert_eq(@fs.file_size(root + "/a"), spec.bytes)
    if shape == "varied-jsonl-v1" || shape == "nested-large-jsonl-v1" {
      for line in @fs.read_file(root + "/a").text().split("\n") {
        if !line.is_empty() {
          ignore(@json.parse(line.to_owned()))
        }
      }
    }
  }
  let invalid = try {
    write_corpus(
      root + "/invalid",
      { bytes: 1024L, record_bytes: 80L, shape: "repetition", },
      seed=17,
    )
    true
  } catch {
    _ => false
  }
  assert_false(invalid)
  assert_false(@fs.exists(root + "/invalid"))
}

///|
async test "seed sweeps bind unique workload identities and actual named key files" {
  let manifest : FunctionalManifest = @json.from_json({
    "schema": 2,
    "published_manifest": "unused",
    "case_corpus": "unused",
    "seeds": [17, 239, 4093],
    "workloads": [
      {
        "id": "keys",
        "command": "join",
        "reference_behavior_id": "case:join",
        "recipe": "bench-join-mixed",
        "corpus": {
          "bytes": "1048576",
          "record_bytes": "80",
          "shape": "varied-ascii-v1",
        },
      },
    ],
  })
  let rows = expand_corpus_sweeps(manifest, [])
  assert_eq(rows.length(), 3)
  assert_eq(functional_workload_errors(rows), [])
  let root = @fs.tmpdir(prefix="cmd-variant-keys-")
  defer @fs.rmdir(root, recursive=true)
  @fs.write_file(root + "/budget", Bytes::make(4096, b'x'))
  for row in rows {
    let directory = root + "/" + row.id
    @fs.mkdir(directory)
    prepare_benchmark_recipe(
      row,
      Some({ source: root + "/budget", input: root + "/budget", }),
      directory,
    )
  }
  assert_false(
    files_equal(root + "/keys-seed17/left", root + "/keys-seed239/left"),
  )
  assert_false(
    files_equal(root + "/keys-seed17/right", root + "/keys-seed239/right"),
  )
  for seeds in [[], [17, 17], [-1], [65536]] {
    let accepted = try {
      ignore(expand_corpus_sweeps({ ..manifest, seeds: Some(seeds), }, []))
      true
    } catch {
      _ => false
    }
    assert_false(accepted)
  }
}
