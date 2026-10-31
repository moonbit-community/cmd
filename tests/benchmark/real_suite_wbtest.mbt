///|
fn real_test_replace(
  value : Json,
  key : String,
  replacement : Json,
) -> Json raise {
  guard value is Object(fields) else { fail("expected real-suite test object") }
  let fields = fields.copy()
  fields[key] = replacement
  Json(fields)
}

///|
async fn real_test_registry() -> (Json, Json, Json, Array[FunctionalWorkload]) {
  let manifest = @json.parse(
    @fs.read_file(real_registry_path("tests/benchmark/real.json")).text(),
  )
  let catalog = @json.parse(
    @fs.read_file(
      real_registry_path(real_text(real_field(manifest, "source_catalog"))),
    ).text(),
  )
  let coverage = @json.parse(
    @fs.read_file(
      real_registry_path(real_text(real_field(manifest, "coverage_registry"))),
    ).text(),
  )
  let typed : FunctionalManifest = @json.from_json(manifest)
  assert_eq(real_suite_errors(manifest, catalog, coverage, typed.workloads), [])
  (manifest, catalog, coverage, typed.workloads)
}

///|
async test "real source catalog rejects malformed identities sizes and ambiguous records" {
  let (manifest, catalog, coverage, rows) = real_test_registry()
  let files = real_array(real_field(catalog, "files"))
  assert_true(!files.is_empty())
  for
    (key, value, diagnostic) in [
      ("sha256", Json(""), "lacks sha256"),
      ("path", Json("../escape"), "unsafe or duplicate real source path"),
      ("bytes", Json(-1L), "size is missing or exceeds limit"),
      ("bytes", Json(16777217L), "size is missing or exceeds limit"),
    ] {
    let changed = files.copy()
    changed[0] = real_test_replace(changed[0], key, value)
    let errors = real_suite_errors(
      manifest,
      real_test_replace(catalog, "files", Json(changed)),
      coverage,
      rows,
    )
    assert_true(errors.any(error => error.contains(diagnostic)), msg=key)
  }
  let duplicate = [..files, files[0]]
  assert_true(
    real_suite_errors(
      manifest,
      real_test_replace(catalog, "files", Json(duplicate)),
      coverage,
      rows,
    ).any(error => error.contains("duplicate real source path")),
  )
  let primary = rows[0].source.unwrap().path
  let missing = files.filter(file => real_field(file, "path") != Json(primary))
  assert_true(
    real_suite_errors(
      manifest,
      real_test_replace(catalog, "files", Json(missing)),
      coverage,
      rows,
    ).any(error => error.contains("source is absent or differs")),
  )
}

///|
async test "real timing forbids live base manifests and generated sweep fields" {
  let (manifest, catalog, coverage, rows) = real_test_registry()
  for
    field in [
      "base_manifest", "sweeps", "seeds", "corpus_sweeps", "seed_variants",
    ] {
    assert_true(
      real_suite_errors(
        real_test_replace(manifest, field, Json("unbound-live-definition")),
        catalog,
        coverage,
        rows,
      ).any(error => error.contains("legacy expansion field is retired")),
    )
  }
}

///|
async test "real rows cannot claim fragmented input through the separate slow-output observer" {
  let (manifest, catalog, coverage, rows) = real_test_registry()
  let changed = {
    ..rows[0],
    transport: Some("fragmented-pipe"),
    chunk_bytes: Some(257),
    sink: Some("slow-pipe"),
    sink_chunk_bytes: Some(4096),
    sink_delay_ms: Some(1),
  }
  assert_true(
    real_suite_errors(manifest, catalog, coverage, [changed, ..rows[1:]]).any(error => {
      error.contains(
        "combined input/output pipe observations are not implemented",
      )
    }),
  )
}

///|
async test "real coverage cannot remove a required command together with all its rows" {
  let (manifest, catalog, coverage, rows) = real_test_registry()
  let commands = real_array(real_field(coverage, "commands"))
  let command = real_text(real_field(commands[0], "command"))
  let reduced = commands.filter(spec => {
    real_field(spec, "command") != Json(command)
  })
  let rows = rows.filter(row => row.command != command)
  let errors = real_suite_errors(
    manifest,
    catalog,
    real_test_replace(coverage, "commands", Json(reduced)),
    rows,
  )
  assert_true(errors.any(error => error.contains("43-command scope")))
}

///|
async test "real timing command cannot be relabeled correctness-only to discard all required workloads" {
  let (manifest, catalog, coverage, rows) = real_test_registry()
  let commands = real_array(real_field(coverage, "commands"))
  guard commands
    .iter()
    .find_first(spec => real_field(spec, "disposition") == Json("timing"))
    is Some(original) else {
    fail("current coverage must retain real timing commands")
  }
  let command = real_text(real_field(original, "command"))
  let boundary = real_test_replace(
    real_test_replace(original, "disposition", Json("correctness-only")),
    "reason",
    Json(
      "Attempted scope reduction retains a reason and its real local witnesses",
    ),
  )
  let modified = commands.map(spec => {
    if real_field(spec, "command") == Json(command) {
      boundary
    } else {
      spec
    }
  })
  let errors = real_suite_errors(
    manifest,
    catalog,
    real_test_replace(coverage, "commands", Json(modified)),
    rows.filter(row => row.command != command),
  )
  assert_true(!errors.is_empty())
}

///|
async test "new ID and mode labels cannot manufacture a distinct real invocation" {
  let (manifest, catalog, coverage, rows) = real_test_registry()
  let duplicate = {
    ..rows[0],
    id: rows[0].id + "-different-label",
    mode: Some("different-mode-label"),
  }
  let errors = real_suite_errors(
    manifest,
    catalog,
    coverage,
    [..rows, duplicate],
  )
  assert_true(
    errors.any(error => {
      error.contains("duplicate actual real-source invocation")
    }),
  )
}

///|
async test "real collections reject the same complete source copied to a second distinct target" {
  let (manifest, catalog, coverage, rows) = real_test_registry()
  guard rows.iter().find_first(row => row.inputs.unwrap_or([]).length() > 1)
    is Some(original) else {
    fail("current registry must retain a genuine multi-file collection")
  }
  let inputs = original.inputs.unwrap()
  let repeated : RealInput = {
    source: inputs[0].source,
    target: "tree/disclosure-regression-distinct-source-alias",
  }
  let changed = { ..original, inputs: Some([..inputs, repeated]), }
  let modified = rows.map(row => {
    if row.id == original.id {
      changed
    } else {
      row
    }
  })
  let errors = real_suite_errors(manifest, catalog, coverage, modified)
  assert_true(
    errors.any(error => {
      error.contains("collection repeats the same original source")
    }),
  )
}

///|
async test "actual real source sizes reject missing mismatched negative oversized and ambiguous observations" {
  let (_, catalog, _, rows) = real_test_registry()
  let files = real_array(real_field(catalog, "files"))
  let observed : Map[String, Int64] = Map([])
  for file in files {
    observed[real_text(real_field(file, "path"))] = @json.from_json(
      real_field(file, "bytes"),
    )
  }
  assert_eq(real_actual_source_errors(catalog, rows, observed), [])
  let path = rows[0].source.unwrap().path
  let missing = observed.copy()
  missing.remove(path)
  assert_true(
    real_actual_source_errors(catalog, rows, missing).any(error => {
      error.contains("missing/ambiguous observed genuine source")
    }),
  )
  for wrong in [observed[path] + 1L, -1L, 16777217L] {
    let actual = observed.copy()
    actual[path] = wrong
    assert_true(
      real_actual_source_errors(catalog, rows, actual).any(error => {
        error.contains("source differs from size/budget")
      }),
    )
  }
  guard files.iter().find_first(file => real_field(file, "path") == Json(path))
    is Some(record) else {
    fail("current source record is missing")
  }
  let ambiguous = real_test_replace(catalog, "files", Json([..files, record]))
  assert_true(
    real_actual_source_errors(ambiguous, rows, observed).any(error => {
      error.contains("missing/ambiguous observed genuine source")
    }),
  )
}

///|
async test "actual unique source budget accepts64MiB rejects80MiB and counts repeated use once" {
  let (_, _, _, examples) = real_test_registry()
  let files : Array[Json] = []
  let rows : Array[FunctionalWorkload] = []
  let observed : Map[String, Int64] = Map([])
  for index in 0..<5 {
    let path = "budget/source-" + index.to_string()
    let sha = "0".repeat(63) + index.to_string()
    let source : NaturalSource = { path, sha256: sha, }
    rows.push({
      ..examples[0],
      id: "actual-budget-" + index.to_string(),
      source: Some(source),
      other_source: None,
      inputs: None,
    })
    files.push({ "path": path, "sha256": sha, "bytes": Json(16777216L) })
    observed[path] = 16777216L
  }
  let catalog : Json = { "schema": 1, "files": Json(files) }
  assert_eq(real_actual_source_errors(catalog, rows[:4].to_owned(), observed), [])
  assert_true(
    real_actual_source_errors(catalog, rows, observed).any(error => {
      error.contains("actual unique genuine source budget exceeds64MiB")
    }),
  )
  assert_eq(
    real_actual_source_errors(catalog, Array::make(8, rows[0]), observed),
    [],
  )
  let first = rows[0].source.unwrap()
  let same_source : NaturalSource = {
    ..first,
    path: "budget/same-identity-different-size",
  }
  let conflicting = {
    ..rows[0],
    id: "conflicting-source-size",
    source: Some(same_source),
  }
  let aliases = [
    files[0],
    { "path": same_source.path, "sha256": first.sha256, "bytes": Json(1L) },
  ]
  let sizes = observed.copy()
  sizes[same_source.path] = 1L
  assert_true(
    real_actual_source_errors(
      { "schema": 1, "files": Json(aliases) },
      [rows[0], conflicting],
      sizes,
    ).any(error => {
      error.contains("same source identity has inconsistent actual sizes")
    }),
  )
}

///|
async test "real byte and record facets require typed positive observations rather than missing or null values" {
  let (_, _, _, rows) = real_test_registry()
  let root = @fs.tmpdir(prefix="cmd-real-observation-gates-")
  defer @fs.rmdir(root, recursive=true)
  let path = root + "/complete"
  @fs.write_file(path, "first\nsecond\n")
  let observed = observe_benchmark_features(path)
  for facet in ["bytes", "records"] {
    let row = { ..rows[0], facets: Some([facet]), }
    assert_eq(real_observation_errors(row, [observed]), [])
    assert_true(!real_observation_errors(row, []).is_empty())
    assert_true(!real_observation_errors(row, [Json::null()]).is_empty())
    assert_true(!real_observation_errors(row, [{}]).is_empty())
    let container = if facet == "bytes" {
      observed
    } else {
      real_field(observed, "records")
    }
    let key = if facet == "bytes" { "bytes" } else { "count" }
    guard container is Object(fields) else {
      fail("actual observer omitted required feature object")
    }
    let missing = fields.copy()
    missing.remove(key)
    let invalid = [
      Json(missing),
      real_test_replace(container, key, Json::null()),
      real_test_replace(container, key, Json(-1L)),
      real_test_replace(container, key, Json("malformed")),
    ]
    for value in invalid {
      let candidate = if facet == "bytes" {
        value
      } else {
        real_test_replace(observed, "records", value)
      }
      assert_true(
        !real_observation_errors(row, [candidate]).is_empty(),
        msg=facet,
      )
    }
  }
  @fs.write_file(root + "/empty", b"")
  let empty = observe_benchmark_features(root + "/empty")
  assert_eq(
    real_observation_errors({ ..rows[0], facets: Some(["empty"]), }, [empty]),
    [],
  )
  assert_true(
    !real_observation_errors({ ..rows[0], facets: Some(["bytes"]), }, [empty]).is_empty(),
  )
  assert_true(
    !real_observation_errors({ ..rows[0], facets: Some(["records"]), }, [empty]).is_empty(),
  )
}

///|
async test "real UTF8 facet requires a strict validity witness as well as nonASCII bytes" {
  let (_, _, _, rows) = real_test_registry()
  let root = @fs.tmpdir(prefix="cmd-real-utf8-gate-")
  defer @fs.rmdir(root, recursive=true)
  @fs.write_file(root + "/valid", "é\n")
  let observed = observe_benchmark_features(root + "/valid")
  let row = { ..rows[0], facets: Some(["utf8"]), }
  let valid = real_test_replace(observed, "valid_utf8", Json(true))
  assert_eq(real_observation_errors(row, [valid]), [])
  for
    value in [
      observed,
      real_test_replace(observed, "valid_utf8", Json(false)),
      real_test_replace(observed, "valid_utf8", Json::null()),
    ] {
    assert_true(!real_observation_errors(row, [value]).is_empty())
  }
  @fs.write_file(root + "/invalid", b"\xff\n")
  let invalid = real_test_replace(
    observe_benchmark_features(root + "/invalid"),
    "valid_utf8",
    Json(false),
  )
  assert_true(!real_observation_errors(row, [invalid]).is_empty())
}
