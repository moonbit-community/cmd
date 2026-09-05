///|

///|
fn compat_fail(message : String, failures : Array[String]) -> Unit {
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
    compat_fail(
      "catalog: expected 48 commands, got \{catalog.length()}",
      failures,
    )
  }
  let names : Map[String, Bool] = Map([])
  for contract in catalog {
    if names.contains(contract.name) {
      compat_fail("catalog: duplicate command '\{contract.name}'", failures)
    }
    names[contract.name] = true
    if require_binaries {
      let path = @testkit.executable_path(bin_root, contract.name)
      if !@fs.exists(path) {
        compat_fail("catalog: missing native binary '\{path}'", failures)
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
      compat_fail("\{command}: failed to execute: \{err}", failures)
      return
    }
  }
  if result.status != status {
    compat_fail(
      "\{command}: expected status \{status}, got \{result.status}; stderr=\{result.stderr.to_unchecked_string()}",
      failures,
    )
  }
  if !@testkit.bytes_equal(result.stdout, stdout) {
    compat_fail(
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
      compat_fail("\{command}: failed to execute: \{err}", failures)
      return
    }
  }
  if result.status != 0 {
    compat_fail(
      "\{command}: expected status 0, got \{result.status}; stderr=\{result.stderr}",
      failures,
    )
  }
  if !@testkit.contains_bytes(result.stdout, needle) {
    compat_fail(
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
      compat_fail("\{command}: failure case could not run: \{err}", failures)
      return
    }
  }
  if result.status != expected_status {
    compat_fail(
      "\{command}: expected failure status \{expected_status}, got \{result.status}",
      failures,
    )
  }
  if !@testkit.contains_bytes(result.stderr, diagnostic) {
    compat_fail(
      "\{command}: diagnostic missing '\{diagnostic}': \{result.stderr}",
      failures,
    )
  }
}

///|
/// Run a follow session against a set of regular files. The caller controls
/// the initial contents, one append pass, and an optional replacement pass;
/// the child is cancelled after both observations have had time to flush.
async fn run_tail_follow_process(
  program : String,
  args_prefix : Array[String],
  initial : Array[Bytes],
  append : Array[Bytes],
  replacement : Array[Bytes?],
  poll_wait_ms? : Int = 160,
) -> (Bytes, Bytes) {
  let root = @fs.tmpdir(prefix="mooncmd-tail-follow")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let paths : Array[String] = []
  for index in 0..<initial.length() {
    let path = @path.Path(root).join(Path("log-\{index}")).to_string()
    paths.push(path)
    @fs.write_file(path, initial[index])
  }
  let args = args_prefix.copy()
  args.append(paths)
  let stdout_path = @path.Path(root).join(Path("stdout")).to_string()
  let stderr_path = @path.Path(root).join(Path("stderr")).to_string()
  let stdout = @process.redirect_to_file(stdout_path)
  let stderr = @process.redirect_to_file(stderr_path)
  @async.with_task_group <| group => {
    let child = @process.spawn(
      group,
      program,
      args,
      stdout~,
      stderr~,
      cancel_handler=@process.hard_cancel(),
      no_wait=true,
    )
    @async.sleep(120)
    for index, path in paths {
      @fs.write_file(path, append[index], append=true, create_mode=OpenExisting)
    }
    @async.sleep(poll_wait_ms)
    let mut replaced = false
    for index, path in paths {
      match replacement[index] {
        Some(data) => {
          @fs.write_file(path, data)
          replaced = true
        }
        None => ()
      }
    }
    if replaced {
      @async.sleep(poll_wait_ms)
    }
    child.cancel()
    ignore(child.wait()) catch {
      _ => ()
    }
  }
  (@fs.read_file(stdout_path).binary(), @fs.read_file(stderr_path).binary())
}

///|
fn record_tail_follow_result(
  result : (Bytes, Bytes),
  expected_stdout : Bytes,
  label : String,
  failures : Array[String],
) -> Unit {
  if !@testkit.bytes_equal(result.0, expected_stdout) {
    compat_fail(
      "tail: \{label} stdout mismatch; expected \{expected_stdout}, got \{result.0}",
      failures,
    )
  }
  if result.1.length() != 0 {
    compat_fail("tail: \{label} wrote unexpected stderr: \{result.1}", failures)
  }
}

///|
async fn run_tail_follow_cases(
  bin_root : String,
  failures : Array[String],
) -> Unit {
  let tail = @testkit.executable_path(bin_root, "tail")
  let append_lines = run_tail_follow_process(
    tail,
    ["--follow", "--sleep-interval", "0.02", "-n", "2"],
    [b"one\ntwo\nthree\n"],
    [b"four\n"],
    [None],
  )
  record_tail_follow_result(
    append_lines, b"two\nthree\nfour\n", "line append", failures,
  )
  let append_bytes = run_tail_follow_process(
    tail,
    ["-f", "-s", "0.02", "-c", "2"],
    [b"abcdef"],
    [b"gh"],
    [None],
  )
  record_tail_follow_result(append_bytes, b"efgh", "byte append", failures)
  let no_newline = run_tail_follow_process(
    tail,
    ["-f", "-s", "0.02", "-n", "1"],
    [b"left"],
    [b"-right\n"],
    [None],
  )
  record_tail_follow_result(no_newline, b"left-right\n", "no newline", failures)
  let truncated = run_tail_follow_process(
    tail,
    ["-f", "-s", "0.02"],
    [b"before\n"],
    [b"append\n"],
    [Some(b"reset\n")],
  )
  record_tail_follow_result(
    truncated, b"before\nappend\nreset\n", "truncate recovery", failures,
  )
  let multiple = run_tail_follow_process(
    tail,
    ["-f", "-s", "0.02", "-q", "-n", "1"],
    [b"first\n", b"second\n"],
    [b"first-add\n", b"second-add\n"],
    [None, None],
  )
  record_tail_follow_result(
    multiple, b"first\nsecond\nfirst-add\nsecond-add\n", "multiple files", failures,
  )
  let with_headers = run_tail_follow_process(
    tail,
    ["-f", "-s", "0.02", "-v", "-n", "1"],
    [b"header-one\n", b"header-two\n"],
    [b"", b""],
    [None, None],
  )
  if !@testkit.contains_bytes(with_headers.0, "==> ") ||
    !@testkit.contains_bytes(with_headers.0, "header-one") ||
    !@testkit.contains_bytes(with_headers.0, "header-two") {
    compat_fail(
      "tail: verbose follow headers missing: \{with_headers.0}",
      failures,
    )
  }
  expect(
    bin_root,
    "tail",
    ["-f", "-s", "0.02", "-n", "2"],
    Some(b"one\ntwo\nthree\n"),
    0,
    b"two\nthree\n",
    failures,
  )
  expect(
    bin_root,
    "tail",
    ["-s", "0.02", "-n", "1"],
    Some(b"one\ntwo\n"),
    0,
    b"two\n",
    failures,
  )
  expect(
    bin_root,
    "tail",
    ["-s", "0", "-n", "1"],
    Some(b"zero\none\n"),
    0,
    b"one\n",
    failures,
  )
  let default_interval = run_tail_follow_process(
    tail,
    ["-f", "-q", "-n", "0"],
    [b""],
    [b"default\n"],
    [None],
    poll_wait_ms=1100,
  )
  record_tail_follow_result(
    default_interval, b"default\n", "default interval", failures,
  )
  expect_failure(
    bin_root,
    "tail",
    ["-f", "-s", "-1"],
    2,
    "invalid sleep interval",
    failures,
  )
  expect_failure(
    bin_root,
    "tail",
    ["-s", "inf"],
    2,
    "invalid sleep interval",
    failures,
  )
  expect_failure(bin_root, "tail", ["-F"], 2, "unknown short option", failures)
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
      compat_fail(
        "\{contract.name}: catalog command was not executed",
        failures,
      )
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
  expect(
    bin_root,
    "paste",
    ["-", "-"],
    Some(b"left\nright\n"),
    0,
    b"left\tright\n",
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
      compat_fail(
        "sh: environment boundary case failed to run: \{err}",
        failures,
      )
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
      compat_fail(
        "make: environment boundary case failed to run: \{err}",
        failures,
      )
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
      compat_fail(
        "xargs: environment boundary case failed to run: \{err}",
        failures,
      )
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
      compat_fail(
        "env: environment boundary case failed to run: \{err}",
        failures,
      )
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
      compat_fail("cp: filesystem case failed to run: \{err}", failures)
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
      compat_fail("mv: filesystem case failed to run: \{err}", failures)
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
      compat_fail("cp: nested case failed to run: \{err}", failures)
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
      compat_fail("rm: -- operand case failed to run: \{err}", failures)
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
      compat_fail("rm: protected path case failed to run: \{err}", failures)
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
        compat_fail("ln: filesystem case failed to run: \{err}", failures)
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
        compat_fail("rm: symlink case failed to run: \{err}", failures)
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
    compat_fail(message, failures)
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
      compat_fail("\{command}: encoder failed to run: \{err}", failures)
      return
    }
  }
  if encoded.status != 0 {
    compat_fail(
      "\{command}: encoder returned \{encoded.status}: \{encoded.stderr}",
      failures,
    )
    return
  }
  let decoded = @testkit.run(executable, decode_args, stdin=encoded.stdout) catch {
    err => {
      compat_fail("\{command}: decoder failed to run: \{err}", failures)
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
      compat_fail("comm: merge case failed to run: \{err}", failures)
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
      compat_fail("join: merge case failed to run: \{err}", failures)
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
      compat_fail("paste: merge case failed to run: \{err}", failures)
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
async fn run_phase345_cases(
  bin_root : String,
  failures : Array[String],
) -> Unit {
  let root = @fs.tmpdir(prefix="mooncmd-phase345")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let left = @path.Path(root).join(Path("left")).to_string()
  let right = @path.Path(root).join(Path("right")).to_string()
  @fs.write_file(left, b"a left\nb only-left\nc left-c\n")
  @fs.write_file(right, b"a right\nc right-c\nd only-right\n")
  let join = @testkit.run(@testkit.executable_path(bin_root, "join"), [
    "-a", "1", "-a", "2", "-e", "0", "-o", "0,1.2,2.2", left, right,
  ])
  record_result(
    join.status == 0 &&
    @testkit.bytes_equal(
      join.stdout,
      b"a left right\nb only-left 0\nc left-c right-c\nd 0 only-right\n",
    ),
    "join: unpaired/output-list behavior mismatch",
    failures,
  )
  expect(
    bin_root,
    "cat",
    ["-b", "-s", "-A"],
    Some(b"a\n\n\nb\t\x80"),
    0,
    b"     1\ta$\n$\n     2\tb^IM-^@",
    failures,
  )
  expect(
    bin_root,
    "xxd",
    ["-s", "4", "-l", "4"],
    Some(b"0123456789"),
    0,
    b"00000004: 3435 3637                                4567\n",
    failures,
  )
  expect(
    bin_root,
    "xxd",
    ["-r", "-p", "-s", "2"],
    Some(b"6162\n"),
    0,
    b"\x00\x00ab",
    failures,
  )
  let find = @testkit.run(@testkit.executable_path(bin_root, "find"), [
    root,
    "-maxdepth",
    "0",
    "-exec",
    @testkit.executable_path(bin_root, "false"),
    ";",
  ])
  record_result(
    find.status == 0 && find.stdout.is_empty(),
    "find: -exec false must not turn a successful traversal into status 1",
    failures,
  )
  let printf = @testkit.executable_path(bin_root, "printf")
  let batched_find = @testkit.run(@testkit.executable_path(bin_root, "find"), [
    root, "-maxdepth", "0", "-exec", printf, "%s\\n", "{}", "+",
  ])
  record_result(
    batched_find.status == 0 &&
    @testkit.bytes_equal(batched_find.stdout, @utf8.encode(root + "\n")),
    "find: -exec ... + batching mismatch",
    failures,
  )
  expect(
    bin_root,
    "xargs",
    ["-I{}", printf, "<%s>\\n", "{}"],
    Some(b"first line\nsecond line\n"),
    0,
    b"<first line>\n<second line>\n",
    failures,
  )
  expect(
    bin_root,
    "xargs",
    ["-L", "1", printf, "[%s]\\n"],
    Some(b"a b\nc d\n"),
    0,
    b"[a]\n[b]\n[c]\n[d]\n",
    failures,
  )
  expect(
    bin_root,
    "xargs",
    ["-E", "STOP", printf, "[%s]\\n"],
    Some(b"a STOP b\n"),
    0,
    b"[a]\n",
    failures,
  )
  expect(
    bin_root,
    "xargs",
    ["--show-limits"],
    None,
    0,
    b"max-args-bytes: 65536\n",
    failures,
  )
  expect(
    bin_root,
    "xargs",
    [@testkit.executable_path(bin_root, "false")],
    Some(b"value\n"),
    123,
    b"",
    failures,
  )
  expect(
    bin_root,
    "env",
    ["-i", "-0", "B=2", "A=1"],
    None,
    0,
    b"B=2\x00A=1\x00",
    failures,
  )
  let work = @path.Path(root).join(Path("work")).to_string()
  @fs.mkdir(work)
  let env = @testkit.run(
    @testkit.executable_path(bin_root, "env"),
    ["-C", work, @testkit.executable_path(bin_root, "printenv"), "PHASE345"],
    extra_env=Map([("PHASE345", "visible")]),
  )
  record_result(
    env.status == 0 && @testkit.bytes_equal(env.stdout, b"visible\n"),
    "env: -C child execution mismatch",
    failures,
  )
  @fs.write_file(
    @path.Path(work).join(Path("common.mk")).to_string(),
    b"VALUE = included\n",
  )
  @fs.write_file(
    @path.Path(work).join(Path("Makefile")).to_string(),
    b"include common.mk\nVALUE = local\nall:\n\t@printf '%s\\n' '$(VALUE)'\n",
  )
  let make = @testkit.run(@testkit.executable_path(bin_root, "make"), [
    "-s", "-C", work, "VALUE=cli",
  ])
  record_result(
    make.status == 0 && @testkit.bytes_equal(make.stdout, b"cli\n"),
    "make: include or command-line variable precedence mismatch",
    failures,
  )
  expect(
    bin_root,
    "sh",
    ["-s", "shell-name", "value"],
    Some(b"printf '%s|%s\\n' \"$0\" \"$1\"\n"),
    0,
    b"sh|shell-name\n",
    failures,
  )
  let absent_copy = @path.Path(root).join(Path("preserved-copy")).to_string()
  let cp = @testkit.run(@testkit.executable_path(bin_root, "cp"), [
    "-p", left, absent_copy,
  ])
  record_result(
    cp.status == 1 && !@fs.exists(absent_copy),
    "cp: unsupported metadata preservation must fail before creating output",
    failures,
  )
  let absent_touch = @path.Path(root).join(Path("dated")).to_string()
  let touch = @testkit.run(@testkit.executable_path(bin_root, "touch"), [
    "-d", "2020-01-01", absent_touch,
  ])
  record_result(
    touch.status == 1 && !@fs.exists(absent_touch),
    "touch: unsupported timestamp selection must fail before creating output",
    failures,
  )
  let chmod = @testkit.run(@testkit.executable_path(bin_root, "chmod"), [
    "--reference=" + left,
    right,
  ])
  record_result(
    chmod.status == 1 &&
    @testkit.contains_bytes(chmod.stderr, "cannot read permission bits"),
    "chmod: --reference must fail through the explicit capability path",
    failures,
  )
}

///|
async fn run_p5_sh_cases(bin_root : String, failures : Array[String]) -> Unit {
  expect(
    bin_root,
    "sh",
    ["-c", "printf '%s\\n' \"$(printf inner)\""],
    None,
    0,
    b"inner\n",
    failures,
  )
  expect(
    bin_root,
    "sh",
    ["-c", "cat <<EOF\nheredoc\nEOF"],
    None,
    0,
    b"heredoc\n",
    failures,
  )
  expect(
    bin_root,
    "sh",
    ["-c", "if false; then printf no; else printf yes; fi"],
    None,
    0,
    b"yes",
    failures,
  )
  expect(
    bin_root,
    "sh",
    ["-c", "case flower in f*) printf match;; *) printf no;; esac"],
    None,
    0,
    b"match",
    failures,
  )
  expect(
    bin_root,
    "sh",
    ["-c", "for x in a b; do printf '%s' \"$x\"; done"],
    None,
    0,
    b"ab",
    failures,
  )
  expect(
    bin_root,
    "sh",
    [
      "-c", "while false; do printf no; done; until true; do printf no; done; printf yes",
    ],
    None,
    0,
    b"yes",
    failures,
  )
  expect(
    bin_root,
    "sh",
    ["-c", "f() { printf '%s' \"$1\"; return 7; }; f ok"],
    None,
    7,
    b"ok",
    failures,
  )
  expect(
    bin_root,
    "sh",
    ["-c", "(printf one); { printf two; }"],
    None,
    0,
    b"onetwo",
    failures,
  )
  expect(
    bin_root,
    "sh",
    ["-c", "VALUE=abcd; printf '%s' \"${#VALUE}\""],
    None,
    0,
    b"4",
    failures,
  )
  expect(
    bin_root,
    "sh",
    ["-c", "set -- first second; shift; printf '%s' \"$1\""],
    None,
    0,
    b"second",
    failures,
  )
  expect_failure(
    bin_root,
    "sh",
    ["-c", "set -e; false; printf no"],
    1,
    "",
    failures,
  )
  expect_failure(
    bin_root,
    "sh",
    ["-c", "set -u; printf '%s' \"$MISSING\""],
    2,
    "unset",
    failures,
  )
}

///|
async fn run_p2_p3_cases(bin_root : String, failures : Array[String]) -> Unit {
  expect(
    bin_root,
    "grep",
    ["-n", "-b", "-C1", "hit"],
    Some(b"a\nhit\nc\nd\ne\nhit\ng\n"),
    0,
    b"1-0-a\n2:2:hit\n3-6-c\n--\n5-10-e\n6:12:hit\n7-16-g\n",
    failures,
  )
  expect(
    bin_root,
    "grep",
    ["-A0", "-A1", "hit"],
    Some(b"a\nhit\nc\n"),
    0,
    b"hit\nc\n",
    failures,
  )
  expect(
    bin_root,
    "grep",
    ["-Fzb", "hit"],
    Some(b"one\x00hit\x00three\x00"),
    0,
    b"4:hit\x00",
    failures,
  )
  expect(
    bin_root,
    "grep",
    ["--binary-files=text", "hit"],
    Some(b"a\x00hit\n"),
    0,
    b"a\x00hit\n",
    failures,
  )
  let binary_report = @testkit.run(
    @testkit.executable_path(bin_root, "grep"),
    ["hit"],
    stdin=b"a\x00hit\n",
  )
  record_result(
    binary_report.status == 0 &&
    binary_report.stdout.is_empty() &&
    @testkit.bytes_equal(
      binary_report.stderr,
      b"grep: (standard input): binary file matches\n",
    ),
    "grep: binary match notice must use the GNU 3.12 stderr contract",
    failures,
  )
  expect(
    bin_root,
    "grep",
    ["--binary-files=without-match", "hit"],
    Some(b"a\x00hit\n"),
    1,
    b"",
    failures,
  )
  expect(bin_root, "grep", ["--", "-x"], Some(b"-x\n"), 0, b"-x\n", failures)
  expect_failure(
    bin_root,
    "grep",
    ["-A", "bad", "hit"],
    2,
    "invalid context length",
    failures,
  )
  expect_failure(
    bin_root,
    "grep",
    ["--binary-files=bad", "hit"],
    2,
    "unknown binary-files type",
    failures,
  )
  expect_failure(
    bin_root,
    "grep",
    ["["],
    2,
    "invalid regular expression",
    failures,
  )
  let quiet_error = @testkit.run(@testkit.executable_path(bin_root, "grep"), [
    "-s", "hit", "missing-p2-p3-file",
  ])
  record_result(
    quiet_error.status == 2 && quiet_error.stderr.is_empty(),
    "grep: -s must suppress missing-file diagnostics without hiding status 2",
    failures,
  )
  let root = @fs.tmpdir(prefix="mooncmd-p2-p3")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let nested = @path.Path(root).join(Path("nested")).to_string()
  @fs.mkdir(nested)
  let keep = @path.Path(nested).join(Path("keep.txt")).to_string()
  let skip = @path.Path(nested).join(Path("skip.txt")).to_string()
  let log = @path.Path(nested).join(Path("keep.log")).to_string()
  @fs.write_file(keep, b"needle\n")
  @fs.write_file(skip, b"needle\n")
  @fs.write_file(log, b"needle\n")
  expect(
    bin_root,
    "grep",
    ["-r", "--include=*.txt", "--exclude=skip*", "needle", root],
    None,
    0,
    @utf8.encode(keep + ":needle\n"),
    failures,
  )
  expect(
    bin_root,
    "env",
    ["--ignore-environment", "--unset=DROP", "DROP=no", "KEEP=yes"],
    None,
    0,
    b"DROP=no\nKEEP=yes\n",
    failures,
  )
  expect(bin_root, "env", ["-i", "1=x"], None, 0, b"1=x\n", failures)
  expect_failure(bin_root, "env", ["-C"], 125, "requires an argument", failures)
  expect_failure(bin_root, "env", ["=x"], 125, "invalid", failures)
  expect_failure(
    bin_root,
    "env",
    ["--help"],
    125,
    "unsupported option",
    failures,
  )
  let repeated_cwd = @testkit.run(@testkit.executable_path(bin_root, "env"), [
    "-C",
    root,
    "-C",
    ".",
    @testkit.executable_path(bin_root, "pwd"),
  ])
  let current = @fs.realpath(".")
  record_result(
    repeated_cwd.status == 0 &&
    @testkit.bytes_equal(repeated_cwd.stdout, @utf8.encode(current + "\n")),
    "env: repeated -C must resolve the last directory from the original cwd",
    failures,
  )
  expect_failure(
    bin_root,
    "env",
    ["mooncmd-command-that-does-not-exist"],
    127,
    "cannot run",
    failures,
  )
  expect_failure(
    bin_root,
    "env",
    ["-i", "FOO=x", "-u"],
    127,
    "cannot run",
    failures,
  )
  let not_executable = @path.Path(root).join(Path("not-executable")).to_string()
  @fs.mkdir(not_executable)
  expect_failure(bin_root, "env", [not_executable], 126, "cannot run", failures)
  expect(
    bin_root,
    "sort",
    ["-t:", "-k2,2n", "-k1,1r"],
    Some(b"b:2\na:10\nc:2\n"),
    0,
    b"c:2\nb:2\na:10\n",
    failures,
  )
  expect(
    bin_root,
    "sort",
    ["-g"],
    Some(b"inf\n1\n-inf\nnan\ntext\n"),
    0,
    b"text\nnan\n-inf\n1\ninf\n",
    failures,
  )
  expect(
    bin_root,
    "sort",
    ["-t:", "-k2n,2r"],
    Some(b"a:2\nb:10\n"),
    0,
    b"b:10\na:2\n",
    failures,
  )
  expect(
    bin_root,
    "sort",
    ["-k2,2"],
    Some(b"x  b\nz a\ny   a\n"),
    0,
    b"y   a\nx  b\nz a\n",
    failures,
  )
  expect(
    bin_root,
    "sort",
    ["-u", "-t:", "-k2,2"],
    Some(b"b:1\na:1\n"),
    0,
    b"b:1\n",
    failures,
  )
  expect(
    bin_root,
    "sort",
    ["-h"],
    Some(b"999999K\n1M\n10K\n"),
    0,
    b"10K\n999999K\n1M\n",
    failures,
  )
  expect(
    bin_root,
    "sort",
    ["-bdf"],
    Some(b"  z!\na-\n B\n"),
    0,
    b"a-\n B\n  z!\n",
    failures,
  )
  expect(bin_root, "sort", ["-f"], Some(b"[\na\n"), 0, b"a\n[\n", failures)
  expect(
    bin_root,
    "sort",
    ["-V"],
    Some(b"file10\nfile2\nfile1\n"),
    0,
    b"file1\nfile2\nfile10\n",
    failures,
  )
  expect(
    bin_root,
    "sort",
    ["-z"],
    Some(b"b\x00a\x00"),
    0,
    b"a\x00b\x00",
    failures,
  )
  expect(bin_root, "sort", ["-c"], Some(b"a\nb\n"), 0, b"", failures)
  let sort_check = @testkit.run(
    @testkit.executable_path(bin_root, "sort"),
    ["--check"],
    stdin=b"b\na\n",
  )
  record_result(
    sort_check.status == 1 &&
    sort_check.stdout.is_empty() &&
    @testkit.contains_bytes(sort_check.stderr, "disorder"),
    "sort: --check must diagnose the first disorder on stderr",
    failures,
  )
  expect(bin_root, "sort", ["-C"], Some(b"b\na\n"), 1, b"", failures)
  expect_failure(
    bin_root,
    "sort",
    ["-R"],
    2,
    "deterministic seed contract",
    failures,
  )
  expect(
    bin_root,
    "uniq",
    ["-c", "-f1", "-s1", "-w1"],
    Some(b"1 xa\n2 xb\n3 yy\n"),
    0,
    b"      2 1 xa\n      1 3 yy\n",
    failures,
  )
  expect(
    bin_root,
    "uniq",
    ["-z", "-s1", "-w1"],
    Some(b"ax1\x00ax2\x00by\x00"),
    0,
    b"ax1\x00by\x00",
    failures,
  )
  expect_failure(bin_root, "uniq", ["-f", "bad"], 2, "invalid number", failures)
  expect(bin_root, "wc", ["-L"], Some(b"abc\n12345\n"), 0, b"5\n", failures)
  expect(bin_root, "wc", ["-L"], Some(b"a\tb\n"), 0, b"9\n", failures)
  let short = @path.Path(root).join(Path("short")).to_string()
  let long = @path.Path(root).join(Path("long")).to_string()
  @fs.write_file(short, b"a\n")
  @fs.write_file(long, b"1\n2\n3\n4\n5\n6\n7\n8\n9\n10\n")
  let wc = @testkit.run(@testkit.executable_path(bin_root, "wc"), [
    "-l", short, long,
  ])
  record_result(
    wc.status == 0 &&
    @testkit.bytes_equal(
      wc.stdout,
      @utf8.encode(" 1 \{short}\n10 \{long}\n11 total\n"),
    ),
    "wc: multiple-file alignment mismatch",
    failures,
  )
  let list = @path.Path(root).join(Path("files.list")).to_string()
  @fs.write_file(list, @utf8.encode(short + "\u0000" + long + "\u0000"))
  let wc_list = @testkit.run(@testkit.executable_path(bin_root, "wc"), [
    "-l", "--files0-from", list,
  ])
  record_result(
    wc_list.status == 0 && @testkit.bytes_equal(wc_list.stdout, wc.stdout),
    "wc: --files0-from must reuse normal multi-file accounting",
    failures,
  )
  let wc_mixed = @testkit.run(@testkit.executable_path(bin_root, "wc"), [
    "-l",
    short,
    root + "/missing",
  ])
  record_result(
    wc_mixed.status == 1 &&
    @testkit.contains_bytes(wc_mixed.stdout, "1 \{short}") &&
    @testkit.contains_bytes(wc_mixed.stdout, "1 total") &&
    @testkit.contains_bytes(wc_mixed.stderr, "missing"),
    "wc: mixed readable/missing operands must preserve counts, diagnostics, and status",
    failures,
  )
  expect_failure(
    bin_root,
    "wc",
    ["--files0-from", list, short],
    1,
    "extra operand",
    failures,
  )
  expect_failure(
    bin_root,
    "sort",
    ["-c", short, long],
    2,
    "extra operand",
    failures,
  )
  expect(
    bin_root,
    "head",
    ["-z", "-n2"],
    Some(b"abc\x00def\x00ghi\x00"),
    0,
    b"abc\x00def\x00",
    failures,
  )
  expect(
    bin_root,
    "head",
    ["-n", "-2"],
    Some(b"1\n2\n3\n4\n"),
    0,
    b"1\n2\n",
    failures,
  )
  expect(
    bin_root,
    "head",
    ["-n", "+3"],
    Some(b"1\n2\n3\n4\n"),
    0,
    b"1\n2\n3\n",
    failures,
  )
  expect(bin_root, "head", ["-2"], Some(b"1\n2\n3\n"), 0, b"1\n2\n", failures)
  expect(bin_root, "head", ["-2c"], Some(b"abc\n"), 0, b"ab", failures)
  expect(
    bin_root,
    "head",
    ["-n", "1KiB"],
    Some(b"1\n2\n"),
    0,
    b"1\n2\n",
    failures,
  )
  expect(bin_root, "head", ["-n1", "-c2"], Some(b"abc\n"), 0, b"ab", failures)
  expect_failure(bin_root, "head", ["-n", "bad"], 2, "invalid count", failures)
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
  expect(bin_root, "base64", ["-di"], Some(b"YQ== \r\n\t"), 0, b"a", failures)
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
        compat_fail(
          "\{command}: redirected stdin case failed: \{err}",
          failures,
        )
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
async fn run_p9_cases(bin_root : String, failures : Array[String]) -> Unit {
  expect(bin_root, "base64", ["-di"], Some(b"aG!k="), 0, b"hi", failures)
  expect(bin_root, "base64", ["-D"], Some(b"aGk="), 0, b"hi", failures)
  expect(
    bin_root,
    "base64",
    ["-w4"],
    Some(b"abcdef"),
    0,
    b"YWJj\nZGVm\n",
    failures,
  )
  expect(bin_root, "base64", ["-d"], Some(b"!"), 1, b"", failures)
  expect(bin_root, "basename", ["--", ""], None, 0, b"\n", failures)
  expect(bin_root, "basename", ["///"], None, 0, b"/\n", failures)
  expect(
    bin_root,
    "basename",
    ["path///to///file///"],
    None,
    0,
    b"file\n",
    failures,
  )
  expect(bin_root, "dirname", ["--", ""], None, 0, b".\n", failures)
  expect(bin_root, "dirname", ["///"], None, 0, b"/\n", failures)
  expect(
    bin_root,
    "dirname",
    ["path///to///file///"],
    None,
    0,
    b"path///to\n",
    failures,
  )
  expect(
    bin_root,
    "cat",
    ["-u"],
    Some(b"binary\x00\xff"),
    0,
    b"binary\x00\xff",
    failures,
  )
  expect(
    bin_root,
    "cut",
    ["-z", "-c1"],
    Some(b"ab\x00cd"),
    0,
    b"a\x00c\x00",
    failures,
  )
  expect_failure(bin_root, "cut", ["-c", "3-1"], 2, "decreasing", failures)
  expect_failure(bin_root, "cut", ["-d", "", "-f1"], 2, "single byte", failures)
  expect(
    bin_root,
    "printf",
    ["%d,", "1", "2", "3"],
    None,
    0,
    b"1,2,3,",
    failures,
  )
  expect(bin_root, "printf", ["%b", "A\\x00B"], None, 0, b"A\x00B", failures)
  expect(bin_root, "printf", ["%d", "invalid"], None, 1, b"0", failures)
  expect(bin_root, "seq", ["3", "-1", "1"], None, 0, b"3\n2\n1\n", failures)
  expect_failure(
    bin_root,
    "seq",
    ["1", "0", "2"],
    1,
    "zero increment",
    failures,
  )
  expect(bin_root, "echo", ["--", "-e"], None, 0, b"-- -e\n", failures)
  expect(bin_root, "echo", ["-e", "A\\x00B"], None, 0, b"A\x00B\n", failures)
  expect_failure(
    bin_root,
    "paste",
    ["-s", "-d", "\\"],
    1,
    "unescaped backslash",
    failures,
  )
  expect(bin_root, "sleep", ["0", "0s"], None, 0, b"", failures)
  expect_failure(
    bin_root,
    "sleep",
    ["-1"],
    1,
    "invalid time interval",
    failures,
  )
  expect_stdout_contains(
    bin_root,
    "sleep",
    ["--version"],
    "0.1.3",
    Map([]),
    failures,
  )
  expect(bin_root, "true", ["ignored"], None, 0, b"", failures)
  expect(bin_root, "false", ["ignored"], None, 1, b"", failures)
  expect_stdout_contains(
    bin_root,
    "true",
    ["--help"],
    "Usage:",
    Map([]),
    failures,
  )
  expect_stdout_contains(
    bin_root,
    "false",
    ["--version"],
    "0.1.3",
    Map([]),
    failures,
  )
  let sleep_cancelled = @async.with_task_group <| group => {
    let child = @process.spawn(
      group,
      @testkit.executable_path(bin_root, "sleep"),
      ["60"],
      cancel_handler=@process.hard_cancel(),
      no_wait=true,
    )
    @async.sleep(20)
    child.cancel()
    ignore(child.wait()) catch {
      _ => ()
    }
    true
  }
  record_result(
    sleep_cancelled, "sleep: hard-cancel signal path did not terminate the child",
    failures,
  )
  expect(bin_root, "tr", ["\\141", "X"], Some(b"a"), 0, b"X", failures)
  expect(bin_root, "tr", ["[=a=]", "X"], Some(b"a"), 0, b"X", failures)
  expect(bin_root, "tr", ["abc", "[X*]"], Some(b"abc"), 0, b"XXX", failures)
  expect(
    bin_root,
    "tr",
    ["-d", "[:punct:]"],
    Some(b"a! b?\n"),
    0,
    b"a b\n",
    failures,
  )
  expect(bin_root, "tr", ["-C", "a", "X"], Some(b"ab"), 0, b"aX", failures)
  expect(bin_root, "tr", ["-t", "abc", "X"], Some(b"abc"), 0, b"Xbc", failures)
  expect_failure(bin_root, "tr", ["\\", "X"], 2, "missing character", failures)
  expect_failure(
    bin_root,
    "tr",
    ["[:unknown:]", "X"],
    2,
    "unsupported character class",
    failures,
  )

  let root = @fs.tmpdir(prefix="mooncmd-p9")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let left = @path.Path(root).join(Path("left")).to_string()
  let right = @path.Path(root).join(Path("right")).to_string()
  @fs.write_file(left, b"same\n")
  @fs.write_file(right, b"same\n")
  let cmp_equal = @testkit.run(@testkit.executable_path(bin_root, "cmp"), [
    left, right,
  ])
  @fs.write_file(right, b"different\n")
  let cmp_different = @testkit.run(@testkit.executable_path(bin_root, "cmp"), [
    left, right,
  ])
  let missing = @path.Path(root).join(Path("missing")).to_string()
  let cmp_error = @testkit.run(@testkit.executable_path(bin_root, "cmp"), [
    left, missing,
  ])
  record_result(
    cmp_equal.status == 0 && cmp_different.status == 1 && cmp_error.status == 2,
    "cmp: P9 status matrix did not produce 0/1/2",
    failures,
  )

  @fs.write_file(left, b"a\x00c\x00")
  @fs.write_file(right, b"b\x00c\x00")
  let comm_zero = @testkit.run(@testkit.executable_path(bin_root, "comm"), [
    "-z", left, right,
  ])
  record_result(
    comm_zero.status == 0 &&
    @testkit.bytes_equal(comm_zero.stdout, b"a\x00\tb\x00\t\tc\x00"),
    "comm: NUL-record merge mismatch",
    failures,
  )
  @fs.write_file(left, b"b\na\n")
  @fs.write_file(right, b"z\n")
  let comm_checked = @testkit.run(@testkit.executable_path(bin_root, "comm"), [
    "--check-order", left, right,
  ])
  let comm_unchecked = @testkit.run(
    @testkit.executable_path(bin_root, "comm"),
    ["--check-order", "--nocheck-order", left, right],
  )
  let comm_default = @testkit.run(@testkit.executable_path(bin_root, "comm"), [
    left, right,
  ])
  @fs.write_file(right, b"b\na\n")
  let comm_pairable = @testkit.run(@testkit.executable_path(bin_root, "comm"), [
    left, right,
  ])
  record_result(
    comm_checked.status == 1 &&
    @testkit.contains_bytes(comm_checked.stderr, "not in sorted order") &&
    comm_unchecked.status == 0 &&
    comm_default.status == 1 &&
    comm_pairable.status == 0,
    "comm: explicit order-check precedence mismatch",
    failures,
  )

  @fs.write_file(left, b"1\x002\x00")
  @fs.write_file(right, b"a\x00b\x00")
  let paste_zero = @testkit.run(@testkit.executable_path(bin_root, "paste"), [
    "-z", left, right,
  ])
  record_result(
    paste_zero.status == 0 &&
    @testkit.bytes_equal(paste_zero.stdout, b"1\ta\x002\tb\x00"),
    "paste: NUL-record output mismatch",
    failures,
  )
  @fs.write_file(left, b"1 left\x002 left\x00")
  @fs.write_file(right, b"1 right\x002 right\x00")
  let join_zero = @testkit.run(@testkit.executable_path(bin_root, "join"), [
    "-z", left, right,
  ])
  record_result(
    join_zero.status == 0 &&
    @testkit.bytes_equal(join_zero.stdout, b"1 left right\x002 left right\x00"),
    "join: NUL-record output mismatch",
    failures,
  )
  @fs.write_file(left, b"b\na\n")
  @fs.write_file(right, b"a\nb\n")
  let join_checked = @testkit.run(@testkit.executable_path(bin_root, "join"), [
    "--check-order", left, right,
  ])
  let join_unchecked = @testkit.run(
    @testkit.executable_path(bin_root, "join"),
    ["--check-order", "--nocheck-order", left, right],
  )
  record_result(
    join_checked.status == 1 &&
    @testkit.contains_bytes(join_checked.stderr, "not in sorted order") &&
    join_unchecked.status == 0,
    "join: order-check precedence mismatch",
    failures,
  )
  expect(
    bin_root,
    "nl",
    ["-ba", "-ha", "-w1", "-s:", "-v10", "-i2"],
    Some(b"\\:\\:\\:\nh\n\\:\\:\nb\n"),
    0,
    b"\n10:h\n\n10:b\n",
    failures,
  )

  let pwd_invalid = @testkit.run(
    @testkit.executable_path(bin_root, "pwd"),
    ["-L"],
    cwd=root,
    extra_env=Map([("PWD", "/mooncmd-p9-does-not-exist")]),
  )
  record_result(
    pwd_invalid.status == 0 &&
    @testkit.bytes_equal(
      pwd_invalid.stdout,
      @utf8.encode((@fs.realpath(root) catch { _ => root }) + "\n"),
    ),
    "pwd: invalid logical PWD did not fall back to the physical cwd",
    failures,
  )
  let printenv_mixed = @testkit.run(
    @testkit.executable_path(bin_root, "printenv"),
    ["P9_VALUE", "P9_MISSING"],
    extra_env=Map([("P9_VALUE", "visible")]),
  )
  record_result(
    printenv_mixed.status == 1 &&
    @testkit.bytes_equal(printenv_mixed.stdout, b"visible\n"),
    "printenv: present/missing status precedence mismatch",
    failures,
  )

  let payload = @path.Path(root).join(Path("payload")).to_string()
  let checks = @path.Path(root).join(Path("checks")).to_string()
  @fs.write_file(payload, b"abc")
  @fs.write_file(
    checks, b"ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad  payload\nmalformed\n",
  )
  let checksum_warn = @testkit.run(
    @testkit.executable_path(bin_root, "sha256sum"),
    ["-c", "--warn", "checks"],
    cwd=root,
  )
  let checksum_strict = @testkit.run(
    @testkit.executable_path(bin_root, "sha256sum"),
    ["-c", "--strict", "--status", "checks"],
    cwd=root,
  )
  let missing_checks = @path.Path(root).join(Path("missing-checks")).to_string()
  @fs.write_file(
    missing_checks, b"ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad  absent\nba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad  payload\n",
  )
  let checksum_missing = @testkit.run(
    @testkit.executable_path(bin_root, "sha256sum"),
    ["-c", "--ignore-missing", "--quiet", "missing-checks"],
    cwd=root,
  )
  record_result(
    checksum_warn.status == 0 &&
    @testkit.bytes_equal(checksum_warn.stdout, b"payload: OK\n") &&
    @testkit.contains_bytes(checksum_warn.stderr, "improperly formatted") &&
    checksum_strict.status == 1 &&
    checksum_strict.stdout.is_empty() &&
    checksum_strict.stderr.is_empty() &&
    checksum_missing.status == 0 &&
    checksum_missing.stdout.is_empty() &&
    checksum_missing.stderr.is_empty(),
    "sha256sum: malformed warning/strict/status precedence mismatch",
    failures,
  )
  let checksum_binary = @testkit.run(
    @testkit.executable_path(bin_root, "sha256sum"),
    ["-bt", "payload"],
    cwd=root,
  )
  let checksum_text = @testkit.run(
    @testkit.executable_path(bin_root, "sha256sum"),
    ["-tb", "payload"],
    cwd=root,
  )
  record_result(
    checksum_binary.status == 0 &&
    @testkit.contains_bytes(checksum_binary.stdout, "  payload\n") &&
    checksum_text.status == 0 &&
    @testkit.contains_bytes(checksum_text.stdout, " *payload\n"),
    "sha256sum: binary/text marker precedence mismatch",
    failures,
  )

  let existing = @path.Path(root).join(Path("existing")).to_string()
  let created = @path.Path(root).join(Path("created")).to_string()
  @fs.mkdir(existing)
  let mkdir_order = @testkit.run(@testkit.executable_path(bin_root, "mkdir"), [
    existing, created,
  ])
  let removable = @path.Path(root).join(Path("removable")).to_string()
  @fs.write_file(removable, b"x")
  let rm_order = @testkit.run(@testkit.executable_path(bin_root, "rm"), [
    missing, removable,
  ])
  let nonempty = @path.Path(root).join(Path("nonempty")).to_string()
  let empty = @path.Path(root).join(Path("empty")).to_string()
  @fs.mkdir(nonempty)
  @fs.write_file(@path.Path(nonempty).join(Path("kept")).to_string(), b"x")
  @fs.mkdir(empty)
  let rmdir_order = @testkit.run(@testkit.executable_path(bin_root, "rmdir"), [
    nonempty, empty,
  ])
  let tee_output = @path.Path(root).join(Path("tee-output")).to_string()
  let tee_partial = @testkit.run(
    @testkit.executable_path(bin_root, "tee"),
    [root, tee_output],
    stdin=b"stream\x00data",
  )
  record_result(
    mkdir_order.status == 1 &&
    @fs.exists(created) &&
    rm_order.status == 1 &&
    !@fs.exists(removable) &&
    rmdir_order.status == 1 &&
    !@fs.exists(empty) &&
    @fs.exists(nonempty) &&
    tee_partial.status == 1 &&
    @testkit.bytes_equal(tee_partial.stdout, b"stream\x00data") &&
    @testkit.bytes_equal(@fs.read_file(tee_output).binary(), b"stream\x00data"),
    "filesystem utilities: failure ordering or partial-output handling mismatch",
    failures,
  )
}

///|
async fn run_http_cases(bin_root : String, failures : Array[String]) -> Unit {
  @async.with_task_group <| group => {
    let mut wget_retry_attempts = 0
    let mut curl_retry_attempts = 0
    let mut curl_retry_all_attempts = 0
    let mut curl_retry_limited_attempts = 0
    let mut wget_retry_limited_attempts = 0
    let cross_origin = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    group.add_defer(() => cross_origin.close())
    group.spawn_bg(no_wait=true) <| () => {
      cross_origin.run_forever() <| ((request, body, connection) => {
        let request_name = match request.meth {
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
        let authorization = if request.headers.get("Authorization") is None {
          "clean"
        } else {
          "leaked"
        }
        let payload = body.read_all().text()
        let response = "\{request_name}:\{authorization}:\{payload}"
        connection.send_response(200, "OK", extra_headers={
          "Content-Length": response.length().to_string(),
        })
        connection..write(response).end_response()
      })
    }
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    group.add_defer(() => server.close())
    group.spawn_bg(no_wait=true) <| () => {
      server.run_forever() <| ((request, _body, connection) => {
        match request.path {
          "/fixed" => {
            connection.send_response(200, "OK", extra_headers={
              "Content-Length": "5",
            })
            if request.meth == @http.Head {
              connection.end_response()
            } else {
              connection..write("hello").end_response()
            }
          }
          "/chunked" => {
            connection.send_response(200, "OK")
            connection..write("slow-").flush()
            @async.sleep(5)
            connection..write("stream").end_response()
          }
          "/redirect" =>
            connection
            ..send_response(302, "Found", extra_headers={
              "Location": "/fixed",
              "Content-Length": "0",
            })
            .end_response()
          "/method-redirect" =>
            connection
            ..send_response(302, "Found", extra_headers={
              "Location": "/request",
              "Content-Length": "0",
            })
            .end_response()
          "/cross-origin" =>
            connection
            ..send_response(307, "Temporary Redirect", extra_headers={
              "Location": "http://127.0.0.1:\{cross_origin.addr.port()}/target",
              "Content-Length": "0",
            })
            .end_response()
          "/chain-1" =>
            connection
            ..send_response(302, "Found", extra_headers={
              "Location": "/chain-2",
              "Content-Length": "0",
            })
            .end_response()
          "/chain-2" =>
            connection
            ..send_response(302, "Found", extra_headers={
              "Location": "/fixed",
              "Content-Length": "0",
            })
            .end_response()
          "/redirect-301"
          | "/redirect-302"
          | "/redirect-303"
          | "/redirect-307"
          | "/redirect-308" => {
            let status = @string.parse_int(request.path[10:])
            let reason = match status {
              301 => "Moved Permanently"
              302 => "Found"
              303 => "See Other"
              307 => "Temporary Redirect"
              _ => "Permanent Redirect"
            }
            connection
            ..send_response(status, reason, extra_headers={
              "Location": "/echo",
              "Content-Length": "0",
            })
            .end_response()
          }
          "/loop-a" =>
            connection
            ..send_response(302, "Found", extra_headers={
              "Location": "/loop-b",
              "Content-Length": "0",
            })
            .end_response()
          "/loop-b" =>
            connection
            ..send_response(302, "Found", extra_headers={
              "Location": "/loop-a",
              "Content-Length": "0",
            })
            .end_response()
          "/echo" => {
            let content = _body.read_all().binary()
            connection.send_response(200, "OK", extra_headers={
              "Content-Length": content.length().to_string(),
            })
            connection..write(content).end_response()
          }
          "/request" => {
            let content = _body.read_all().text()
            let request_name = match request.meth {
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
            let marker = request.headers.get("X-Marker").unwrap_or("")
            let response = "\{request_name}:\{marker}:\{content}"
            connection.send_response(200, "OK", extra_headers={
              "Content-Length": response.length().to_string(),
            })
            connection..write(response).end_response()
          }
          "/method-check" => {
            let expected = request.headers.get("X-Expected").unwrap_or("")
            let accepted = oracle_request_name(request) == expected
            connection
            ..send_response(
              if accepted {
                200
              } else {
                400
              },
              if accepted {
                "OK"
              } else {
                "Bad Request"
              },
              extra_headers={ "Content-Length": "0" },
            )
            .end_response()
          }
          "/range" => {
            let ranged = request.headers.get("Range") == Some("bytes=3-")
            let content = if ranged { "lo" } else { "hello" }
            connection.send_response(if ranged { 206 } else { 200 }, "OK", extra_headers={
              "Content-Length": content.length().to_string(),
            })
            connection..write(content).end_response()
          }
          "/range-ignore" => {
            connection.send_response(200, "OK", extra_headers={
              "Content-Length": "5",
            })
            connection..write("hello").end_response()
          }
          "/conditional" =>
            if request.headers.get("If-Modified-Since") is Some(_) {
              connection
              ..send_response(304, "Not Modified", extra_headers={
                "Content-Length": "0",
              })
              .end_response()
            } else {
              connection.send_response(200, "OK", extra_headers={
                "Content-Length": "5",
              })
              connection..write("fresh").end_response()
            }
          "/not-modified" =>
            connection
            ..send_response(304, "Not Modified", extra_headers={
              "Content-Length": "0",
            })
            .end_response()
          "/wget-retry" | "/curl-retry" => {
            if request.path == "/wget-retry" {
              wget_retry_attempts += 1
            } else {
              curl_retry_attempts += 1
            }
            let attempts = if request.path == "/wget-retry" {
              wget_retry_attempts
            } else {
              curl_retry_attempts
            }
            let success_attempt = if request.path == "/wget-retry" {
              3
            } else {
              2
            }
            if attempts < success_attempt {
              connection
              ..send_response(503, "Service Unavailable", extra_headers={
                "Content-Length": "0",
              })
              .end_response()
            } else {
              connection.send_response(200, "OK", extra_headers={
                "Content-Length": "5",
              })
              connection..write("hello").end_response()
            }
          }
          "/curl-retry-all" => {
            curl_retry_all_attempts += 1
            if curl_retry_all_attempts < 2 {
              connection
              ..send_response(404, "Not Found", extra_headers={
                "Content-Length": "0",
              })
              .end_response()
            } else {
              connection.send_response(200, "OK", extra_headers={
                "Content-Length": "5",
              })
              connection..write("hello").end_response()
            }
          }
          "/curl-retry-limited" => {
            curl_retry_limited_attempts += 1
            connection
            ..send_response(503, "Service Unavailable", extra_headers={
              "Content-Length": "0",
            })
            .end_response()
          }
          "/wget-retry-limited" => {
            wget_retry_limited_attempts += 1
            connection
            ..send_response(503, "Service Unavailable", extra_headers={
              "Content-Length": "0",
            })
            .end_response()
          }
          "/partial" => {
            connection.send_response(200, "OK", extra_headers={
              "Content-Length": "9",
            })
            connection..write("abc").flush()
            connection.close()
          }
          "/unauthorized" =>
            connection
            ..send_response(401, "Unauthorized", extra_headers={
              "Content-Length": "0",
            })
            .end_response()
          "/forbidden" =>
            connection
            ..send_response(403, "Forbidden", extra_headers={
              "Content-Length": "0",
            })
            .end_response()
          "/busy" =>
            connection
            ..send_response(429, "Too Many Requests", extra_headers={
              "Content-Length": "0",
            })
            .end_response()
          "/server-error" =>
            connection
            ..send_response(500, "Internal Server Error", extra_headers={
              "Content-Length": "0",
            })
            .end_response()
          "/named" => {
            connection.send_response(200, "OK", extra_headers={
              "Content-Length": "5",
              "Content-Disposition": "attachment; filename=fixture.txt",
            })
            connection..write("hello").end_response()
          }
          "/named-encoded" => {
            connection.send_response(200, "OK", extra_headers={
              "Content-Length": "5",
              "Content-Disposition": "attachment; filename*=UTF-8''encoded.txt",
            })
            connection..write("hello").end_response()
          }
          "/named-partial" => {
            connection.send_response(200, "OK", extra_headers={
              "Content-Length": "9",
              "Content-Disposition": "attachment; filename=partial.txt",
            })
            connection..write("abc").flush()
            connection.close()
          }
          "/one" => {
            connection.send_response(200, "OK", extra_headers={
              "Content-Length": "3",
            })
            connection..write("one").end_response()
          }
          "/two" => {
            connection.send_response(200, "OK", extra_headers={
              "Content-Length": "3",
            })
            connection..write("two").end_response()
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
          "/body-stall" => {
            connection.send_response(200, "OK", extra_headers={
              "Content-Length": "5",
            })
            connection.flush()
            @async.sleep(200)
            connection..write("later").end_response()
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
      @testkit.contains_bytes(wget_fixed.stderr, "HTTP request sent") &&
      @testkit.contains_bytes(wget_fixed.stderr, "saved [5]"),
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
      wget_missing.status == 8 &&
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
      wget_quiet_missing.status == 8 &&
      wget_quiet_missing.stdout.is_empty() &&
      wget_quiet_missing.stderr.is_empty(),
      "wget: -q did not suppress an HTTP error diagnostic",
      failures,
    )
    let curl_chunked = @testkit.run(curl, [base + "/chunked"])
    record_result(
      curl_chunked.status == 0 &&
      @testkit.bytes_equal(curl_chunked.stdout, b"slow-stream") &&
      @testkit.contains_bytes(curl_chunked.stderr, "0% 11"),
      "curl: unknown-length response or progress feedback mismatch",
      failures,
    )
    let curl_silent = @testkit.run(curl, ["-s", "-f", base + "/missing"])
    record_result(
      curl_silent.status == 22 && curl_silent.stderr.is_empty(),
      "curl: -s did not suppress errors",
      failures,
    )
    let curl_show_error = @testkit.run(curl, ["-sS", "-f", base + "/missing"])
    record_result(
      curl_show_error.status == 22 &&
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
        "HTTP request sent",
      ) &&
      @testkit.contains_bytes(@fs.read_file(wget_log).binary(), "saved [5]"),
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
      curl_timeout.status == 28 &&
      @testkit.contains_bytes(curl_timeout.stderr, "timed out after 20"),
      "curl: idle timeout did not fail promptly",
      failures,
    )
    let wget_redirect = @testkit.run(wget, ["-q", "-O", "-", base + "/redirect"])
    record_result(
      wget_redirect.status == 0 &&
      @testkit.bytes_equal(wget_redirect.stdout, b"hello") &&
      wget_redirect.stderr.is_empty(),
      "wget: default relative redirect handling mismatch",
      failures,
    )
    let curl_redirect = @testkit.run(curl, ["-s", base + "/redirect"])
    record_result(
      curl_redirect.status == 0 && curl_redirect.stdout.is_empty(),
      "curl: followed a redirect without -L",
      failures,
    )
    let curl_location = @testkit.run(curl, ["-sL", base + "/redirect"])
    record_result(
      curl_location.status == 0 &&
      @testkit.bytes_equal(curl_location.stdout, b"hello"),
      "curl: -L relative redirect handling mismatch",
      failures,
    )
    let curl_redirect_zero = @testkit.run(curl, [
      "-sL",
      "--max-redirs",
      "0",
      base + "/redirect",
    ])
    let curl_redirect_one = @testkit.run(curl, [
      "-sL",
      "--max-redirs",
      "1",
      base + "/chain-1",
    ])
    let curl_redirect_two = @testkit.run(curl, [
      "-sL",
      "--max-redirs",
      "2",
      base + "/chain-1",
    ])
    let curl_redirect_unlimited = @testkit.run(curl, [
      "-sL",
      "--max-redirs",
      "-1",
      base + "/chain-1",
    ])
    let wget_redirect_zero = @testkit.run(wget, [
      "-qO-",
      "--max-redirect=0",
      base + "/redirect",
    ])
    let wget_redirect_one = @testkit.run(wget, [
      "-qO-",
      "--max-redirect=1",
      base + "/chain-1",
    ])
    let wget_redirect_two = @testkit.run(wget, [
      "-qO-",
      "--max-redirect=2",
      base + "/chain-1",
    ])
    record_result(
      curl_redirect_zero.status == 47 &&
      curl_redirect_one.status == 47 &&
      curl_redirect_two.status == 0 &&
      @testkit.bytes_equal(curl_redirect_two.stdout, b"hello") &&
      curl_redirect_unlimited.status == 0 &&
      @testkit.bytes_equal(curl_redirect_unlimited.stdout, b"hello") &&
      wget_redirect_zero.status == 7 &&
      wget_redirect_one.status == 7 &&
      wget_redirect_two.status == 0 &&
      @testkit.bytes_equal(wget_redirect_two.stdout, b"hello"),
      "curl/wget redirect limit behavior mismatch",
      failures,
    )
    let curl_last_status = @testkit.run(curl, [
      "-sf",
      base + "/missing",
      base + "/fixed",
    ])
    record_result(
      curl_last_status.status == 0 &&
      @testkit.bytes_equal(curl_last_status.stdout, b"hello"),
      "curl: final transfer did not determine the process status",
      failures,
    )
    let curl_loop = @testkit.run(curl, ["-sSL", base + "/loop-a"])
    record_result(
      curl_loop.status == 47 &&
      @testkit.contains_bytes(curl_loop.stderr, "redirect loop"),
      "curl: redirect loop status mismatch",
      failures,
    )
    let curl_post = @testkit.run(curl, [
      "-s",
      "-d",
      "alpha=one",
      "--data-raw",
      "beta=two",
      base + "/echo",
    ])
    record_result(
      curl_post.status == 0 &&
      @testkit.bytes_equal(curl_post.stdout, b"alpha=one&beta=two"),
      "curl: repeated data body mismatch",
      failures,
    )
    let data_root = @fs.tmpdir(prefix="mooncmd-http-data")
    defer (@fs.rmdir(data_root, recursive=true) catch { _ => () })
    let data_path = @path.Path(data_root).join(Path("input.bin")).to_string()
    @fs.write_file(data_path, b"a\r\nb\x00c")
    let curl_form_file = @testkit.run(curl, [
      "-s",
      "-d",
      "@" + data_path,
      base + "/echo",
    ])
    let curl_raw = @testkit.run(curl, [
      "-s",
      "--data-raw",
      "@literal",
      base + "/echo",
    ])
    let curl_binary = @testkit.run(curl, [
      "-s",
      "--data-binary",
      "@" + data_path,
      base + "/echo",
    ])
    let curl_encoded = @testkit.run(curl, [
      "-s",
      "--data-urlencode",
      "field@" + data_path,
      base + "/echo",
    ])
    let curl_empty_data = @testkit.run(curl, [
      "-s",
      "--data-raw",
      "",
      "--data-urlencode",
      "a b",
      base + "/echo",
    ])
    record_result(
      curl_form_file.status == 0 &&
      @testkit.bytes_equal(curl_form_file.stdout, b"abc") &&
      curl_raw.status == 0 &&
      @testkit.bytes_equal(curl_raw.stdout, b"@literal") &&
      curl_binary.status == 0 &&
      @testkit.bytes_equal(curl_binary.stdout, b"a\r\nb\x00c") &&
      curl_encoded.status == 0 &&
      @testkit.bytes_equal(curl_encoded.stdout, b"field=a%0D%0Ab%00c") &&
      curl_empty_data.status == 0 &&
      @testkit.bytes_equal(curl_empty_data.stdout, b"&a%20b"),
      "curl: data file/raw/binary/urlencode behavior mismatch",
      failures,
    )
    let upload_path = @path.Path(data_root).join(Path("upload.bin")).to_string()
    @fs.write_file(upload_path, b"upload\x00bytes")
    let curl_upload = @testkit.run(curl, [
      "-s",
      "-T",
      upload_path,
      base + "/echo",
    ])
    let curl_upload_twice = @testkit.run(curl, [
      "-s",
      "-T",
      upload_path,
      base + "/echo",
      base + "/echo",
    ])
    let curl_upload_patch = @testkit.run(curl, [
      "-s",
      "-X",
      "PATCH",
      "-T",
      upload_path,
      base + "/request",
    ])
    let curl_upload_missing = @testkit.run(curl, [
      "-s",
      "-T",
      upload_path + ".missing",
      base + "/echo",
    ])
    record_result(
      curl_upload.status == 0 &&
      @testkit.bytes_equal(curl_upload.stdout, b"upload\x00bytes") &&
      curl_upload_twice.status == 0 &&
      @testkit.bytes_equal(
        curl_upload_twice.stdout,
        b"upload\x00bytesupload\x00bytes",
      ) &&
      curl_upload_patch.status == 0 &&
      @testkit.bytes_equal(curl_upload_patch.stdout, b"PATCH::upload\x00bytes") &&
      curl_upload_missing.status == 26 &&
      curl_upload_missing.stdout.is_empty(),
      "curl: upload file behavior mismatch",
      failures,
    )
    let curl_head = @testkit.run(curl, ["-I", base + "/fixed"])
    record_result(
      curl_head.status == 0 &&
      @testkit.contains_bytes(curl_head.stdout, "HTTP/1.1 200 OK") &&
      !@testkit.contains_bytes(curl_head.stdout, "hello"),
      "curl: HEAD response mismatch",
      failures,
    )
    let named_root = @fs.tmpdir(prefix="mooncmd-http-name")
    defer (@fs.rmdir(named_root, recursive=true) catch { _ => () })
    let curl_named = @testkit.run(
      curl,
      ["-sOJ", base + "/named"],
      cwd=named_root,
    )
    let named_path = @path.Path(named_root)
      .join(Path("fixture.txt"))
      .to_string()
    record_result(
      curl_named.status == 0 &&
      @fs.exists(named_path) &&
      @testkit.bytes_equal(@fs.read_file(named_path).binary(), b"hello"),
      "curl: -OJ content-disposition output mismatch",
      failures,
    )
    let basename_path = @path.Path(named_root).join(Path("fixed")).to_string()
    @fs.write_file(basename_path, b"old")
    let curl_basename = @testkit.run(
      curl,
      ["-sO", base + "/fixed"],
      cwd=named_root,
    )
    let encoded_path = @path.Path(named_root)
      .join(Path("encoded.txt"))
      .to_string()
    let curl_encoded_name = @testkit.run(
      curl,
      ["-sOJ", base + "/named-encoded"],
      cwd=named_root,
    )
    let curl_named_partial = @testkit.run(
      curl,
      ["-sSJO", "--remove-on-error", base + "/named-partial"],
      cwd=named_root,
    )
    let named_partial_path = @path.Path(named_root)
      .join(Path("partial.txt"))
      .to_string()
    record_result(
      curl_basename.status == 0 &&
      @testkit.bytes_equal(@fs.read_file(basename_path).binary(), b"hello") &&
      curl_encoded_name.status == 0 &&
      @testkit.bytes_equal(@fs.read_file(encoded_path).binary(), b"hello") &&
      curl_named_partial.status == 7 &&
      !@fs.exists(named_partial_path),
      "curl: remote filename, collision, or named cleanup mismatch",
      failures,
    )
    for status in [301, 302, 303] {
      let redirected = @testkit.run(curl, [
        "-sL",
        "-d",
        "body",
        base + "/redirect-\{status}",
      ])
      record_result(
        redirected.status == 0 && redirected.stdout.is_empty(),
        "curl: \{status} did not rewrite POST to GET",
        failures,
      )
    }
    for status in [307, 308] {
      let redirected = @testkit.run(curl, [
        "-sL",
        "-d",
        "body",
        base + "/redirect-\{status}",
      ])
      record_result(
        redirected.status == 0 &&
        @testkit.bytes_equal(redirected.stdout, b"body"),
        "curl: \{status} did not preserve the request body",
        failures,
      )
    }
    let curl_request = @testkit.run(curl, [
      "-s",
      "-H",
      "X-Marker: present",
      "-X",
      "PATCH",
      "--data-raw",
      "payload",
      base + "/request",
    ])
    record_result(
      curl_request.status == 0 &&
      @testkit.bytes_equal(curl_request.stdout, b"PATCH:present:payload"),
      "curl: method/header/body request mismatch",
      failures,
    )
    let wget_request = @testkit.run(wget, [
      "-qO-",
      "--header=X-Marker: present",
      "--method=PATCH",
      "--body-data=payload",
      base + "/request",
    ])
    record_result(
      wget_request.status == 0 &&
      @testkit.bytes_equal(wget_request.stdout, b"PATCH:present:payload"),
      "wget: method/header/body request mismatch",
      failures,
    )
    for
      request_name in [
        "GET", "HEAD", "POST", "PUT", "DELETE", "CONNECT", "OPTIONS", "TRACE", "PATCH",
      ] {
      let checked = @testkit.run(curl, [
        "-sf",
        "-X",
        request_name,
        "-H",
        "X-Expected: " + request_name,
        base + "/method-check",
      ])
      record_result(
        checked.status == 0,
        "curl: request method {request_name} did not reach the server",
        failures,
      )
    }
    let curl_explicit_redirect = @testkit.run(curl, [
      "-sL",
      "-X",
      "POST",
      "--data-raw",
      "payload",
      base + "/method-redirect",
    ])
    let wget_explicit_redirect = @testkit.run(wget, [
      "-qO-",
      "--method=POST",
      "--body-data=payload",
      base + "/method-redirect",
    ])
    record_result(
      curl_explicit_redirect.status == 0 &&
      @testkit.bytes_equal(curl_explicit_redirect.stdout, b"POST::") &&
      wget_explicit_redirect.status == 0 &&
      @testkit.bytes_equal(wget_explicit_redirect.stdout, b"GET::"),
      "explicit request methods were not preserved across redirects",
      failures,
    )
    let cross_redirect = @testkit.run(curl, [
      "-sL",
      "-X",
      "PATCH",
      "-H",
      "Authorization: secret",
      "--data-raw",
      "payload",
      base + "/cross-origin",
    ])
    record_result(
      cross_redirect.status == 0 &&
      @testkit.bytes_equal(cross_redirect.stdout, b"PATCH:clean:payload"),
      "curl: cross-origin redirect method/body/header behavior mismatch",
      failures,
    )
    let resume_root = @fs.tmpdir(prefix="mooncmd-http-resume")
    defer (@fs.rmdir(resume_root, recursive=true) catch { _ => () })
    let resume_path = @path.Path(resume_root).join(Path("range")).to_string()
    let range_ignore_path = @path.Path(resume_root)
      .join(Path("range-ignore"))
      .to_string()
    @fs.write_file(range_ignore_path, b"hel")
    let wget_resume = @testkit.run(
      wget,
      ["-q", "-c", base + "/range"],
      cwd=resume_root,
    )
    record_result(
      wget_resume.status == 0 &&
      @testkit.bytes_equal(@fs.read_file(resume_path).binary(), b"hello"),
      "wget: range resume mismatch",
      failures,
    )
    @fs.write_file(resume_path, b"hel")
    let wget_range_ignored = @testkit.run(
      wget,
      ["-q", "-c", base + "/range-ignore"],
      cwd=resume_root,
    )
    record_result(
      wget_range_ignored.status == 0 &&
      @testkit.bytes_equal(@fs.read_file(range_ignore_path).binary(), b"hello"),
      "wget: ignored range response handling mismatch",
      failures,
    )
    let unchanged_path = @path.Path(resume_root)
      .join(Path("not-modified"))
      .to_string()
    @fs.write_file(unchanged_path, b"original")
    let wget_unchanged = @testkit.run(
      wget,
      ["-q", "-N", base + "/not-modified"],
      cwd=resume_root,
    )
    record_result(
      wget_unchanged.status == 0 &&
      @testkit.bytes_equal(@fs.read_file(unchanged_path).binary(), b"original"),
      "wget: timestamping 304 changed the destination",
      failures,
    )
    let conditional_path = @path.Path(resume_root)
      .join(Path("conditional"))
      .to_string()
    @fs.write_file(conditional_path, b"preserved")
    let wget_conditional = @testkit.run(
      wget,
      ["-q", "-N", base + "/conditional"],
      cwd=resume_root,
    )
    record_result(
      wget_conditional.status == 0 &&
      @testkit.bytes_equal(
        @fs.read_file(conditional_path).binary(),
        b"preserved",
      ),
      "wget: timestamping did not send a conditional request",
      failures,
    )
    let input_root = @fs.tmpdir(prefix="mooncmd-http-input")
    defer (@fs.rmdir(input_root, recursive=true) catch { _ => () })
    let input_one = @path.Path(input_root).join(Path("urls-one")).to_string()
    let input_two = @path.Path(input_root).join(Path("urls-two")).to_string()
    let input_mixed = @path.Path(input_root)
      .join(Path("urls-mixed"))
      .to_string()
    @fs.write_file(input_one, @utf8.encode("# comment\n\n" + base + "/one\n"))
    @fs.write_file(input_two, @utf8.encode("  \n" + base + "/two\n"))
    @fs.write_file(
      input_mixed,
      @utf8.encode(base + "/missing\n" + base + "/one\n"),
    )
    let wget_inputs = @testkit.run(wget, [
      "-qO-",
      "-i",
      input_one,
      "--input-file=" + input_two,
    ])
    let wget_aggregate = @testkit.run(wget, ["-qO-", "-i", input_mixed])
    let wget_missing_input = @testkit.run(wget, [
      "-q",
      "-i",
      input_mixed + ".missing",
    ])
    record_result(
      wget_inputs.status == 0 &&
      @testkit.bytes_equal(wget_inputs.stdout, b"onetwo") &&
      wget_aggregate.status == 8 &&
      @testkit.bytes_equal(wget_aggregate.stdout, b"one") &&
      wget_missing_input.status == 3,
      "wget: input-file parsing or status aggregation mismatch",
      failures,
    )
    let append_log = @path.Path(input_root).join(Path("append.log")).to_string()
    let quiet_log = @path.Path(input_root).join(Path("quiet.log")).to_string()
    @fs.write_file(append_log, b"before\n")
    @fs.write_file(quiet_log, b"untouched\n")
    let wget_append_log = @testkit.run(wget, [
      "-a",
      append_log,
      "-O",
      "-",
      base + "/one",
    ])
    let wget_quiet_log = @testkit.run(wget, [
      "-q",
      "-a",
      quiet_log,
      "-O",
      "-",
      base + "/one",
    ])
    record_result(
      wget_append_log.status == 0 &&
      @testkit.bytes_equal(wget_append_log.stdout, b"one") &&
      @testkit.contains_bytes(@fs.read_file(append_log).binary(), "before\n--") &&
      wget_quiet_log.status == 0 &&
      @testkit.bytes_equal(wget_quiet_log.stdout, b"one") &&
      @testkit.bytes_equal(@fs.read_file(quiet_log).binary(), b"untouched\n"),
      "wget: append log or quiet/log interaction mismatch",
      failures,
    )
    let body_file = @path.Path(input_root).join(Path("body.bin")).to_string()
    @fs.write_file(body_file, b"body\x00bytes")
    let wget_body_file = @testkit.run(wget, [
      "-qO-",
      "--method=POST",
      "--body-file=" + body_file,
      base + "/echo",
    ])
    let wget_body_without_method = @testkit.run(wget, [
      "-qO-",
      "--body-data=payload",
      base + "/echo",
    ])
    let wget_body_conflict = @testkit.run(wget, [
      "-qO-",
      "--method=POST",
      "--body-data=payload",
      "--body-file=" + body_file,
      base + "/echo",
    ])
    let wget_headers = @testkit.run(wget, [
      "-qO-",
      "--header=X-Marker: first",
      "--header=X-Marker: second",
      base + "/request",
    ])
    record_result(
      wget_body_file.status == 0 &&
      @testkit.bytes_equal(wget_body_file.stdout, b"body\x00bytes") &&
      wget_body_without_method.status == 1 &&
      wget_body_without_method.stdout.is_empty() &&
      wget_body_conflict.status == 1 &&
      wget_body_conflict.stdout.is_empty() &&
      wget_headers.status == 0 &&
      @testkit.bytes_equal(wget_headers.stdout, b"GET:second:"),
      "wget: binary body file or repeated header behavior mismatch",
      failures,
    )
    let wget_retry = @testkit.run(wget, [
      "-qO-",
      "--retry-on-http-error=503",
      "--waitretry=0.001",
      "--tries=3",
      base + "/wget-retry",
    ])
    record_result(
      wget_retry.status == 0 &&
      @testkit.bytes_equal(wget_retry.stdout, b"hello") &&
      wget_retry_attempts == 3,
      "wget: HTTP retry mismatch",
      failures,
    )
    let curl_retry = @testkit.run(curl, [
      "-s",
      "--retry",
      "1",
      "--retry-delay",
      "0",
      base + "/curl-retry",
    ])
    record_result(
      curl_retry.status == 0 &&
      @testkit.bytes_equal(curl_retry.stdout, b"hello") &&
      curl_retry_attempts == 2,
      "curl: HTTP retry mismatch",
      failures,
    )
    let curl_retry_all = @testkit.run(curl, [
      "-sf",
      "--retry",
      "1",
      "--retry-all-errors",
      "--retry-delay",
      "1",
      base + "/curl-retry-all",
    ])
    let curl_retry_limited = @testkit.run(curl, [
      "-sf",
      "--retry",
      "3",
      "--retry-max-time",
      "1",
      base + "/curl-retry-limited",
    ])
    let curl_refused = @testkit.run(curl, [
      "-s", "--retry", "2", "--retry-connrefused", "--retry-max-time", "1", "http://127.0.0.1:1/unreachable",
    ])
    let wget_retry_limited = @testkit.run(wget, [
      "-qO-",
      "--tries=2",
      "--retry-on-http-error=503",
      "--waitretry=0.001",
      base + "/wget-retry-limited",
    ])
    let wget_refused = @testkit.run(wget, [
      "-qO-", "--tries=2", "--retry-connrefused", "--waitretry=0.001", "http://127.0.0.1:1/unreachable",
    ])
    record_result(
      curl_retry_all.status == 0 &&
      @testkit.bytes_equal(curl_retry_all.stdout, b"hello") &&
      curl_retry_all_attempts == 2 &&
      curl_retry_limited.status == 22 &&
      curl_retry_limited_attempts == 1 &&
      curl_refused.status == 7 &&
      wget_retry_limited.status == 8 &&
      wget_retry_limited_attempts == 2 &&
      wget_refused.status == 4,
      "curl/wget retry classification, limits, or final status mismatch",
      failures,
    )
    for endpoint in ["unauthorized", "forbidden", "busy", "server-error"] {
      let wget_status = @testkit.run(wget, ["-qO-", base + "/" + endpoint])
      let curl_status = @testkit.run(curl, ["-sf", base + "/" + endpoint])
      record_result(
        wget_status.status == 8 && curl_status.status == 22,
        "HTTP error status mapping mismatch for \{endpoint}",
        failures,
      )
    }
    let partial_path = @path.Path(resume_root)
      .join(Path("partial.bin"))
      .to_string()
    let curl_partial = @testkit.run(curl, [
      "-sS",
      "--remove-on-error",
      "-o",
      partial_path,
      base + "/partial",
    ])
    record_result(
      curl_partial.status == 7 &&
      !@fs.exists(partial_path) &&
      @testkit.contains_bytes(curl_partial.stderr, "response body"),
      "curl: partial response cleanup mismatch",
      failures,
    )
    let collision_root = @fs.tmpdir(prefix="mooncmd-http-collision")
    defer (@fs.rmdir(collision_root, recursive=true) catch { _ => () })
    let original = @path.Path(collision_root).join(Path("fixed")).to_string()
    let numbered = original + ".1"
    @fs.write_file(original, b"original")
    let wget_collision = @testkit.run(
      wget,
      ["-q", base + "/fixed"],
      cwd=collision_root,
    )
    record_result(
      wget_collision.status == 0 &&
      @testkit.bytes_equal(@fs.read_file(original).binary(), b"original") &&
      @testkit.bytes_equal(@fs.read_file(numbered).binary(), b"hello"),
      "wget: numbered output collision mismatch",
      failures,
    )
    let truncate = @path.Path(collision_root)
      .join(Path("truncate.bin"))
      .to_string()
    @fs.write_file(truncate, b"old-data")
    let wget_truncate = @testkit.run(wget, [
      "-q", "-t", "1", "-O", truncate, "http://127.0.0.1:1/unreachable",
    ])
    record_result(
      wget_truncate.status == 4 && @fs.read_file(truncate).binary().is_empty(),
      "wget: -O did not truncate before connection setup",
      failures,
    )
    let wget_name_root = @fs.tmpdir(prefix="mooncmd-http-wget-name")
    defer (@fs.rmdir(wget_name_root, recursive=true) catch { _ => () })
    let wget_encoded = @path.Path(wget_name_root)
      .join(Path("encoded.txt"))
      .to_string()
    @fs.write_file(wget_encoded, b"old")
    let wget_disposition = @testkit.run(
      wget,
      ["-q", "--content-disposition", base + "/named-encoded"],
      cwd=wget_name_root,
    )
    record_result(
      wget_disposition.status == 0 &&
      @testkit.bytes_equal(@fs.read_file(wget_encoded).binary(), b"old") &&
      @testkit.bytes_equal(
        @fs.read_file(wget_encoded + ".1").binary(),
        b"hello",
      ),
      "wget: content-disposition duplicate filename behavior mismatch",
      failures,
    )
    let curl_connect_ok = @testkit.run(curl, [
      "-s",
      "--connect-timeout",
      "0.1",
      base + "/fixed",
    ])
    let curl_max_timeout = @testkit.run(curl, [
      "-s",
      "--max-time",
      "0.02",
      base + "/body-stall",
    ])
    let curl_idle_timeout = @testkit.run(curl, [
      "-s",
      "--idle-timeout",
      "0.02",
      base + "/body-stall",
    ])
    let wget_connect_ok = @testkit.run(wget, [
      "-qO-",
      "--connect-timeout=0.1",
      base + "/fixed",
    ])
    let wget_total_timeout = @testkit.run(wget, [
      "-qO-",
      "-T",
      "0.02",
      base + "/stall",
    ])
    let wget_read_timeout = @testkit.run(wget, [
      "-qO-",
      "--read-timeout=0.02",
      base + "/body-stall",
    ])
    let wget_idle_timeout = @testkit.run(wget, [
      "-qO-",
      "--idle-timeout=0.02",
      base + "/body-stall",
    ])
    record_result(
      curl_connect_ok.status == 0 &&
      @testkit.bytes_equal(curl_connect_ok.stdout, b"hello") &&
      curl_max_timeout.status == 28 &&
      curl_idle_timeout.status == 28 &&
      wget_connect_ok.status == 0 &&
      @testkit.bytes_equal(wget_connect_ok.stdout, b"hello") &&
      wget_total_timeout.status == 4 &&
      wget_read_timeout.status == 4 &&
      wget_idle_timeout.status == 4,
      "curl/wget timeout expiry or successful connection mismatch",
      failures,
    )
  }
}

///|
async fn run_https_cases(bin_root : String, failures : Array[String]) -> Unit {
  if @platform.is_windows() {
    return
  }
  @async.with_task_group <| group => {
    let current = @env.current_dir().unwrap_or(".")
    let cert = @path.Path(current)
      .join(Path("tests/fixtures/http/cert.pem"))
      .to_string()
    let key = @path.Path(current)
      .join(Path("tests/fixtures/http/key.pem"))
      .to_string()
    let output_root = @fs.tmpdir(prefix="mooncmd-https")
    defer (@fs.rmdir(output_root, recursive=true) catch { _ => () })
    let log = @path.Path(output_root).join(Path("server.log")).to_string()
    let server = @process.spawn(
      group,
      @env.args()[0],
      ["--https-server", cert, key, log],
      no_console_window=true,
      no_wait=true,
    )
    let mut port : Int? = None
    for attempt = 0; attempt < 100; attempt = attempt + 1 {
      if @fs.exists(log) {
        let text = @fs.read_file(log).text()
        if text.find("ACCEPT ") is Some(index) {
          let suffix = text[index + 7:].to_owned()
          let line = suffix.split("\n").next().unwrap_or("")
          if line.rev_find(":") is Some(colon) {
            port = try @string.parse_int(line[colon + 1:].to_owned()) catch {
              _ => None
            } noraise {
              value => Some(value)
            }
            if port is Some(_) {
              break
            }
          }
        }
      }
      @async.sleep(10)
    }
    guard port is Some(port) else {
      server.cancel()
      ignore(server.wait()) catch {
        _ => ()
      }
      compat_fail("HTTPS fixture did not report a listening port", failures)
      return
    }
    let url = "https://127.0.0.1:\{port}/"
    let curl = @testkit.executable_path(bin_root, "curl")
    let wget = @testkit.executable_path(bin_root, "wget")
    let curl_verified = @testkit.run(curl, ["-sf", url])
    let curl_insecure = @testkit.run(curl, ["-skf", url])
    let wget_verified = @testkit.run(wget, ["-qO-", url])
    let wget_insecure = @testkit.run(wget, [
      "-qO-", "--no-check-certificate", url,
    ])
    record_result(
      curl_verified.status == 60 &&
      curl_insecure.status == 0 &&
      wget_verified.status == 5 &&
      wget_insecure.status == 0,
      "HTTPS certificate verification controls mismatch",
      failures,
    )
    server.cancel()
    ignore(server.wait()) catch {
      _ => ()
    }
  }
}

///|
async fn run_connect_proxy(
  server : @socket.TcpServer,
  requests : Ref[Int],
) -> Unit {
  server.run_forever() <| ((client, _) => {
    requests.val = requests.val + 1
    guard client.read_until("\r\n") is Some(line) else { return }
    while client.read_until("\r\n") is Some(header) && header != "" {

    }
    guard line.has_prefix("CONNECT ") && line.find(" HTTP/") is Some(end) else {
      client.write("HTTP/1.1 400 Bad Request\r\nContent-Length: 0\r\n\r\n")
      return
    }
    let authority = line[8:end].to_owned()
    let destination = @socket.Tcp::connect(@socket.Addr::parse(authority))
    defer destination.close()
    client.write("HTTP/1.1 200 Connection Established\r\n\r\n")
    @async.with_task_group <| relay => {
      relay.spawn_bg(no_wait=true) <| () => { client.write_reader(destination) }
      destination.write_reader(client)
    }
  })
}

///|
async fn run_proxy_cases(bin_root : String, failures : Array[String]) -> Unit {
  @async.with_task_group <| group => {
    let origin = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    group.add_defer(() => origin.close())
    group.spawn_bg(no_wait=true) <| () => {
      origin.run_forever() <| ((_, _, connection) => {
        connection.send_response(200, "OK", extra_headers={
          "Content-Length": "5",
        })
        connection..write("hello").end_response()
      })
    }
    let proxy = @socket.TcpServer(@socket.Addr::parse("127.0.0.1:0"))
    group.add_defer(() => proxy.close())
    let proxy_requests = Ref(0)
    group.spawn_bg(no_wait=true, () => run_connect_proxy(proxy, proxy_requests))
    let proxy_url = "http://127.0.0.1:\{proxy.addr.port()}"
    let url = "http://127.0.0.1:\{origin.addr.port()}/fixed"
    let curl = @testkit.executable_path(bin_root, "curl")
    let wget = @testkit.executable_path(bin_root, "wget")
    let curl_proxy = @testkit.run(
      curl,
      ["-s", "--proxy", proxy_url, "--noproxy", "", url],
      extra_env=Map([("NO_PROXY", "")]),
    )
    let wget_proxy = @testkit.run(
      wget,
      ["-qO-", url],
      extra_env=Map([
        ("http_proxy", proxy_url),
        ("HTTP_PROXY", ""),
        ("NO_PROXY", ""),
        ("no_proxy", ""),
      ]),
    )
    record_result(
      curl_proxy.status == 0 &&
      @testkit.bytes_equal(curl_proxy.stdout, b"hello") &&
      wget_proxy.status == 0 &&
      @testkit.bytes_equal(wget_proxy.stdout, b"hello") &&
      proxy_requests.val == 2,
      "HTTP CONNECT proxy transfer mismatch",
      failures,
    )
    let curl_bypass = @testkit.run(
      curl,
      ["-s", "--proxy", "http://127.0.0.1:1", "--noproxy", "127.0.0.1", url],
      extra_env=Map([("NO_PROXY", "")]),
    )
    let wget_bypass = @testkit.run(
      wget,
      ["-qO-", "--no-proxy", url],
      extra_env=Map([
        ("http_proxy", "http://127.0.0.1:1"),
        ("HTTP_PROXY", "http://127.0.0.1:1"),
        ("NO_PROXY", ""),
        ("no_proxy", ""),
      ]),
    )
    record_result(
      curl_bypass.status == 0 &&
      @testkit.bytes_equal(curl_bypass.stdout, b"hello") &&
      wget_bypass.status == 0 &&
      @testkit.bytes_equal(wget_bypass.stdout, b"hello") &&
      proxy_requests.val == 2,
      "curl --noproxy or wget --no-proxy did not bypass the proxy",
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
      compat_fail(
        "\{command}: candidate differential run failed: \{err}",
        failures,
      )
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
      compat_fail("\{command}: GNU oracle failed: \{err}", failures)
      return
    }
  }
  if candidate.status != oracle.status {
    compat_fail(
      "\{command}: GNU status mismatch: candidate=\{candidate.status}, oracle=\{oracle.status}",
      failures,
    )
  }
  if !@testkit.bytes_equal(candidate.stdout, oracle.stdout) {
    compat_fail(
      "\{command}: GNU stdout mismatch: candidate=\{candidate.stdout}, oracle=\{oracle.stdout}",
      failures,
    )
  }
}

///|
async fn compare_gnu_tail_follow(
  bin_root : String,
  failures : Array[String],
) -> Unit {
  let args = ["-f", "-q", "-n", "1"]
  let candidate = run_tail_follow_process(
    @testkit.executable_path(bin_root, "tail"),
    args,
    [b"first\nsecond\n"],
    [b"third\n"],
    [None],
    poll_wait_ms=1200,
  )
  let oracle = run_tail_follow_process(
    "tail",
    args,
    [b"first\nsecond\n"],
    [b"third\n"],
    [None],
    poll_wait_ms=1200,
  )
  if !@testkit.bytes_equal(candidate.0, oracle.0) {
    compat_fail(
      "tail: GNU follow stdout mismatch; candidate=\{candidate.0}, oracle=\{oracle.0}",
      failures,
    )
  }
  if !@testkit.bytes_equal(candidate.1, oracle.1) {
    compat_fail(
      "tail: GNU follow stderr mismatch; candidate=\{candidate.1}, oracle=\{oracle.1}",
      failures,
    )
  }
  let candidate_truncate = run_tail_follow_process(
    @testkit.executable_path(bin_root, "tail"),
    args,
    [b"before\n"],
    [b"append\n"],
    [Some(b"reset\n")],
    poll_wait_ms=1200,
  )
  let oracle_truncate = run_tail_follow_process(
    "tail",
    args,
    [b"before\n"],
    [b"append\n"],
    [Some(b"reset\n")],
    poll_wait_ms=1200,
  )
  if !@testkit.bytes_equal(candidate_truncate.0, oracle_truncate.0) {
    compat_fail(
      "tail: GNU truncate stdout mismatch; candidate=\{candidate_truncate.0}, oracle=\{oracle_truncate.0}",
      failures,
    )
  }
  if candidate_truncate.1.length() != 0 {
    compat_fail(
      "tail: descriptor follow must recover from truncation silently: \{candidate_truncate.1}",
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
  compare_gnu_tail_follow(bin_root, failures)
  compare_gnu(bin_root, "tr", ["a-z", "A-Z"], b"hello world\n", failures)
}

///|
async fn run_compat_suite(
  bin_root : String,
  gnu_diff : Bool,
  stress : Bool,
  failures : Array[String],
) -> Unit {
  check_catalog(bin_root, true, failures)
  if !failures.is_empty() {
    return
  }
  run_catalog_smoke(bin_root, failures)
  run_option_boundaries(bin_root, failures)
  run_environment_boundary_cases(bin_root, failures)
  run_filesystem_cases(bin_root, failures)
  run_chunk_boundary_cases(bin_root, failures)
  run_merge_cases(bin_root, failures)
  run_phase345_cases(bin_root, failures)
  run_p5_sh_cases(bin_root, failures)
  run_p2_p3_cases(bin_root, failures)
  run_edge_cases(bin_root, failures)
  run_p9_cases(bin_root, failures)
  run_stdin_prompt_cases(bin_root, failures)
  run_tail_follow_cases(bin_root, failures)
  run_http_cases(bin_root, failures)
  run_https_cases(bin_root, failures)
  run_proxy_cases(bin_root, failures)
  if gnu_diff {
    run_gnu_differential(bin_root, failures)
  }
  if stress {
    run_stress_cases(bin_root, failures)
  }
}
