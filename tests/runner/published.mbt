///|
struct PublishedCommand {
  name : String
  package_name : String
  version : String
} derive(FromJson)

///|
struct PublishedSelection {
  base_manifest : String
  commands : Array[PublishedCommand]
  case_ids : Array[String]
  extra_cases : Array[Json]
} derive(FromJson)

///|
fn published_coordinates(
  selection : PublishedSelection,
) -> Map[String, String] raise {
  guard !selection.commands.is_empty() && !selection.case_ids.is_empty() else {
    fail("published acceptance requires commands and cases")
  }
  guard @testkit.safe_relative_path(selection.base_manifest) else {
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
    ids.add(id)
  }
  let coordinates : Map[String, String] = Map([])
  for command in selection.commands {
    guard command.package_name == "cli/" + command.name &&
      command.version != "latest" &&
      !command.version.is_empty() &&
      !command.version.contains("@") &&
      !command.version.contains("/") &&
      !coordinates.contains(command.name) &&
      command.name != "timeout" else {
      fail("invalid or duplicate published coordinate: " + command.name)
    }
    guard @contracts.find_contract(command.name) is Some(contract) &&
      @contracts.releasable(contract) else {
      fail("command is outside the published inventory: " + command.name)
    }
    guard command.version.split(".").count() >= 3 &&
      ![" ", "\t", "\n", "\r"].any(value => command.version.contains(value)) else {
      fail("expected an exact package version: " + command.name)
    }
    coordinates[command.name] = command.package_name + "@" + command.version
  }
  coordinates
}

///|
async fn load_published_commands(
  path : String,
  moonx : String,
) -> (String, Array[String]) {
  let selection : PublishedSelection = @json.from_json(
    @json.parse(@fs.read_file(path).text()),
  )
  @testkit.configure_commands(published_coordinates(selection), moonx)
  let cases = @path.Path(path)
    .dirname()
    .join(Path(selection.base_manifest))
    .to_string()
  (cases, selection.case_ids)
}

///|
async fn prime_published_commands(
  selected : Array[String],
  reports : Array[@testkit.CaseReport],
  execute~ : async (String, Array[String], Int32) -> @testkit.TimedRun = (
    program,
    args,
    timeout,
  ) => @testkit.run_with_deadline(program, args, timeout),
) -> Unit {
  for contract in @contracts.command_catalog() {
    let name = contract.name
    if !@testkit.command_available(name) ||
      (!selected.is_empty() && !selected.contains(name)) {
      continue
    }
    let start = @async.now()
    let result = execute(
      @testkit.command_program(),
      @testkit.command_args("", name, ["--version"]),
      120000,
    )
    let failures : Array[String] = []
    if result.timed_out ||
      result.cleanup_error is Some(_) ||
      result.output.status != 0 ||
      result.output.stderr != b"" ||
      result.output.stdout !=
      @utf8.encode(name + " " + @testkit.command_version(name).unwrap() + "\n") {
      failures.push(
        "exact-version startup failed for \{name}@\{@testkit.command_version(name).unwrap()}: status=\{result.output.status}, timed_out=\{result.timed_out}, stdout=\{result.output.stdout}, stderr=" +
        @utf8.decode_lossy(result.output.stderr),
      )
    }
    @testkit.append_report(reports, {
      ..suite_report("published-resolution:" + name, "moonx", start, failures),
      command: name,
      verification: "availability",
    })
    guard failures.is_empty() else { fail(failures.join("; ")) }
  }
}
