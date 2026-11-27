///|
#derive(FromJson)
struct PublishedSelection {
  candidate : Bool?
  base_manifest : String
  case_ids : Array[String]
  extra_cases : Array[Json]
}

///|
fn validate_published_selection(selection : PublishedSelection) -> Unit raise {
  guard !selection.case_ids.is_empty() else {
    fail("published acceptance requires selected cases")
  }
  // Generated candidates use the sibling current corpus; other parent paths
  // remain rejected, and published snapshots keep their local expectation file.
  let current_candidate = selection.candidate == Some(true) &&
    selection.base_manifest == "../cases/manifest.json"
  guard @harness.safe_relative_path(selection.base_manifest) ||
    current_candidate else {
    fail("unsafe published case path")
  }
  guard selection.extra_cases.is_empty() else {
    fail(
      "inline published cases must be moved into the selected expectation file",
    )
  }
  let ids : Set[String] = Set([])
  for id in selection.case_ids {
    guard !id.is_empty() && !ids.contains(id) else {
      fail("duplicate or empty published case ID")
    }
    ids.insert(id)
  }
}

///|
fn module_coordinate(command : String, source : String) -> String raise {
  let fields : Map[String, String] = Map([])
  for line in source.split("\n") {
    for key in ["name", "version"] {
      if line.trim().strip_prefix(key + " = ") is Some(value) {
        guard !fields.contains(key) &&
          @json.parse(value.to_owned()) is String(value) else {
          fail("invalid or duplicate module " + key + ": " + command)
        }
        fields[key] = value
      }
    }
  }
  guard fields.get("name") == Some("cli/" + command) &&
    fields.get("version") is Some(version) else {
    fail("missing or mismatched module coordinate: " + command)
  }
  guard exact_version(version) else {
    fail("expected an exact module version: " + command)
  }
  "cli/" + command + "@" + version
}

///|
fn exact_version(version : String) -> Bool {
  let build = version.split("+").collect()
  guard build.length() <= 2 else { return false }
  let identifiers = fn(text : StringView, prerelease : Bool) -> Bool {
    text
    .split(".")
    .all(part => {
      !part.is_empty() &&
      part
      .iter()
      .all(char => char is ('0'..<='9' | 'a'..<='z' | 'A'..<='Z' | '-')) &&
      (
        !prerelease ||
        !part.iter().all(char => char is ('0'..<='9')) ||
        part.length() == 1 ||
        !part.has_prefix("0")
      )
    })
  }
  if build.length() == 2 && !identifiers(build[1], false) {
    return false
  }
  let release = build[0]
  let core = if release.find("-") is Some(index) {
    if !identifiers(release[index + 1:], true) {
      return false
    }
    release[:index]
  } else {
    release
  }
  let parts = core.split(".").collect()
  parts.length() == 3 &&
  parts.all(part => {
    !part.is_empty() &&
    part.iter().all(char => char is ('0'..<='9')) &&
    (part.length() == 1 || !part.has_prefix("0"))
  })
}

///|
async fn published_coordinates(
  commands : Array[String],
  read_module~ : async (String) -> String = name => {
    @fs.read_file(@harness.repository_path("commands/" + name + "/moon.mod")).text()
  },
) -> Map[String, String] {
  guard !commands.is_empty() else {
    fail("empty release eligibility selection")
  }
  let coordinates : Map[String, String] = Map([])
  for name in commands {
    guard !coordinates.contains(name) &&
      @catalog.find(name) is Some(contract) &&
      @catalog.releasable(contract) else {
      fail("invalid release eligibility: " + name)
    }
    coordinates[name] = module_coordinate(name, read_module(name))
  }
  coordinates
}

///|
async fn load_published_commands(path : String) -> (String, Array[String]) {
  let selection : PublishedSelection = @json.from_json(
    @json.parse(@fs.read_file(path).text()),
  )
  validate_published_selection(selection)
  let cases = @path.Path(path)
    .dirname()
    .join(Path(selection.base_manifest))
    .to_string()
  (cases, selection.case_ids)
}

///|
fn published_case_commands(cases : Array[@harness.Case]) -> Array[String] raise {
  let names : Set[String] = Set([])
  for fixture in cases {
    guard @catalog.find(fixture.command) is Some(contract) &&
      @catalog.releasable(contract) else {
      fail("invalid primary release eligibility: " + fixture.command)
    }
    names.insert(fixture.command)
    for related in fixture.related_commands.unwrap_or([]) {
      guard @catalog.find(related) is Some(contract) else {
        fail("unknown related command: " + related)
      }
      if @catalog.releasable(contract) {
        names.insert(related)
      }
    }
  }
  let result = names.iter().collect()
  result.sort_by((left, right) => left.lexical_compare(right))
  result
}

///|
async fn prime_published_commands(
  selected : Array[String],
  reports : Array[@harness.CaseReport],
  execute~ : async (String, Array[String], Int32) -> @harness.TimedRun = (
    program,
    args,
    timeout,
  ) => @harness.run_with_deadline(program, args, timeout),
) -> Unit {
  for contract in @catalog.commands() {
    let name = contract.name
    if !@harness.command_available(name) ||
      (!selected.is_empty() && !selected.contains(name)) {
      continue
    }
    let start = @async.now()
    let result = execute(
      @harness.command_program(),
      @harness.command_args("", name, ["--version"]),
      120000,
    )
    let failures : Array[String] = []
    if result.timed_out ||
      result.cleanup_error is Some(_) ||
      result.output.status != 0 ||
      result.output.stderr != b"" ||
      result.output.stdout !=
      @utf8.encode(name + " " + @harness.command_version(name).unwrap() + "\n") {
      failures.push(
        "exact-version startup failed for \{name}@\{@harness.command_version(name).unwrap()}: status=\{result.output.status}, timed_out=\{result.timed_out}, stdout=\{result.output.stdout}, stderr=" +
        @utf8.decode_lossy(result.output.stderr),
      )
    }
    @harness.append_report(reports, {
      ..@harness.suite_report(
        "published-resolution:" + name,
        "moonx",
        start,
        failures,
      ),
      command: name,
      verification: "availability",
    })
    guard failures.is_empty() else { fail(failures.join("; ")) }
  }
}
