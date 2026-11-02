///|
priv struct DriverOptions {
  manifest_path : String
  published_manifest : String?
  moonx : String
  wasm_root : String
  oracle_image : String
  suites : Array[String]
  commands : Array[String]
  ids : Array[String]
  jobs : Int32
  list : Bool
  validate_only : Bool
  report_dir : String
}

///|
fn parse_driver_options(
  args : ArrayView[String],
  project_root : String,
  canonical_corpus_path : String,
) -> DriverOptions raise {
  let mut manifest_path = canonical_corpus_path
  let mut published_manifest : String? = None
  let mut moonx = "moonx"
  let mut wasm_root = workspace_path(project_root, "_build/wasm/release/build")
  let mut oracle_image = "mooncmd-oracle:phase0"
  let suites : Array[String] = []
  let commands : Array[String] = []
  let ids : Array[String] = []
  let mut jobs = 4
  let mut list = false
  let mut validate_only = false
  let mut report_dir = workspace_path(
    project_root,
    "test-reports/workspace-" + @async.now().to_string(),
  )
  let mut index = 0
  while index < args.length() {
    let flag = args[index]
    match flag {
      "--list" => list = true
      "--validate-only" => validate_only = true
      "--manifest"
      | "--published-manifest"
      | "--moonx"
      | "--wasm-root"
      | "--oracle-image"
      | "--suite"
      | "--command"
      | "--case"
      | "--report-dir"
      | "--jobs" => {
        index += 1
        guard args.get(index) is Some(value) else { fail(usage()) }
        match flag {
          "--manifest" => manifest_path = value
          "--published-manifest" => published_manifest = Some(value)
          "--moonx" => moonx = value
          "--wasm-root" => wasm_root = value
          "--oracle-image" => oracle_image = value
          "--suite" => if !suites.contains(value) { suites.push(value) }
          "--command" => commands.push(value)
          "--case" => ids.push(value)
          "--report-dir" => report_dir = value
          _ => jobs = @string.parse_int(value) catch { _ => 0 }
        }
      }
      _ => fail(usage())
    }
    index += 1
  }
  if jobs < 1 ||
    suites.any(suite => {
      ![
        "functional", "metadata", "compat", "contract", "policy", "oracle", "stress",
        "scenarios", "all",
      ].contains(suite)
    }) {
    fail(usage())
  }
  if suites.is_empty() {
    suites.push("functional")
  }
  if suites.contains("functional") || suites.contains("all") {
    let oracle = suites.contains("oracle") || suites.contains("all")
    suites.clear()
    suites.append([
      "metadata", "compat", "contract", "scenarios", "policy", "stress",
    ])
    if oracle {
      suites.push("oracle")
    }
  }
  {
    manifest_path,
    published_manifest,
    moonx,
    wasm_root,
    oracle_image,
    suites,
    commands,
    ids,
    jobs,
    list,
    validate_only,
    report_dir,
  }
}
