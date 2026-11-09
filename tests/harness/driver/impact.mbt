///|
#derive(ToJson, FromJson)
priv struct OracleSelection {
  schema : Int32
  commit : String
  scope : String
  reason : String
  commands : Array[String]
  case_ids : Array[String]
  changed_paths : Array[String]
}

///|
fn changed_paths(data : String) -> Array[String] raise {
  if data == "" {
    return []
  }
  let fields = data.split("\u0000").map(StringView::to_owned).collect()
  guard fields.last() == Some("") else { fail("unterminated Git change list") }
  let paths : Array[String] = []
  let mut index = 0
  while index < fields.length() - 1 {
    let status = fields[index]
    index += 1
    let count = if status.has_prefix("R") || status.has_prefix("C") {
      2
    } else {
      1
    }
    guard ["A", "D", "M", "T", "U"].contains(status) || count == 2 else {
      fail("unknown Git change status")
    }
    for _ in 0..<count {
      guard fields.get(index) is Some(path) && @harness.safe_relative_path(path) else {
        fail("invalid Git change path")
      }
      paths.push(path)
      index += 1
    }
  }
  paths
}

///|
async fn expand_oracle_selection(args : Array[String]) -> Array[String] {
  if args.get(0) != Some("--run-oracle-selection") {
    return args
  }
  guard args
    is ["--run-oracle-selection", path, report, "--oracle-image", image] else {
    fail("selected differential requires its pinned oracle image")
  }
  [..oracle_selection_arguments(path, report), "--oracle-image", image]
}

///|
async fn oracle_selection_arguments(
  path : String,
  report : String,
) -> Array[String] {
  let selection : OracleSelection = @json.from_json(
    @json.parse(@fs.read_file(path).text()),
  )
  guard selection.schema == 1 &&
    ["all", "commands"].contains(selection.scope) &&
    !selection.case_ids.is_empty() else {
    fail("empty or invalid required differential selection")
  }
  let current = @harness.run_with_deadline("git", ["rev-parse", "HEAD"], 15000)
  guard current.output.status == 0 &&
    !current.timed_out &&
    current.cleanup_error is None &&
    @utf8.decode(current.output.stdout).trim() == selection.commit else {
    fail("differential selection commit mismatch")
  }
  let args = ["--suite", "oracle", "--jobs", "2", "--report-dir", report]
  for id in selection.case_ids {
    args.append(["--case", id])
  }
  args
}

///|
fn oracle_impact(
  paths : Array[String]?,
  commands : Array[String],
  cases : Array[@harness.Case],
) -> (String, String, Array[String]) {
  guard paths is Some(paths) && !paths.is_empty() else {
    return ("all", "comparison baseline unavailable or empty", commands)
  }
  let selected : Set[String] = Set([])
  for path in paths {
    let source = [".mbt", ".mbti", ".mbtx", ".mbt.md"].any(suffix => {
      path.has_suffix(suffix)
    })
    if !source &&
      (
        path.has_prefix("docs/") ||
        path.contains("/docs/") ||
        path == "LICENSE" ||
        path == "LICENSE.txt" ||
        path.has_suffix("README.md") ||
        (
          path.has_suffix(".md") &&
          !path.contains("/fixtures/") &&
          !path.contains("/testdata/")
        )
      ) {
      continue
    }
    let parts = path.split("/").map(StringView::to_owned).collect()
    if parts.length() >= 3 &&
      parts[0] == "commands" &&
      commands.contains(parts[1]) {
      selected.add(parts[1])
      continue
    }
    if parts is ["tests", "cases", file] && file.has_suffix(".json") {
      let command = file[:file.length() - 5].to_owned()
      if commands.contains(command) {
        selected.add(command)
        continue
      }
    }
    let owners = cases.filter(fixture => {
      fixture.inputs.unwrap_or([]).contains(path)
    })
    if !owners.is_empty() {
      for fixture in owners {
        selected.add(fixture.command)
        for command in fixture.related_commands.unwrap_or([]) {
          selected.add(command)
        }
      }
      continue
    }
    if source ||
      path.has_prefix("core/") ||
      path.has_prefix("tests/") ||
      path.has_prefix(".github/workflows/") ||
      path.has_prefix(".github/actions/") ||
      ["moon.work", "moon.mod", "moon.pkg", ".gitmodules"].contains(path) {
      return (
        "all",
        "shared or unclassified execution input: " + path,
        commands,
      )
    }
  }
  let result = selected.iter().collect()
  result.sort()
  if result.is_empty() {
    ("none", "no functional changes", [])
  } else {
    ("commands", "registered command and fixture consumers", result)
  }
}

///|
async fn select_oracle_changes(
  root : String,
  base : String,
  head : String,
  output : String,
) -> Unit {
  guard !@fs.exists(output) else { fail("selection output already exists") }
  let all = @harness.load_cases(root + "/tests/cases/manifest.json")
  validate_case_inputs(root, all)
  let commands = @catalog.commands().map(command => command.name)
  let diff = @harness.run_with_deadline(
    "git",
    ["diff", "--name-status", "-z", "--find-renames", base, head, "--"],
    15000,
    cwd=root,
  )
  let paths = if diff.output.status == 0 &&
    !diff.timed_out &&
    diff.cleanup_error is None {
    Some(changed_paths(@utf8.decode(diff.output.stdout)))
  } else {
    None
  }
  let (scope, reason, affected) = oracle_impact(paths, commands, all)
  let registry = @catalog.load(root + "/tests/cases/index.json")
  let cases = if scope == "none" {
    []
  } else {
    @harness.select_cases(all, affected, []).filter(fixture => {
      case_in_suites(fixture, ["oracle"])
    })
  }
  for command in affected {
    if !cases.any(fixture => {
        fixture.command == command ||
        fixture.related_commands.unwrap_or([]).contains(command)
      }) {
      guard registry.release_commands.any(item => {
        item.name == command && item.oracle_boundary.unwrap_or("") != ""
      }) else {
        fail("empty required oracle selection: " + command)
      }
    }
  }
  let scope = if scope != "none" && cases.is_empty() { "none" } else { scope }
  let reason = if !affected.is_empty() && cases.is_empty() {
    "explicit registered upstream boundaries: " + affected.join(", ")
  } else {
    reason
  }
  let selection : OracleSelection = {
    schema: 1,
    commit: head,
    scope,
    reason,
    commands: affected,
    case_ids: cases.map(fixture => fixture.id),
    changed_paths: paths.unwrap_or([]),
  }
  @fs.write_file(output, @json.to_json(selection).stringify(indent=2) + "\n")
  if @env.get_env_var("GITHUB_OUTPUT") is Some(path) {
    @fs.write_file(
      path,
      "required=" + (if scope == "none" { "false" } else { "true" }) + "\n",
      append=true,
    )
  }
  println(
    "Oracle scope: " +
    scope +
    "; " +
    reason +
    "; cases=" +
    cases.length().to_string(),
  )
}

///|
async fn validate_case_inputs(
  root : String,
  cases : Array[@harness.Case],
) -> Unit {
  for fixture in cases {
    let seen : Set[String] = Set([])
    for path in fixture.inputs.unwrap_or([]) {
      guard @harness.safe_relative_path(path) && !seen.contains(path) else {
        fail(fixture.id + ": invalid fixture input: " + path)
      }
      seen.add(path)
      guard @fs.exists(workspace_path(root, path)) else {
        fail(fixture.id + ": missing fixture input: " + path)
      }
    }
  }
}
