///|
fn usage() -> String {
  "Usage: compat-runner --bin-root DIR [--catalog-only] [--gnu-diff] [--stress]"
}

///|
fn fail(message : String, failures : Array[String]) -> Unit {
  failures.push(message)
}

///|
async fn check_catalog(
  bin_root : String,
  require_binaries : Bool,
  failures : Array[String],
) -> Unit {
  let catalog = @cli.command_catalog()
  if catalog.length() != 48 {
    fail("catalog: expected 48 commands, got \{catalog.length()}", failures)
  }
  let names : Map[String, Bool] = Map([])
  for contract in catalog {
    if names.contains(contract.name) {
      fail("catalog: duplicate command '\{contract.name}'", failures)
    }
    names[contract.name] = true
    if require_binaries {
      let path = @testkit.executable_path(bin_root, contract.name)
      if !@fs.exists(path) {
        fail("catalog: missing native binary '\{path}'", failures)
      }
    }
  }
}

///|
async fn expect(
  bin_root : String,
  command : String,
  args : Array[String],
  stdin : Bytes?,
  status : Int,
  stdout : Bytes,
  failures : Array[String],
) -> Unit {
  let path = @testkit.executable_path(bin_root, command)
  let result = @testkit.run(path, args, stdin?) catch {
    err => {
      fail("\{command}: failed to execute: \{err}", failures)
      return
    }
  }
  if result.status != status {
    fail(
      "\{command}: expected status \{status}, got \{result.status}; stderr=\{result.stderr.to_unchecked_string()}",
      failures,
    )
  }
  if !@testkit.bytes_equal(result.stdout, stdout) {
    fail(
      "\{command}: stdout mismatch; expected \{stdout}, got \{result.stdout}",
      failures,
    )
  }
}

///|
async fn expect_case(
  bin_root : String,
  command : String,
  args : Array[String],
  stdin : Bytes?,
  status : Int,
  stdout : Bytes,
  invoked : Map[String, Bool],
  failures : Array[String],
) -> Unit {
  invoked[command] = true
  expect(bin_root, command, args, stdin, status, stdout, failures)
}

///|
async fn expect_stdout_contains(
  bin_root : String,
  command : String,
  args : Array[String],
  needle : String,
  invoked : Map[String, Bool],
  failures : Array[String],
) -> Unit {
  invoked[command] = true
  let path = @testkit.executable_path(bin_root, command)
  let result = @testkit.run(path, args) catch {
    err => {
      fail("\{command}: failed to execute: \{err}", failures)
      return
    }
  }
  if result.status != 0 {
    fail(
      "\{command}: expected status 0, got \{result.status}; stderr=\{result.stderr}",
      failures,
    )
  }
  if !@testkit.contains_bytes(result.stdout, needle) {
    fail(
      "\{command}: stdout does not contain '\{needle}': \{result.stdout}",
      failures,
    )
  }
}

///|
async fn expect_failure(
  bin_root : String,
  command : String,
  args : Array[String],
  expected_status : Int,
  diagnostic : String,
  failures : Array[String],
  cwd? : String,
) -> Unit {
  let result = @testkit.run(
    @testkit.executable_path(bin_root, command),
    args,
    cwd?,
  ) catch {
    err => {
      fail("\{command}: failure case could not run: \{err}", failures)
      return
    }
  }
  if result.status != expected_status {
    fail(
      "\{command}: expected failure status \{expected_status}, got \{result.status}",
      failures,
    )
  }
  if !@testkit.contains_bytes(result.stderr, diagnostic) {
    fail(
      "\{command}: diagnostic missing '\{diagnostic}': \{result.stderr}",
      failures,
    )
  }
}

///|
async fn run_catalog_smoke(bin_root : String, failures : Array[String]) -> Unit {
  let invoked : Map[String, Bool] = Map([])
  expect_case(
    bin_root,
    "base64",
    ["-w0"],
    Some(b"hello world"),
    0,
    b"aGVsbG8gd29ybGQ=\n",
    invoked,
    failures,
  )
  expect_stdout_contains(
    bin_root,
    "basename",
    ["--help"],
    "Usage:",
    invoked,
    failures,
  )
  expect_case(
    bin_root,
    "cat",
    [],
    Some(b"\x00\xff\x01ok"),
    0,
    b"\x00\xff\x01ok",
    invoked,
    failures,
  )
  expect_stdout_contains(
    bin_root,
    "chmod",
    ["--help"],
    "Usage:",
    invoked,
    failures,
  )
  expect_stdout_contains(
    bin_root,
    "cmp",
    ["--help"],
    "Usage:",
    invoked,
    failures,
  )
  expect_stdout_contains(
    bin_root,
    "comm",
    ["--help"],
    "Usage:",
    invoked,
    failures,
  )
  expect_stdout_contains(
    bin_root,
    "cp",
    ["--help"],
    "Usage:",
    invoked,
    failures,
  )
  expect_stdout_contains(
    bin_root,
    "curl",
    ["--help"],
    "Usage:",
    invoked,
    failures,
  )
  expect_case(bin_root, "cut", ["-c1"], Some(b""), 0, b"", invoked, failures)
  expect_stdout_contains(
    bin_root,
    "dirname",
    ["--help"],
    "Usage:",
    invoked,
    failures,
  )
  expect_stdout_contains(
    bin_root,
    "echo",
    ["--help"],
    "Usage:",
    invoked,
    failures,
  )
  expect_case(bin_root, "env", ["-i"], None, 0, b"", invoked, failures)
  expect_case(bin_root, "false", [], None, 1, b"", invoked, failures)
  expect_stdout_contains(
    bin_root,
    "find",
    ["--help"],
    "Usage:",
    invoked,
    failures,
  )
  expect_stdout_contains(
    bin_root,
    "grep",
    ["--help"],
    "Usage:",
    invoked,
    failures,
  )
  expect_case(bin_root, "head", [], Some(b""), 0, b"", invoked, failures)
  expect_stdout_contains(
    bin_root,
    "join",
    ["--help"],
    "Usage:",
    invoked,
    failures,
  )
  expect_case(
    bin_root,
    "jq",
    ["-n", "-c", "null"],
    None,
    0,
    b"null\n",
    invoked,
    failures,
  )
  expect_stdout_contains(
    bin_root,
    "jqlog",
    ["--help"],
    "Usage:",
    invoked,
    failures,
  )
  expect_stdout_contains(
    bin_root,
    "ln",
    ["--help"],
    "Usage:",
    invoked,
    failures,
  )
  expect_stdout_contains(
    bin_root,
    "ls",
    ["--help"],
    "Usage:",
    invoked,
    failures,
  )
  expect_stdout_contains(
    bin_root,
    "make",
    ["--help"],
    "Usage:",
    invoked,
    failures,
  )
  expect_stdout_contains(
    bin_root,
    "mkdir",
    ["--help"],
    "Usage:",
    invoked,
    failures,
  )
  expect_stdout_contains(
    bin_root,
    "mv",
    ["--help"],
    "Usage:",
    invoked,
    failures,
  )
  expect_case(bin_root, "nl", [], Some(b""), 0, b"", invoked, failures)
  expect_case(bin_root, "paste", [], Some(b""), 0, b"", invoked, failures)
  expect_stdout_contains(
    bin_root,
    "printenv",
    ["--help"],
    "Usage:",
    invoked,
    failures,
  )
  expect_case(
    bin_root,
    "printf",
    ["%s=%d\n", "answer", "42"],
    None,
    0,
    b"answer=42\n",
    invoked,
    failures,
  )
  expect_stdout_contains(
    bin_root,
    "pwd",
    ["--help"],
    "Usage:",
    invoked,
    failures,
  )
  expect_stdout_contains(
    bin_root,
    "rm",
    ["--help"],
    "Usage:",
    invoked,
    failures,
  )
  expect_stdout_contains(
    bin_root,
    "rmdir",
    ["--help"],
    "Usage:",
    invoked,
    failures,
  )
  expect_stdout_contains(
    bin_root,
    "seq",
    ["--help"],
    "Usage:",
    invoked,
    failures,
  )
  expect_stdout_contains(
    bin_root,
    "sha256sum",
    ["--help"],
    "Usage:",
    invoked,
    failures,
  )
  expect_case(bin_root, "sh", ["-c", ""], None, 0, b"", invoked, failures)
  expect_stdout_contains(
    bin_root,
    "sleep",
    ["--help"],
    "Usage:",
    invoked,
    failures,
  )
  expect_case(bin_root, "sort", [], Some(b""), 0, b"", invoked, failures)
  expect_case(bin_root, "tail", [], Some(b""), 0, b"", invoked, failures)
  expect_stdout_contains(
    bin_root,
    "tee",
    ["--help"],
    "Usage:",
    invoked,
    failures,
  )
  expect_stdout_contains(
    bin_root,
    "test",
    ["--help"],
    "Usage:",
    invoked,
    failures,
  )
  expect_stdout_contains(
    bin_root,
    "timeout",
    ["--help"],
    "Usage:",
    invoked,
    failures,
  )
  expect_stdout_contains(
    bin_root,
    "touch",
    ["--help"],
    "Usage:",
    invoked,
    failures,
  )
  expect_case(bin_root, "tr", ["a", "b"], Some(b""), 0, b"", invoked, failures)
  expect_case(bin_root, "true", [], None, 0, b"", invoked, failures)
  expect_case(bin_root, "uniq", [], Some(b""), 0, b"", invoked, failures)
  expect_case(
    bin_root,
    "wc",
    ["-l"],
    Some(b"a\r\nb\n"),
    0,
    b"2\n",
    invoked,
    failures,
  )
  expect_stdout_contains(
    bin_root,
    "wget",
    ["--help"],
    "Usage:",
    invoked,
    failures,
  )
  expect_case(
    bin_root,
    "xargs",
    ["-r", "echo"],
    Some(b""),
    0,
    b"",
    invoked,
    failures,
  )
  expect_case(bin_root, "xxd", [], Some(b""), 0, b"", invoked, failures)
  for contract in @cli.command_catalog() {
    if !invoked.contains(contract.name) {
      fail("\{contract.name}: catalog command was not executed", failures)
    }
  }
}

///|
async fn run_option_boundaries(
  bin_root : String,
  failures : Array[String],
) -> Unit {
  expect(
    bin_root,
    "dirname",
    ["-zz", "/alpha/beta"],
    None,
    0,
    b"/alpha\x00",
    failures,
  )
  expect(bin_root, "dirname", ["--", "-operand"], None, 0, b".\n", failures)
  expect_failure(
    bin_root,
    "printenv",
    ["--unknown"],
    2,
    "unknown option",
    failures,
  )
  expect_failure(
    bin_root,
    "touch",
    ["--no-create=value"],
    2,
    "does not accept a value",
    failures,
  )
  expect_failure(
    bin_root,
    "base64",
    ["--wrap=-1"],
    2,
    "invalid wrap size",
    failures,
  )
  expect_failure(bin_root, "cut", ["-d::", "-f1"], 2, "single byte", failures)
  expect_failure(bin_root, "comm", ["-", "-"], 2, "both inputs", failures)
  expect_failure(
    bin_root,
    "paste",
    ["-", "-"],
    2,
    "standard input may be specified only once",
    failures,
  )
  expect_failure(
    bin_root,
    "tr",
    ["a", "b", "ignored"],
    2,
    "extra operand",
    failures,
  )
}

///|
async fn run_environment_boundary_cases(
  bin_root : String,
  failures : Array[String],
) -> Unit {
  let secret_name = "MOOXCLI_COMPAT_SECRET"
  let secret_value = "must-cross-native-process-boundary"
  let injected : Map[String, String] = Map([(secret_name, secret_value)])
  let sh = @testkit.run(
    @testkit.executable_path(bin_root, "sh"),
    ["-c", "export"],
    extra_env=injected,
  ) catch {
    err => {
      fail("sh: environment boundary case failed to run: \{err}", failures)
      return
    }
  }
  record_result(
    sh.status == 0 && @testkit.contains_bytes(sh.stdout, secret_value),
    "sh: parent environment variable did not cross the native shell boundary",
    failures,
  )

  let root = @fs.tmpdir(prefix="mooncmd-environment")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let makefile = @path.Path(root).join(Path("Makefile")).to_string()
  @fs.write_file(makefile, b"all:\n\t@export\n")
  let make = @testkit.run(
    @testkit.executable_path(bin_root, "make"),
    ["-s", "-f", makefile],
    extra_env=injected,
  ) catch {
    err => {
      fail("make: environment boundary case failed to run: \{err}", failures)
      return
    }
  }
  record_result(
    make.status == 0 && @testkit.contains_bytes(make.stdout, secret_value),
    "make: parent environment variable did not cross the native recipe boundary",
    failures,
  )

  let printenv = @testkit.executable_path(bin_root, "printenv")
  let xargs = @testkit.run(
    @testkit.executable_path(bin_root, "xargs"),
    [printenv, secret_name],
    stdin=b"",
    extra_env=injected,
  ) catch {
    err => {
      fail("xargs: environment boundary case failed to run: \{err}", failures)
      return
    }
  }
  record_result(
    xargs.status == 0 && @testkit.contains_bytes(xargs.stdout, secret_value),
    "xargs: parent environment variable did not cross the native child boundary",
    failures,
  )

  let env = @testkit.run(
    @testkit.executable_path(bin_root, "env"),
    ["printenv", secret_name],
    extra_env=injected,
  ) catch {
    err => {
      fail("env: environment boundary case failed to run: \{err}", failures)
      return
    }
  }
  record_result(
    env.status == 0 && @testkit.contains_bytes(env.stdout, secret_value),
    "env: parent environment variable did not cross the native child boundary",
    failures,
  )
}

///|
async fn run_filesystem_cases(
  bin_root : String,
  failures : Array[String],
) -> Unit {
  let root = @fs.tmpdir(prefix="mooncmd-compat-fs")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let source = @path.Path(root).join(Path("source")).to_string()
  let copy = @path.Path(root).join(Path("copy")).to_string()
  let moved = @path.Path(root).join(Path("moved")).to_string()
  @fs.write_file(source, b"policy-fixture\n")
  let cp = @testkit.run(@testkit.executable_path(bin_root, "cp"), [source, copy]) catch {
    err => {
      fail("cp: filesystem case failed to run: \{err}", failures)
      return
    }
  }
  record_result(cp.status == 0, "cp: regular file copy failed", failures)
  record_result(
    @fs.read_file(copy).binary() == b"policy-fixture\n",
    "cp: copied bytes mismatch",
    failures,
  )
  let mv = @testkit.run(@testkit.executable_path(bin_root, "mv"), [copy, moved]) catch {
    err => {
      fail("mv: filesystem case failed to run: \{err}", failures)
      return
    }
  }
  record_result(mv.status == 0, "mv: rename failed", failures)
  record_result(
    !@fs.exists(copy) && @fs.exists(moved),
    "mv: rename side effects mismatch",
    failures,
  )
  let directory = @path.Path(root).join(Path("tree")).to_string()
  let child = @path.Path(directory).join(Path("child")).to_string()
  let nested = @path.Path(child).join(Path("copy")).to_string()
  @fs.mkdir(child, recursive=true)
  @fs.write_file(@path.Path(directory).join(Path("file")).to_string(), b"x")
  let nested_copy = @testkit.run(@testkit.executable_path(bin_root, "cp"), [
    "-R", directory, nested,
  ]) catch {
    err => {
      fail("cp: nested case failed to run: \{err}", failures)
      return
    }
  }
  record_result(
    nested_copy.status != 0 &&
    @testkit.contains_bytes(nested_copy.stderr, "inside the source"),
    "cp: nested destination was not stably rejected: status=\{nested_copy.status}, stderr=\{nested_copy.stderr}",
    failures,
  )
  let dash = @path.Path(root).join(Path("-dash")).to_string()
  @fs.write_file(dash, b"dash")
  let rm_dash = @testkit.run(
    @testkit.executable_path(bin_root, "rm"),
    ["--", "-dash"],
    cwd=root,
  ) catch {
    err => {
      fail("rm: -- operand case failed to run: \{err}", failures)
      return
    }
  }
  record_result(
    rm_dash.status == 0 && !@fs.exists(dash),
    "rm: -- did not protect dash-prefixed operand parsing",
    failures,
  )
  let guarded_dir = @path.Path(root).join(Path("protected")).to_string()
  @fs.mkdir(guarded_dir)
  @fs.write_file(
    @path.Path(guarded_dir).join(Path("kept")).to_string(),
    b"safe",
  )
  let protected_rm = @testkit.run(
    @testkit.executable_path(bin_root, "rm"),
    ["-r", "."],
    cwd=guarded_dir,
  ) catch {
    err => {
      fail("rm: protected path case failed to run: \{err}", failures)
      return
    }
  }
  record_result(
    protected_rm.status != 0 &&
    @testkit.contains_bytes(protected_rm.stderr, "protected path") &&
    @fs.exists(@path.Path(guarded_dir).join(Path("kept")).to_string()),
    "rm: current-directory protection failed",
    failures,
  )
  let link = @path.Path(root).join(Path("link")).to_string()
  if @platform.symbolic_links_supported() {
    let ln = @testkit.run(@testkit.executable_path(bin_root, "ln"), [
      "-s", source, link,
    ]) catch {
      err => {
        fail("ln: filesystem case failed to run: \{err}", failures)
        return
      }
    }
    record_result(
      ln.status == 0 && @fs.exists(link),
      "ln: symlink creation failed",
      failures,
    )
    let rm_link = @testkit.run(@testkit.executable_path(bin_root, "rm"), [
      "-r", link,
    ]) catch {
      err => {
        fail("rm: symlink case failed to run: \{err}", failures)
        return
      }
    }
    record_result(
      rm_link.status == 0 && @fs.exists(source) && !@fs.exists(link),
      "rm: recursive symlink removal followed the target",
      failures,
    )
  } else {
    expect_failure(
      bin_root,
      "ln",
      ["-s", source, link],
      1,
      "unsupported capability",
      failures,
    )
    expect_failure(
      bin_root,
      "chmod",
      ["600", source],
      1,
      "unsupported capability",
      failures,
    )
  }
}

///|
fn record_result(
  condition : Bool,
  message : String,
  failures : Array[String],
) -> Unit {
  if !condition {
    fail(message, failures)
  }
}

///|
fn patterned_bytes(length : Int) -> Bytes {
  let data : Array[Byte] = []
  for index = 0; index < length; index = index + 1 {
    data.push((index & 0xFF).to_byte())
  }
  Bytes::from_array(data)
}

///|
async fn expect_round_trip(
  bin_root : String,
  command : String,
  encode_args : Array[String],
  decode_args : Array[String],
  input : Bytes,
  failures : Array[String],
) -> Unit {
  let executable = @testkit.executable_path(bin_root, command)
  let encoded = @testkit.run(executable, encode_args, stdin=input) catch {
    err => {
      fail("\{command}: encoder failed to run: \{err}", failures)
      return
    }
  }
  if encoded.status != 0 {
    fail(
      "\{command}: encoder returned \{encoded.status}: \{encoded.stderr}",
      failures,
    )
    return
  }
  let decoded = @testkit.run(executable, decode_args, stdin=encoded.stdout) catch {
    err => {
      fail("\{command}: decoder failed to run: \{err}", failures)
      return
    }
  }
  record_result(
    decoded.status == 0 && @testkit.bytes_equal(decoded.stdout, input),
    "\{command}: chunk-boundary round trip failed: status=\{decoded.status}, stderr=\{decoded.stderr}",
    failures,
  )
}

///|
async fn run_chunk_boundary_cases(
  bin_root : String,
  failures : Array[String],
) -> Unit {
  for length in [65535, 65536, 65537] {
    let input = patterned_bytes(length)
    expect_round_trip(bin_root, "base64", ["-w0"], ["-d"], input, failures)
    expect_round_trip(bin_root, "xxd", ["-p"], ["-r", "-p"], input, failures)
  }
  expect(
    bin_root,
    "tr",
    ["-s", "a"],
    Some(Bytes::make(65537, b'a')),
    0,
    b"a",
    failures,
  )
}

///|
async fn run_merge_cases(bin_root : String, failures : Array[String]) -> Unit {
  let root = @fs.tmpdir(prefix="mooncmd-compat-merge")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let left = @path.Path(root).join(Path("left")).to_string()
  let right = @path.Path(root).join(Path("right")).to_string()
  @fs.write_file(left, b"a\nb\nc\n")
  @fs.write_file(right, b"b\nc\nd\n")
  let comm = @testkit.run(@testkit.executable_path(bin_root, "comm"), [
    "-23", left, right,
  ]) catch {
    err => {
      fail("comm: merge case failed to run: \{err}", failures)
      return
    }
  }
  record_result(
    comm.status == 0 && @testkit.bytes_equal(comm.stdout, b"a\n"),
    "comm: incremental merge output mismatch",
    failures,
  )
  @fs.write_file(left, b"1 alice\n2 bob\n")
  @fs.write_file(right, b"1 red\n2 blue\n")
  let join = @testkit.run(@testkit.executable_path(bin_root, "join"), [
    left, right,
  ]) catch {
    err => {
      fail("join: merge case failed to run: \{err}", failures)
      return
    }
  }
  record_result(
    join.status == 0 &&
    @testkit.bytes_equal(join.stdout, b"1 alice red\n2 bob blue\n"),
    "join: incremental merge output mismatch",
    failures,
  )
  @fs.write_file(left, b"1\n2\n")
  @fs.write_file(right, b"a\nb\n")
  let paste = @testkit.run(@testkit.executable_path(bin_root, "paste"), [
    "-d,", left, right,
  ]) catch {
    err => {
      fail("paste: merge case failed to run: \{err}", failures)
      return
    }
  }
  record_result(
    paste.status == 0 && @testkit.bytes_equal(paste.stdout, b"1,a\n2,b\n"),
    "paste: incremental merge output mismatch",
    failures,
  )
}

///|
async fn run_edge_cases(bin_root : String, failures : Array[String]) -> Unit {
  expect(
    bin_root,
    "wc",
    ["-c"],
    Some(Bytes::make(65536, b'x')),
    0,
    b"65536\n",
    failures,
  )
  expect(
    bin_root,
    "cut",
    ["-c1"],
    Some(b"\x00abc\n\xfftail"),
    0,
    b"\x00\n\xff\n",
    failures,
  )
  expect(
    bin_root,
    "uniq",
    [],
    Some(b"\xffsame\n\xffsame"),
    0,
    b"\xffsame\n",
    failures,
  )
  expect(
    bin_root,
    "nl",
    ["-ba", "-w1", "-s:"],
    Some(b"\x00\nlast"),
    0,
    b"1:\x00\n2:last\n",
    failures,
  )
  expect(bin_root, "base64", ["-d"], Some(b"YQ== \r\n\t"), 0, b"a", failures)
  expect(bin_root, "base64", ["-d"], Some(b"YQ==YQ=="), 1, b"", failures)
}

///|
async fn run_stdin_prompt_cases(
  bin_root : String,
  failures : Array[String],
) -> Unit {
  for
    command in [
      "base64", "cat", "head", "nl", "paste", "sha256sum", "sh", "sort", "tail",
      "tee", "uniq", "wc", "xargs", "xxd",
    ] {
    let result = @testkit.run(
      @testkit.executable_path(bin_root, command),
      [],
      stdin=b"",
    ) catch {
      err => {
        fail("\{command}: redirected stdin case failed: \{err}", failures)
        continue
      }
    }
    record_result(
      result.status == 0 && result.stderr.is_empty(),
      "\{command}: redirected stdin emitted an interactive prompt",
      failures,
    )
  }
}

///|
async fn run_http_cases(bin_root : String, failures : Array[String]) -> Unit {
  @async.with_task_group <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    group.add_defer(() => server.close())
    group.spawn_bg(no_wait=true) <| () => {
      server.run_forever() <| ((request, _body, connection) => {
        match request.path {
          "/fixed" => {
            connection.send_response(200, "OK", extra_headers={
              "Content-Length": "5",
            })
            connection..write("hello").end_response()
          }
          "/chunked" => {
            connection.send_response(200, "OK")
            connection..write("slow-").flush()
            @async.sleep(5)
            connection..write("stream").end_response()
          }
          "/missing" =>
            connection
            ..send_response(404, "Not Found", extra_headers={
              "Content-Length": "0",
            })
            .end_response()
          "/stall" => {
            @async.sleep(200)
            connection..send_response(200, "OK").end_response()
          }
          _ => connection..send_response(400, "Bad Request").end_response()
        }
      })
    }
    let base = "http://127.0.0.1:\{server.addr.port()}"
    let wget = @testkit.executable_path(bin_root, "wget")
    let curl = @testkit.executable_path(bin_root, "curl")
    let wget_fixed = @testkit.run(wget, ["-O", "-", base + "/fixed"])
    record_result(
      wget_fixed.status == 0 &&
      @testkit.bytes_equal(wget_fixed.stdout, b"hello") &&
      @testkit.contains_bytes(wget_fixed.stderr, "starting download") &&
      @testkit.contains_bytes(wget_fixed.stderr, "downloaded 5 bytes"),
      "wget: fixed-length response or progress feedback mismatch",
      failures,
    )
    let wget_quiet = @testkit.run(wget, ["-q", "-O", "-", base + "/fixed"])
    record_result(
      wget_quiet.status == 0 &&
      @testkit.bytes_equal(wget_quiet.stdout, b"hello") &&
      wget_quiet.stderr.is_empty(),
      "wget: -q did not suppress progress",
      failures,
    )
    let wget_missing = @testkit.run(wget, ["-O", "-", base + "/missing"])
    record_result(
      wget_missing.status == 1 &&
      wget_missing.stdout.is_empty() &&
      @testkit.contains_bytes(wget_missing.stderr, "HTTP status 404 Not Found"),
      "wget: HTTP error behavior mismatch",
      failures,
    )
    let wget_quiet_missing = @testkit.run(wget, [
      "-q",
      "-O",
      "-",
      base + "/missing",
    ])
    record_result(
      wget_quiet_missing.status == 1 &&
      wget_quiet_missing.stdout.is_empty() &&
      @testkit.contains_bytes(
        wget_quiet_missing.stderr,
        "HTTP status 404 Not Found",
      ),
      "wget: -q hid an HTTP error",
      failures,
    )
    let curl_chunked = @testkit.run(curl, [base + "/chunked"])
    record_result(
      curl_chunked.status == 0 &&
      @testkit.bytes_equal(curl_chunked.stdout, b"slow-stream") &&
      @testkit.contains_bytes(curl_chunked.stderr, "downloaded 11 bytes"),
      "curl: unknown-length response or progress feedback mismatch",
      failures,
    )
    let curl_silent = @testkit.run(curl, ["-s", "-f", base + "/missing"])
    record_result(
      curl_silent.status == 1 && curl_silent.stderr.is_empty(),
      "curl: -s did not suppress errors",
      failures,
    )
    let curl_show_error = @testkit.run(curl, ["-sS", "-f", base + "/missing"])
    record_result(
      curl_show_error.status == 1 &&
      @testkit.contains_bytes(
        curl_show_error.stderr,
        "HTTP status 404 Not Found",
      ),
      "curl: -sS did not restore the HTTP error",
      failures,
    )
    let output_root = @fs.tmpdir(prefix="mooncmd-http")
    defer (@fs.rmdir(output_root, recursive=true) catch { _ => () })
    let output = @path.Path(output_root).join(Path("response")).to_string()
    let wget_log = @path.Path(output_root).join(Path("wget.log")).to_string()
    let wget_logged = @testkit.run(wget, [
      "-o",
      wget_log,
      "-O",
      "-",
      base + "/fixed",
    ])
    record_result(
      wget_logged.status == 0 &&
      @testkit.bytes_equal(wget_logged.stdout, b"hello") &&
      wget_logged.stderr.is_empty() &&
      @testkit.contains_bytes(
        @fs.read_file(wget_log).binary(),
        "starting download",
      ) &&
      @testkit.contains_bytes(
        @fs.read_file(wget_log).binary(),
        "downloaded 5 bytes",
      ),
      "wget: -o did not route diagnostics to its log",
      failures,
    )
    let curl_file = @testkit.run(curl, ["-s", "-o", output, base + "/fixed"])
    record_result(
      curl_file.status == 0 &&
      curl_file.stdout.is_empty() &&
      @testkit.bytes_equal(@fs.read_file(output).binary(), b"hello"),
      "curl: file output mismatch",
      failures,
    )
    let curl_timeout = @testkit.run(curl, [
      "--idle-timeout",
      "0.02",
      base + "/stall",
    ])
    record_result(
      curl_timeout.status == 1 &&
      @testkit.contains_bytes(curl_timeout.stderr, "timed out after 20"),
      "curl: idle timeout did not fail promptly",
      failures,
    )
  }
}

///|
async fn run_stress_cases(bin_root : String, failures : Array[String]) -> Unit {
  for size in [1048576, 16777216, 67108864] {
    expect(
      bin_root,
      "wc",
      ["-c"],
      Some(Bytes::make(size, b'x')),
      0,
      @utf8.encode("\{size}\n"),
      failures,
    )
  }
  expect(
    bin_root,
    "wc",
    ["-l"],
    Some(Bytes::make(1000000, b'\n')),
    0,
    b"1000000\n",
    failures,
  )
}

///|
async fn compare_gnu(
  bin_root : String,
  command : String,
  args : Array[String],
  stdin : Bytes,
  failures : Array[String],
) -> Unit {
  let candidate = @testkit.run(
    @testkit.executable_path(bin_root, command),
    args,
    stdin~,
    extra_env=Map([("LC_ALL", "C")]),
  ) catch {
    err => {
      fail("\{command}: candidate differential run failed: \{err}", failures)
      return
    }
  }
  let oracle = @testkit.run(
    command,
    args,
    stdin~,
    extra_env=Map([("LC_ALL", "C")]),
  ) catch {
    err => {
      fail("\{command}: GNU oracle failed: \{err}", failures)
      return
    }
  }
  if candidate.status != oracle.status {
    fail(
      "\{command}: GNU status mismatch: candidate=\{candidate.status}, oracle=\{oracle.status}",
      failures,
    )
  }
  if !@testkit.bytes_equal(candidate.stdout, oracle.stdout) {
    fail(
      "\{command}: GNU stdout mismatch: candidate=\{candidate.stdout}, oracle=\{oracle.stdout}",
      failures,
    )
  }
}

///|
async fn run_gnu_differential(
  bin_root : String,
  failures : Array[String],
) -> Unit {
  compare_gnu(bin_root, "base64", [], b"hello world", failures)
  compare_gnu(bin_root, "cat", [], b"\x00\xfftext\n", failures)
  compare_gnu(bin_root, "cut", ["-d,", "-f1,3"], b"x,y,z\n1,2,3\n", failures)
  compare_gnu(bin_root, "head", ["-n", "2"], b"1\n2\n3\n", failures)
  compare_gnu(bin_root, "sha256sum", [], b"hello world", failures)
  compare_gnu(bin_root, "sort", ["-n"], b"10\n2\n1\n", failures)
  compare_gnu(bin_root, "tail", ["-n", "2"], b"1\n2\n3\n", failures)
  compare_gnu(bin_root, "tr", ["a-z", "A-Z"], b"hello world\n", failures)
}

///|
async fn main {
  let args = @env.args()[1:]
  let mut bin_root : String? = None
  let mut catalog_only = false
  let mut gnu_diff = false
  let mut stress = false
  let mut index = 0
  while index < args.length() {
    match args[index] {
      "--bin-root" => {
        index += 1
        if index >= args.length() {
          @stdio.stderr.write(usage() + "\n")
          @sys.exit(2)
          return
        }
        bin_root = Some(args[index])
      }
      "--catalog-only" => catalog_only = true
      "--gnu-diff" => gnu_diff = true
      "--stress" => stress = true
      _ => {
        @stdio.stderr.write(usage() + "\n")
        @sys.exit(2)
        return
      }
    }
    index += 1
  }
  let root = match bin_root {
    Some(root) =>
      @fs.realpath(root) catch {
        err => {
          @stdio.stderr.write(
            "compat-runner: invalid bin root '\{root}': \{err}\n",
          )
          @sys.exit(2)
          return
        }
      }
    None => {
      @stdio.stderr.write(usage() + "\n")
      @sys.exit(2)
      return
    }
  }
  let failures : Array[String] = []
  check_catalog(root, !catalog_only, failures)
  if !catalog_only && failures.is_empty() {
    run_catalog_smoke(root, failures)
    run_option_boundaries(root, failures)
    run_environment_boundary_cases(root, failures)
    run_filesystem_cases(root, failures)
    run_chunk_boundary_cases(root, failures)
    run_merge_cases(root, failures)
    run_edge_cases(root, failures)
    run_stdin_prompt_cases(root, failures)
    run_http_cases(root, failures)
    if gnu_diff {
      run_gnu_differential(root, failures)
    }
    if stress {
      run_stress_cases(root, failures)
    }
  }
  if !failures.is_empty() {
    for failure in failures {
      @stdio.stderr.write("FAIL: " + failure + "\n")
    }
    @sys.exit(1)
    return
  }
  @stdio.stdout.write("Compatibility checks passed for 48 commands.\n")
}
