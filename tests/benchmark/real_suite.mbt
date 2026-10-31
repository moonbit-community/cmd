///|
fn real_field(value : Json, name : String) -> Json {
  match value {
    Object(fields) => fields.get(name).unwrap_or(Json::null())
    _ => Json::null()
  }
}

///|
fn real_array(value : Json) -> Array[Json] {
  match value {
    Array(rows) => rows
    _ => []
  }
}

///|
fn real_text(value : Json) -> String {
  match value {
    String(text) => text
    _ => ""
  }
}

///|
async fn real_registry_path(path : String) -> String {
  if @fs.exists(path) {
    path
  } else {
    "../" + path
  }
}

///|
fn real_sources(row : FunctionalWorkload) -> Array[NaturalSource] {
  let sources : Array[NaturalSource] = []
  if row.source is Some(source) {
    sources.push(source)
  }
  if row.other_source is Some(source) {
    sources.push(source)
  }
  for input in row.inputs.unwrap_or([]) {
    sources.push(input.source)
  }
  sources
}

///|
fn real_command_scope() -> Set[String] {
  Set([
    "base32", "base64", "cat", "cksum", "column", "comm", "csplit", "curl", "cut",
    "diff", "expand", "find", "fold", "grep", "gunzip", "gzip", "head", "join", "jq",
    "ln", "make", "md5sum", "nl", "paste", "rev", "rg", "sed", "sh", "sha1sum", "sha256sum",
    "sha512sum", "sort", "split", "strings", "tac", "tail", "tr", "tree", "unexpand",
    "uniq", "wc", "wget", "zcat",
  ])
}

///|
fn real_invocation_identity(row : FunctionalWorkload) -> Json {
  let inputs = row.inputs
    .unwrap_or([])
    .map(input => (input.target, input.source.sha256))
  inputs.sort_by((a, b) => a.0.lexical_compare(b.0))
  [
    Json(row.command),
    Json(row.args),
    Json(row.recipe),
    Json(row.source.map(source => source.sha256)),
    Json(row.other_source.map(source => source.sha256)),
    Json(inputs),
    Json(row.transport),
    Json(row.chunk_bytes),
    Json(row.sink),
    Json(row.sink_chunk_bytes),
    Json(row.sink_delay_ms),
  ]
}

///|
fn real_suite_errors(
  manifest : Json,
  catalog : Json,
  coverage : Json,
  rows : Array[FunctionalWorkload],
) -> Array[String] {
  let errors : Array[String] = []
  for
    name in [
      "base_manifest", "sweeps", "seeds", "corpus_sweeps", "seed_variants", "published_manifest",
      "workspace_case_corpus",
    ] {
    if real_field(manifest, name) != Json::null() {
      errors.push(
        "schema3 requires explicit complete real rows; legacy expansion field is retired: " +
        name,
      )
    }
  }
  if real_field(manifest, "schema") != Json(3) ||
    real_field(catalog, "schema") != Json(1) ||
    real_field(coverage, "schema") != Json(1) {
    errors.push(
      "real-corpus performance requires manifest schema3 and source/coverage schema1",
    )
  }
  let limits = real_field(manifest, "limits")
  let max_file : Int64 = @json.from_json(real_field(limits, "max_source_bytes")) catch {
    _ => 0L
  }
  let max_total : Int64 = @json.from_json(
    real_field(limits, "max_unique_source_bytes"),
  ) catch {
    _ => 0L
  }
  if max_file <= 0L ||
    max_file > 16777216L ||
    max_total < max_file ||
    max_total > 67108864L {
    errors.push(
      "real source limits must be explicit and at most16MiB/file and64MiB unique bytes",
    )
  }
  let records : Map[String, Json] = Map([])
  for source in real_array(real_field(catalog, "files")) {
    let path = real_text(real_field(source, "path"))
    if !@testkit.safe_relative_path(path) || records.contains(path) {
      errors.push("unsafe or duplicate real source path: " + path)
    }
    for key in ["sha256", "provenance", "family", "url", "license_record"] {
      if real_text(real_field(source, key)).trim().is_empty() {
        errors.push("real source lacks " + key + ": " + path)
      }
    }
    let size : Int64 = @json.from_json(real_field(source, "bytes")) catch {
      _ => -1L
    }
    if size < 0L || size > max_file {
      errors.push("real source size is missing or exceeds limit: " + path)
    }
    records[path] = source
  }
  for row in real_array(real_field(manifest, "workloads")) {
    for name in ["case_id", "pending", "corpus", "seed"] {
      if real_field(row, name) != Json::null() {
        errors.push("real rows reject retired literal/generated field: " + name)
      }
    }
  }
  let identities : Array[Json] = []
  let used : Map[String, Int64] = Map([])
  for row in rows {
    if row.transport is Some(_) && row.sink is Some(_) {
      errors.push(
        "combined input/output pipe observations are not implemented: " + row.id,
      )
    }
    let contracts = real_array(real_field(coverage, "mode_contracts")).filter(contract => {
      real_field(contract, "command") == Json(row.command) &&
      real_field(contract, "mode") == Json(row.mode.unwrap_or(""))
    })
    if contracts is [contract] {
      let invocation : Json = {
        "args": Json(row.args.unwrap_or([])),
        "recipe": Json(row.recipe.unwrap_or("")),
        "expected_status": row.expected_status.unwrap_or(0),
      }
      if !real_array(real_field(contract, "allowed_invocations")).contains(
          invocation,
        ) {
        errors.push(
          "real mode argv/preparation/status differs from reviewed operation contract: " +
          row.id,
        )
      }
      for facet in row.facets.unwrap_or([]) {
        if [
            "formatting", "selection", "sorting", "spill", "codec", "network", "early-exit",
          ].contains(facet) &&
          !real_array(real_field(contract, "operation_facets")).contains(
            Json(facet),
          ) {
          errors.push(
            "unreviewed operation facet on real row: " + row.id + ":" + facet,
          )
        }
      }
    } else {
      errors.push("real row has no unique reviewed mode contract: " + row.id)
    }
    if row.args.unwrap_or([]).any(arg => ["--help", "--version"].contains(arg)) {
      errors.push(
        "metadata cannot replace a real performance operation: " + row.id,
      )
    }
    if row.output_relation is Some(relation) &&
      (
        !["record-multiset", "json"].contains(relation) ||
        !row.facets.unwrap_or([]).contains("tree")
      ) {
      errors.push(
        "structural output relation requires a declared bounded tree listing: " +
        row.id,
      )
    }
    if row.source is None ||
      row.args is None ||
      row.expected_status is None ||
      row.mode.unwrap_or("").is_empty() ||
      row.facets.unwrap_or([]).is_empty() {
      errors.push(
        "real workload needs genuine sources, explicit mode/facets/argv/status and no generated/literal/pending substitute: " +
        row.id,
      )
    }
    let identity = real_invocation_identity(row)
    if identities.contains(identity) {
      errors.push("duplicate actual real-source invocation: " + row.id)
    }
    identities.push(identity)
    if ![
        Some("real-input"),
        Some("real-file-pair"),
        Some("gzip"),
        Some("bench-join-natural-csv"),
        Some("bench-comm-natural-idsets"),
        Some("bench-csplit-boundaries"),
        Some("bench-split-byte-chunks"),
        Some("bench-gunzip-stored"),
        Some("bench-gunzip-fixed-literals"),
        Some("bench-gunzip-native-dynamic"),
        Some("bench-gunzip-members"),
        Some("bench-zcat-stored"),
        Some("bench-zcat-fixed-literals"),
        Some("bench-zcat-native-dynamic"),
        Some("bench-zcat-members"),
      ].contains(row.recipe) {
      errors.push("real workload has an undeclared preparation: " + row.id)
    }
    let targets : Set[String] = Set([])
    let originals : Set[String] = Set([])
    for input in row.inputs.unwrap_or([]) {
      if !@testkit.safe_relative_path(input.target) ||
        targets.contains(input.target) {
        errors.push("unsafe or duplicate real input target: " + row.id)
      }
      targets.add(input.target)
      if originals.contains(input.source.path) {
        errors.push(
          "real collection repeats the same original source: " + row.id,
        )
      }
      originals.add(input.source.path)
    }
    let facets : Set[String] = Set([])
    for facet in row.facets.unwrap_or([]) {
      if ![
          "bytes", "records", "utf8", "binary", "empty", "unterminated", "long-record",
          "named-files", "tree", "pipe-input", "slow-output", "early-exit", "formatting",
          "selection", "sorting", "spill", "duplicates", "codec", "network",
        ].contains(facet) ||
        facets.contains(facet) {
        errors.push("unknown or duplicate real facet: " + row.id + ":" + facet)
      }
      facets.add(facet)
    }
    for source in real_sources(row) {
      match records.get(source.path) {
        Some(record) if real_field(record, "sha256") == Json(source.sha256) => {
          let size : Int64 = @json.from_json(real_field(record, "bytes")) catch {
            _ => 0L
          }
          used[source.sha256] = size
        }
        _ =>
          errors.push(
            "workload source is absent or differs from provenance catalog: " +
            row.id +
            ":" +
            source.path,
          )
      }
    }
  }
  if used.values().fold(init=0L, (sum, size) => sum + size) > max_total {
    errors.push("real suite exceeds unique-source budget")
  }
  let commands : Set[String] = Set([])
  for spec in real_array(real_field(coverage, "commands")) {
    let command = real_text(real_field(spec, "command"))
    if command.is_empty() || commands.contains(command) {
      errors.push("empty or duplicate real coverage command")
    }
    commands.add(command)
    let selected = rows.filter(row => row.command == command)
    let disposition = real_text(real_field(spec, "disposition"))
    if disposition == "correctness-only" {
      if !["ln", "make", "sh"].contains(command) {
        errors.push(
          "reviewed timing command cannot be relabeled correctness-only: " +
          command,
        )
      }
      if !selected.is_empty() ||
        real_array(real_field(spec, "local_case_ids")).is_empty() ||
        real_text(real_field(spec, "reason")).trim().is_empty() {
        errors.push(
          "correctness-only command needs local witnesses, reason and no invented timing rows: " +
          command,
        )
      }
      continue
    }
    if ["ln", "make", "sh"].contains(command) {
      errors.push(
        "reviewed correctness-only command needs a new deliberate timing policy before measured inclusion: " +
        command,
      )
    }
    if disposition != "timing" ||
      selected.is_empty() ||
      real_array(real_field(spec, "required_modes")).is_empty() ||
      real_array(real_field(spec, "required_facets")).is_empty() ||
      real_array(real_field(spec, "local_case_ids")).is_empty() {
      errors.push(
        "real command requires nonempty timing mode/facet and local contract coverage: " +
        command,
      )
    }
    for mode in real_array(real_field(spec, "required_modes")) {
      if !selected.any(row => row.mode == Some(real_text(mode))) {
        errors.push(
          "missing required real command mode: " +
          command +
          ":" +
          real_text(mode),
        )
      }
    }
    for facet in real_array(real_field(spec, "required_facets")) {
      if !selected.any(row => {
          row.facets.unwrap_or([]).contains(real_text(facet))
        }) {
        errors.push(
          "missing required real facet: " + command + ":" + real_text(facet),
        )
      }
    }
  }
  for row in rows {
    if !commands.contains(row.command) {
      errors.push(
        "real workload command has no coverage disposition: " + row.command,
      )
    }
  }
  if commands != real_command_scope() {
    errors.push(
      "real coverage must account for every command in the reviewed43-command scope",
    )
  }
  errors
}

///|
async fn validate_real_suite(
  path : String,
  rows : Array[FunctionalWorkload],
) -> Unit {
  let manifest = @json.parse(@fs.read_file(path).text())
  let source_path = real_registry_path(
    real_text(real_field(manifest, "source_catalog")),
  )
  let coverage_path = real_registry_path(
    real_text(real_field(manifest, "coverage_registry")),
  )
  let coverage = @json.parse(@fs.read_file(coverage_path).text())
  let errors = real_suite_errors(
    manifest,
    @json.parse(@fs.read_file(source_path).text()),
    coverage,
    rows,
  )
  let protection = @json.parse(
    @fs.read_file(real_registry_path("tests/benchmark/protection.json")).text(),
  )
  guard real_field(protection, "profiles") is Object(profiles) else {
    fail("missing independently registered real protection routes")
  }
  for spec in real_array(real_field(coverage, "commands")) {
    let command = real_text(real_field(spec, "command"))
    let actual = rows
      .filter(row => row.command == command)
      .map(row => Json(row.id))
    let registered = real_array(profiles.get(command).unwrap_or(Json::null()))
    if real_field(spec, "disposition") == Json("correctness-only") {
      actual.push(Json("correctness-only:" + command))
    }
    if registered.length() != actual.length() ||
      registered.any(id => !actual.contains(id)) {
      errors.push(
        "real suite disagrees with independently registered required protection rows: " +
        command,
      )
    }
  }
  let typed : FunctionalManifest = @json.from_json(manifest)
  let cases = @testkit.load_cases(real_registry_path(typed.case_corpus))
  let index = @registry.load(real_registry_path("tests/registry/registry.json"))
  for row in rows {
    if !index.entries.any(entry => {
        entry.command == row.command &&
        (
          entry.behavior_id == row.reference_behavior_id ||
          entry.aliases.contains(row.reference_behavior_id)
        )
      }) {
      errors.push(
        "real workload has no owned runtime behavior reference: " + row.id,
      )
    }
  }
  @testkit.configure_local_quality(
    real_registry_path("tests/registry/case-quality.json"),
    cases,
    index.entries
    .filter(row => row.implementation == "stateful-scenario")
    .map(row => {
      row.behavior_id
      .strip_prefix("scenario:")
      .map(StringView::to_owned)
      .unwrap_or(row.case_id)
    }),
  )
  for command in real_array(real_field(coverage, "commands")) {
    let name = real_text(real_field(command, "command"))
    for id in real_array(real_field(command, "local_case_ids")) {
      let found = cases.filter(fixture => {
        fixture.id == real_text(id) ||
        fixture.aliases.unwrap_or([]).contains(real_text(id))
      })
      if !(found is [fixture] &&
        (
          fixture.command == name ||
          fixture.related_commands.unwrap_or([]).contains(name)
        ) &&
        @testkit.local_quality_descriptor(fixture.id) is Some(_)) {
        errors.push(
          "real boundary needs an owned independent exact/typed local contract: " +
          name +
          ":" +
          real_text(id),
        )
      }
    }
  }
  guard errors.is_empty() else { fail(errors.join("\n")) }
}

///|
async fn validate_real_source_sizes(
  options : Map[String, String],
  rows : Array[FunctionalWorkload],
) -> Unit {
  let path = options.get("--manifest").unwrap_or("tests/benchmark/real.json")
  let manifest = @json.parse(@fs.read_file(path).text())
  let catalog = @json.parse(
    @fs.read_file(
      real_registry_path(real_text(real_field(manifest, "source_catalog"))),
    ).text(),
  )
  let sources = real_array(real_field(catalog, "files"))
  let root = options.get("--corpus-root").unwrap_or("")
  guard @path.Path(root).is_absolute() else {
    fail("genuine input requires absolute corpus root")
  }
  let observed : Map[String, Int64] = Map([])
  for row in rows {
    for source in real_sources(row) {
      let actual = @fs.file_size(root + "/" + source.path)
      observed[source.path] = actual
    }
  }
  ignore(sources)
  let errors = real_actual_source_errors(catalog, rows, observed)
  guard errors.is_empty() else { fail(errors.join("\n")) }
}

///|
fn real_actual_source_errors(
  catalog : Json,
  rows : Array[FunctionalWorkload],
  observed_sizes : Map[String, Int64],
) -> Array[String] {
  let errors : Array[String] = []
  let unique : Map[String, Int64] = Map([])
  let sources = real_array(real_field(catalog, "files"))
  for row in rows {
    for source in real_sources(row) {
      let records = sources.filter(record => {
        real_field(record, "path") == Json(source.path) &&
        real_field(record, "sha256") == Json(source.sha256)
      })
      guard records is [record] &&
        observed_sizes.get(source.path) is Some(actual) else {
        errors.push("missing/ambiguous observed genuine source: " + source.path)
        continue
      }
      let expected : Int64 = @json.from_json(real_field(record, "bytes")) catch {
        _ => -1L
      }
      if actual < 0L || actual > 16777216L || actual != expected {
        errors.push(
          "observed genuine source differs from size/budget: " + source.path,
        )
      }
      if unique.get(source.sha256) is Some(previous) && previous != actual {
        errors.push("same source identity has inconsistent actual sizes")
      }
      unique[source.sha256] = actual
    }
  }
  if unique.values().fold(init=0L, (sum, size) => sum + size) > 67108864L {
    errors.push("actual unique genuine source budget exceeds64MiB")
  }
  errors
}

///|
fn real_observation_errors(
  row : FunctionalWorkload,
  observations : Array[Json],
) -> Array[String] {
  let errors : Array[String] = []
  for facet in row.facets.unwrap_or([]) {
    let observed = match facet {
      "empty" =>
        observations.any(value => real_field(value, "bytes") == Json(0L))
      "bytes" =>
        observations.any(value => {
          (@json.from_json(real_field(value, "bytes")) > 0L) catch {
            _ => false
          }
        })
      "records" =>
        observations.any(value => {
          (@json.from_json(real_field(real_field(value, "records"), "count")) >
          0L) catch {
            _ => false
          }
        })
      "unterminated" =>
        observations.any(value => {
          real_field(real_field(value, "records"), "unterminated_tail") ==
          Json(true)
        })
      "long-record" =>
        observations.any(value => {
          (@json.from_json(
            real_field(real_field(value, "records"), "max_bytes"),
          ) >=
          65536L) catch {
            _ => false
          }
        })
      "utf8" =>
        observations.any(value => {
          real_field(value, "valid_utf8") == Json(true) &&
          ((@json.from_json(
            real_field(
              real_field(value, "byte_distribution"),
              "non_ascii_bytes",
            ),
          ) >
          0L) catch {
            _ => false
          })
        })
      "binary" =>
        observations.any(value => {
          (@json.from_json(
            real_field(real_field(value, "byte_distribution"), "nul_bytes"),
          ) >
          0L) catch {
            _ => false
          }
        })
      "duplicates" =>
        observations.any(value => {
          (@json.from_json(
            real_field(
              real_field(value, "record_repetition"),
              "adjacent_duplicate_pairs",
            ),
          ) >
          0L) catch {
            _ => false
          }
        })
      "pipe-input" => row.transport == Some("fragmented-pipe")
      "slow-output" => row.sink == Some("slow-pipe")
      "tree" => row.inputs.unwrap_or([]).length() > 1
      "named-files" =>
        row.inputs is Some(_) ||
        benchmark_file_recipe(row.recipe) ||
        row.args.unwrap_or([]).any(arg => arg.contains("${INPUT}"))
      "formatting" =>
        [
          "cat", "column", "expand", "unexpand", "fold", "nl", "paste", "rev", "rg",
          "grep", "tr", "jq", "tree",
        ].contains(row.command) &&
        (row.command != "cat" || !row.args.unwrap_or([]).is_empty())
      "selection" =>
        [
          "cut", "sed", "grep", "rg", "head", "tail", "find", "jq", "tree", "strings",
          "tr", "join", "comm",
        ].contains(row.command) &&
        !row.args.unwrap_or([]).is_empty()
      "sorting" =>
        row.command == "sort" ||
        (
          row.command == "jq" &&
          row.args.unwrap_or([]).any(arg => arg.contains("sort"))
        ) ||
        [Some("bench-join-natural-csv"), Some("bench-comm-natural-idsets")].contains(
          row.recipe,
        )
      "spill" =>
        row.command == "sort" &&
        row.args.unwrap_or([]).contains("-S") &&
        observations.any(value => {
          (@json.from_json(real_field(value, "bytes")) > 4194304L) catch {
            _ => false
          }
        })
      "codec" =>
        ["base32", "base64", "gzip", "gunzip", "zcat"].contains(row.command)
      "network" =>
        ["curl", "wget"].contains(row.command) &&
        row.args.unwrap_or([]).any(arg => arg.has_prefix("${HTTP_BASE}/real-"))
      "early-exit" =>
        row.command == "head" ||
        (
          ["rg", "grep"].contains(row.command) &&
          ({
            let args = row.args.unwrap_or([])
            let mut count_one = false
            for index in 0..<args.length() {
              if args[index] == "-m" && args.get(index + 1) == Some("1") {
                count_one = true
              }
            }
            args.any(arg => {
              ["-q", "--quiet", "-m1", "-l", "--files-with-matches"].contains(
                arg,
              )
            }) ||
            count_one
          })
        )
      _ => false
    }
    if !observed {
      errors.push(
        "declared real facet has no actual input/transport witness: " +
        row.id +
        ":" +
        facet,
      )
    }
  }
  errors
}

///|
async fn prepare_real_inputs(
  row : FunctionalWorkload,
  root : String,
  corpus : PreparedCorpus?,
) -> Unit {
  guard row.inputs is Some(inputs) else { return }
  guard corpus is Some(corpus) else {
    fail("real file collection requires a frozen primary source")
  }
  for input in inputs {
    let source = @path.Path(corpus.source)
      .dirname()
      .join(Path("natural-" + input.source.sha256 + ".bin"))
      .to_string()
    let target = root + "/" + input.target
    @fs.mkdir(
      @path.Path(target).dirname().to_string(),
      recursive=true,
      allow_exist=true,
    )
    ignore(freeze_benchmark_file(source, target, expected=input.source.sha256))
  }
}
