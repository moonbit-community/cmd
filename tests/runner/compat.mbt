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
  if catalog.length() != 59 {
    compat_fail(
      "catalog: expected 59 commands, got \{catalog.length()}",
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
}
