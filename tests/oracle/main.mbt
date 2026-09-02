///|
struct CommandRow {
  name : String
  baseline : String
  status : String
  native : String
  wasm : String
  capabilities : Array[String]
} derive(FromJson, Debug)

///|
struct FixtureFile {
  path : String
  content_hex : String
} derive(FromJson, Debug)

///|
struct Normalization {
  field : String
  rule : String
  comment : String
} derive(FromJson, Debug)

///|
struct OracleCase {
  id : String
  command : String
  args : Array[String]
  stdin_hex : String
  files : Array[FixtureFile]
  environment : Map[String, String]
  expected_status : Int
  normalizations : Array[Normalization]
} derive(FromJson, Debug)

///|
struct Manifest {
  schema : Int
  commands : Array[CommandRow]
  cases : Array[OracleCase]
} derive(FromJson, Debug)

///|
struct SnapshotEntry {
  path : String
  kind : String
  content : Bytes
} derive(Debug)

///|
fn usage() -> String {
  "Usage: oracle-runner --manifest FILE [--bin-root DIR --oracle-image IMAGE] [--validate-only]"
}

///|
fn hex_nibble(char : Char) -> Int? {
  match char {
    '0'..='9' => Some(char.to_int() - '0'.to_int())
    'a'..='f' => Some(char.to_int() - 'a'.to_int() + 10)
    'A'..='F' => Some(char.to_int() - 'A'.to_int() + 10)
    _ => None
  }
}

///|
fn decode_hex(value : String, label : String) -> Bytes raise Failure {
  if value.length() % 2 != 0 {
    fail("\{label}: hexadecimal byte string has odd length")
  }
  let output : Array[Byte] = []
  for index = 0; index < value.length(); index = index + 2 {
    guard value[index].to_char() is Some(high_char) &&
      value[index + 1].to_char() is Some(low_char) &&
      hex_nibble(high_char) is Some(high) &&
      hex_nibble(low_char) is Some(low) else {
      fail("\{label}: invalid hexadecimal byte at offset \{index}")
    }
    output.push(((high << 4) | low).to_byte())
  }
  Bytes::from_array(output)
}

///|
fn safe_relative_path(value : String) -> Bool {
  if value == "" || @path.Path(value).is_absolute() {
    return false
  }
  let normalized = value.replace_all(old="\\", new="/")
  for component in normalized.split("/") {
    if component == "" || component == "." || component == ".." {
      return false
    }
  }
  true
}

///|
fn validate_manifest(manifest : Manifest) -> Array[String] {
  let failures : Array[String] = []
  if manifest.schema != 1 {
    failures.push("manifest: expected schema 1, got \{manifest.schema}")
  }
  let catalog = @cli.command_catalog()
  if manifest.commands.length() != catalog.length() {
    failures.push(
      "manifest: expected \{catalog.length()} command rows, got \{manifest.commands.length()}",
    )
  }
  let rows : Map[String, Bool] = Map([])
  for row in manifest.commands {
    if rows.contains(row.name) {
      failures.push("manifest: duplicate command row '\{row.name}'")
    }
    rows[row.name] = true
    if !["unmeasured", "partial", "compatible", "exception"].contains(
        row.status,
      ) {
      failures.push("\{row.name}: invalid status '\{row.status}'")
    }
    if row.baseline == "" || row.native == "" || row.wasm == "" {
      failures.push(
        "\{row.name}: baseline and target classifications are required",
      )
    }
  }
  for contract in catalog {
    if !rows.contains(contract.name) {
      failures.push("manifest: missing command row '\{contract.name}'")
    }
  }
  let case_ids : Map[String, Bool] = Map([])
  for fixture in manifest.cases {
    if fixture.id == "" || case_ids.contains(fixture.id) {
      failures.push(
        "manifest: case IDs must be nonempty and unique: '\{fixture.id}'",
      )
    }
    case_ids[fixture.id] = true
    if !rows.contains(fixture.command) {
      failures.push("\{fixture.id}: unknown command '\{fixture.command}'")
    }
    ignore(decode_hex(fixture.stdin_hex, fixture.id + " stdin")) catch {
      err => failures.push("\{err}")
    }
    for file in fixture.files {
      if !safe_relative_path(file.path) {
        failures.push("\{fixture.id}: unsafe fixture path '\{file.path}'")
      }
      ignore(decode_hex(file.content_hex, fixture.id + " file " + file.path)) catch {
        err => failures.push("\{err}")
      }
    }
    for normalization in fixture.normalizations {
      if normalization.comment == "" {
        failures.push("\{fixture.id}: every normalization needs a comment")
      }
      if !["stdout", "stderr"].contains(normalization.field) {
        failures.push(
          "\{fixture.id}: unsupported normalization field '\{normalization.field}'",
        )
      }
      if !["temporary-path", "path-separator"].contains(normalization.rule) {
        failures.push(
          "\{fixture.id}: unsupported normalization rule '\{normalization.rule}'",
        )
      }
    }
  }
  failures
}

///|
async fn prepare_directory(root : String, fixture : OracleCase) -> Unit {
  for file in fixture.files {
    let destination = @path.Path(root).join(Path(file.path)).to_string()
    let parent = @path.Path(destination).dirname().to_string()
    @fs.mkdir(parent, recursive=true)
    @fs.write_file(
      destination,
      decode_hex(file.content_hex, fixture.id + " file " + file.path),
    )
  }
}

///|
fn kind_name(kind : @fs.FileKind) -> String {
  match kind {
    Regular => "file"
    Directory => "directory"
    SymLink => "symlink"
    BlockDevice => "block-device"
    CharDevice => "character-device"
    Pipe => "pipe"
    Socket => "socket"
    Unknown => "unknown"
  }
}

///|
async fn snapshot_into(
  root : String,
  relative : String,
  entries : Array[SnapshotEntry],
) -> Unit {
  let directory = if relative == "" {
    root
  } else {
    @path.Path(root).join(Path(relative)).to_string()
  }
  let names = @fs.readdir(
    directory,
    include_hidden=true,
    include_special=false,
    sort=true,
  )
  for name in names {
    let child_relative = if relative == "" {
      name
    } else {
      relative + "/" + name
    }
    let child = @path.Path(root).join(Path(child_relative)).to_string()
    let kind = @fs.kind(child, follow_symlink=false)
    let content = if kind == Regular {
      @fs.read_file(child).binary()
    } else {
      b""
    }
    entries.push({ path: child_relative, kind: kind_name(kind), content, })
    if kind == Directory {
      snapshot_into(root, child_relative, entries)
    }
  }
}

///|
async fn snapshot(root : String) -> Array[SnapshotEntry] {
  let entries : Array[SnapshotEntry] = []
  snapshot_into(root, "", entries)
  entries
}

///|
fn snapshots_equal(
  left : ArrayView[SnapshotEntry],
  right : ArrayView[SnapshotEntry],
) -> Bool {
  if left.length() != right.length() {
    return false
  }
  for index = 0; index < left.length(); index = index + 1 {
    if left[index].path != right[index].path ||
      left[index].kind != right[index].kind ||
      !@testkit.bytes_equal(left[index].content, right[index].content) {
      return false
    }
  }
  true
}

///|
fn first_byte_difference(left : Bytes, right : Bytes) -> String {
  let shared = left.length().min(right.length())
  for index = 0; index < shared; index = index + 1 {
    if left[index] != right[index] {
      return "first byte differs at \{index}: candidate=\{left[index]} oracle=\{right[index]}"
    }
  }
  if left.length() != right.length() {
    "length differs after \{shared} equal bytes: candidate=\{left.length()} oracle=\{right.length()}"
  } else {
    "no byte difference"
  }
}

///|
fn normalize_text(
  data : Bytes,
  field : String,
  rules : ArrayView[Normalization],
  temporary_root : String,
) -> Bytes {
  let mut applies = false
  for rule in rules {
    if rule.field == field {
      applies = true
    }
  }
  if !applies {
    return data
  }
  let mut text = data.to_unchecked_string()
  for rule in rules {
    if rule.field == field {
      match rule.rule {
        "temporary-path" =>
          text = text.replace_all(old=temporary_root, new="${TMP}")
        "path-separator" => text = text.replace_all(old="\\", new="/")
        _ => ()
      }
    }
  }
  @utf8.encode(text)
}

///|
fn controlled_environment(extra : Map[String, String]) -> Map[String, String] {
  let result : Map[String, String] = {
    "LC_ALL": "C",
    "LANG": "C",
    "TZ": "UTC",
    "PATH": "/usr/bin:/bin",
  }
  for name, value in extra {
    result[name] = value
  }
  result
}

///|
async fn run_case(
  fixture : OracleCase,
  bin_root : String,
  oracle_image : String,
) -> Array[String] {
  let failures : Array[String] = []
  let root = @fs.tmpdir(prefix="mooncmd-oracle-")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let candidate_root = @path.Path(root).join(Path("candidate")).to_string()
  let oracle_root = @path.Path(root).join(Path("oracle")).to_string()
  @fs.mkdir(candidate_root)
  @fs.mkdir(oracle_root)
  prepare_directory(candidate_root, fixture)
  prepare_directory(oracle_root, fixture)
  let stdin = decode_hex(fixture.stdin_hex, fixture.id + " stdin")
  let environment = controlled_environment(fixture.environment)
  let candidate = @testkit.run(
    @testkit.executable_path(bin_root, fixture.command),
    fixture.args,
    stdin~,
    cwd=candidate_root,
    extra_env=environment,
    inherit_env=false,
  ) catch {
    err => {
      failures.push("\{fixture.id}: candidate failed to start: \{err}")
      return failures
    }
  }
  let docker_args = [
    "run",
    "--rm",
    "-i",
    "--network",
    "none",
    "--read-only",
    "--tmpfs",
    "/tmp:rw,nosuid,nodev,size=64m",
    "-v",
    oracle_root + ":/work:rw",
    "-w",
    "/work",
  ]
  for name, value in environment {
    if name != "PATH" {
      docker_args.push("-e")
      docker_args.push(name + "=" + value)
    }
  }
  docker_args.push("-e")
  docker_args.push("PATH=/oracle/bin")
  docker_args.push(oracle_image)
  docker_args.push(fixture.command)
  docker_args.append(fixture.args)
  let oracle = @testkit.run("docker", docker_args, stdin~, inherit_env=true) catch {
    err => {
      failures.push("\{fixture.id}: oracle failed to start: \{err}")
      return failures
    }
  }
  if candidate.status != fixture.expected_status {
    failures.push(
      "\{fixture.id}: candidate status \{candidate.status}, expected \{fixture.expected_status}",
    )
  }
  if oracle.status != fixture.expected_status {
    failures.push(
      "\{fixture.id}: oracle status \{oracle.status}, expected \{fixture.expected_status}",
    )
  }
  let candidate_stdout = normalize_text(
    candidate.stdout,
    "stdout",
    fixture.normalizations,
    candidate_root,
  )
  let oracle_stdout = normalize_text(
    oracle.stdout,
    "stdout",
    fixture.normalizations,
    oracle_root,
  )
  if !@testkit.bytes_equal(candidate_stdout, oracle_stdout) {
    failures.push(
      "\{fixture.id}: stdout mismatch; " +
      first_byte_difference(candidate_stdout, oracle_stdout),
    )
  }
  let candidate_stderr = normalize_text(
    candidate.stderr,
    "stderr",
    fixture.normalizations,
    candidate_root,
  )
  let oracle_stderr = normalize_text(
    oracle.stderr,
    "stderr",
    fixture.normalizations,
    oracle_root,
  )
  if !@testkit.bytes_equal(candidate_stderr, oracle_stderr) {
    failures.push(
      "\{fixture.id}: stderr mismatch; " +
      first_byte_difference(candidate_stderr, oracle_stderr),
    )
  }
  let candidate_files = snapshot(candidate_root)
  let oracle_files = snapshot(oracle_root)
  if !snapshots_equal(candidate_files, oracle_files) {
    failures.push(
      "\{fixture.id}: filesystem mismatch\n  candidate=" +
      repr(candidate_files) +
      "\n  oracle=" +
      repr(oracle_files),
    )
  }
  failures
}

///|
async fn main {
  let args = @env.args()[1:]
  let mut manifest_path : String? = None
  let mut bin_root : String? = None
  let mut oracle_image = "mooncmd-oracle:phase0"
  let mut validate_only = false
  let mut index = 0
  while index < args.length() {
    match args[index] {
      "--manifest" if index + 1 < args.length() => {
        index += 1
        manifest_path = Some(args[index])
      }
      "--bin-root" if index + 1 < args.length() => {
        index += 1
        bin_root = Some(args[index])
      }
      "--oracle-image" if index + 1 < args.length() => {
        index += 1
        oracle_image = args[index]
      }
      "--validate-only" => validate_only = true
      _ => {
        @stdio.stderr.write(usage() + "\n")
        @sys.exit(2)
        return
      }
    }
    index += 1
  }
  guard manifest_path is Some(manifest_path) else {
    @stdio.stderr.write(usage() + "\n")
    @sys.exit(2)
    return
  }
  let manifest : Manifest = @json.from_json(
    @json.parse(@fs.read_file(manifest_path).text()),
  ) catch {
    err => {
      @stdio.stderr.write("oracle-runner: cannot read manifest: \{err}\n")
      @sys.exit(2)
      return
    }
  }
  let failures = validate_manifest(manifest)
  if !failures.is_empty() {
    for failure in failures {
      @stdio.stderr.write("FAIL: " + failure + "\n")
    }
    @sys.exit(1)
    return
  }
  if validate_only {
    @stdio.stdout.write(
      "Oracle manifest valid: \{manifest.commands.length()} commands, \{manifest.cases.length()} cases.\n",
    )
    return
  }
  guard bin_root is Some(bin_root) else {
    @stdio.stderr.write(usage() + "\n")
    @sys.exit(2)
    return
  }
  let bin_root = @fs.realpath(bin_root) catch {
    err => {
      @stdio.stderr.write("oracle-runner: invalid bin root: \{err}\n")
      @sys.exit(2)
      return
    }
  }
  for fixture in manifest.cases {
    failures.append(run_case(fixture, bin_root, oracle_image))
  }
  if !failures.is_empty() {
    for failure in failures {
      @stdio.stderr.write("FAIL: " + failure + "\n")
    }
    @sys.exit(1)
    return
  }
  @stdio.stdout.write(
    "Oracle comparison passed for \{manifest.cases.length()} cases.\n",
  )
}
