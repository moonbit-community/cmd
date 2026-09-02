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
async fn ensure_directory(path : String) -> Unit {
  if !@fs.exists(path) {
    @fs.mkdir(path, recursive=true)
  }
}

///|
fn expand_fixture_content(content : Bytes, http_base? : String) -> Bytes {
  guard http_base is Some(base) else { return content }
  let text = @utf8.decode(content) catch { _ => return content }
  if !text.contains("${HTTP_BASE}") {
    return content
  }
  @utf8.encode(text.replace_all(old="${HTTP_BASE}", new=base))
}

///|
async fn prepare_directory(
  root : String,
  fixture : OracleCase,
  http_base? : String,
) -> Unit {
  for file in fixture.files {
    let destination = @path.Path(root).join(Path(file.path)).to_string()
    let parent = @path.Path(destination).dirname().to_string()
    ensure_directory(parent)
    let content = expand_fixture_content(
      decode_hex(file.content_hex, fixture.id + " file " + file.path),
      http_base?,
    )
    @fs.write_file(destination, content)
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
fn oracle_request_name(request : @http.Request) -> String {
  match request.meth {
    Get => "GET"
    Head => "HEAD"
    Post => "POST"
    Put => "PUT"
    Delete => "DELETE"
    Connect => "CONNECT"
    Options => "OPTIONS"
    Trace => "TRACE"
    Patch => "PATCH"
  }
}

///|
async fn run_http_fixture(server : @http.Server) -> Unit {
  server.run_forever() <| ((request, body, connection) => {
    match request.path {
      "/fixed" | "/named.txt" => {
        connection.send_response(200, "OK", extra_headers={
          "Content-Length": "5",
        })
        if request.meth == @http.Head {
          connection.end_response()
        } else {
          connection..write("hello").end_response()
        }
      }
      "/second" => {
        connection.send_response(200, "OK", extra_headers={
          "Content-Length": "5",
        })
        connection..write("world").end_response()
      }
      "/redirect" =>
        connection
        ..send_response(302, "Found", extra_headers={
          "Location": "/fixed",
          "Content-Length": "0",
        })
        .end_response()
      "/redirect-echo" =>
        connection
        ..send_response(307, "Temporary Redirect", extra_headers={
          "Location": "/echo",
          "Content-Length": "0",
        })
        .end_response()
      "/echo" => {
        let content = body.read_all().binary()
        let prefix = oracle_request_name(request) + ":"
        let response = @utf8.encode(prefix) + content
        connection.send_response(200, "OK", extra_headers={
          "Content-Length": response.length().to_string(),
        })
        connection..write(response).end_response()
      }
      "/missing" =>
        connection
        ..send_response(404, "Not Found", extra_headers={
          "Content-Length": "0",
        })
        .end_response()
      _ =>
        connection
        ..send_response(400, "Bad Request", extra_headers={
          "Content-Length": "0",
        })
        .end_response()
    }
  })
}

///|
async fn run_external_http_fixture() -> Int {
  let server = @http.Server(@socket.Addr::parse("0.0.0.0:0"))
  @stdio.stdout.write(server.addr.port().to_string() + "\n")
  run_http_fixture(server)
  0
}

///|
async fn spawn_http_fixture_process(
  group : @async.TaskGroup[Unit],
) -> (@process.Process, @process.ReadFromProcess, String) {
  let (port_reader, port_writer) = @process.read_from_process()
  let process = @process.spawn(
    group,
    @env.args()[0],
    ["--http-fixture-server"],
    stdout=port_writer,
    no_console_window=true,
    no_wait=true,
  )
  let line = port_reader.read_until("\n")
  guard line is Some(line) else {
    fail("oracle-runner: HTTP fixture process closed before reporting a port")
  }
  let port = @string.parse_int(line.trim().to_owned()) catch {
    err => fail("oracle-runner: invalid HTTP fixture port: \{err}")
  }
  (process, port_reader, "http://127.0.0.1:\{port}")
}

///|
async fn spawn_https_fixture_process(
  group : @async.TaskGroup[Unit],
  root : String,
) -> (@process.Process, String) {
  let cert = @fs.realpath("tests/fixtures/http/cert.pem")
  let key = @fs.realpath("tests/fixtures/http/key.pem")
  let fixture_root = @fs.realpath("tests/fixtures/http")
  let log = @path.Path(root).join(Path("https.log")).to_string()
  let output = @process.redirect_to_file(log)
  let process = @process.spawn(
    group,
    "openssl",
    ["s_server", "-accept", "127.0.0.1:0", "-cert", cert, "-key", key, "-WWW"],
    cwd=fixture_root,
    stdout=output,
    stderr=output,
    no_console_window=true,
    no_wait=true,
  )
  for attempt = 0; attempt < 200; attempt = attempt + 1 {
    if @fs.exists(log) {
      let text = @fs.read_file(log).text()
      if text.find("ACCEPT ") is Some(index) {
        let suffix = text[index + 7:].to_owned()
        let line = suffix.split("\n").next().unwrap_or("").trim().to_owned()
        if line.rev_find(":") is Some(colon) {
          let port = @string.parse_int(line[colon + 1:].to_owned()) catch {
            _ => 0
          }
          if port > 0 {
            return (process, "https://127.0.0.1:\{port}")
          }
        }
      }
    }
    @async.sleep(10)
  }
  process.cancel()
  ignore(process.wait()) catch {
    _ => ()
  }
  fail("oracle-runner: HTTPS fixture did not report a listening port")
}

///|
fn expand_fixture_args(
  args : ArrayView[String],
  http_base : String,
  https_base : String,
) -> Array[String] {
  args.map(arg => {
    arg
    .replace_all(old="${HTTP_BASE}", new=http_base)
    .replace_all(old="${HTTPS_BASE}", new=https_base)
  })
}

///|
async fn run_case(
  fixture : OracleCase,
  bin_root : String,
  oracle_image : String,
  http_base : String,
  https_base : String,
) -> Array[String] {
  let failures : Array[String] = []
  let root = @fs.tmpdir(prefix="mooncmd-oracle-\{fixture.id}-")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let candidate_root = @path.Path(root).join(Path("candidate")).to_string()
  let oracle_root = @path.Path(root).join(Path("oracle")).to_string()
  ensure_directory(candidate_root)
  ensure_directory(oracle_root)
  prepare_directory(candidate_root, fixture, http_base~)
  prepare_directory(oracle_root, fixture, http_base~)
  let stdin = decode_hex(fixture.stdin_hex, fixture.id + " stdin")
  let environment = controlled_environment(fixture.environment)
  let args = expand_fixture_args(fixture.args, http_base, https_base)
  let networked = fixture.args.any(arg => {
      arg.contains("${HTTP_BASE}") || arg.contains("${HTTPS_BASE}")
    }) ||
    fixture.files.any(file => {
      file.content_hex.to_lower().contains("247b485454505f424153457d")
    })
  let candidate = @testkit.run(
    @testkit.executable_path(bin_root, fixture.command),
    args,
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
    if networked {
      "host"
    } else {
      "none"
    },
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
  docker_args.append(args)
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
  if args.length() == 1 && args[0] == "--http-fixture-server" {
    let status = run_external_http_fixture()
    if status != 0 {
      @sys.exit(status)
    }
    return
  }
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
  let fixture_root = @fs.tmpdir(prefix="mooncmd-oracle-fixtures-")
  defer (@fs.rmdir(fixture_root, recursive=true) catch { _ => () })
  @async.with_task_group <| group => {
    let (process, reader, http_base) = spawn_http_fixture_process(group)
    let (tls_process, https_base) = spawn_https_fixture_process(
      group, fixture_root,
    )
    group.add_defer(() => {
      reader.close()
      process.cancel()
      ignore(process.wait()) catch {
        _ => ()
      }
      tls_process.cancel()
      ignore(tls_process.wait()) catch {
        _ => ()
      }
    })
    for fixture in manifest.cases {
      failures.append(
        run_case(fixture, bin_root, oracle_image, http_base, https_base),
      )
    }
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
