///|
async fn scenario_read_exact(
  reader : &@io.Reader,
  trace : String,
  expected : String,
  assertion_id? : String,
) -> Unit {
  let expected = @utf8.encode(expected)
  let observed : Array[Byte] = []
  let mut offset = 0
  while offset < expected.length() {
    guard reader.read_some(max_len=expected.length() - offset) is Some(bytes) else {
      fail("unexpected stream EOF")
    }
    @fs.write_file(trace, bytes, append=true)
    for byte in bytes {
      observed.push(byte)
    }
    assert_eq(bytes, expected[offset:offset + bytes.length()].to_owned())
    offset += bytes.length()
  }
  if assertion_id is Some(id) {
    @harness.assert_observation(
      id,
      "sh",
      Json(@harness.scenario_text(Bytes::from_array(observed))),
      Json(@harness.scenario_text(expected)),
    )
  }
}

///|
async fn scenario_run(
  work : String,
  root : String,
  command : String,
  args : Array[String],
  stdin~ : Bytes = b"",
  cwd? : String,
  extra_env~ : Map[String, String] = Map([]),
) -> @harness.RunResult {
  let traces = @path.Path(work).dirname().join(Path("streams")).to_string()
  if !@fs.exists(traces) {
    @fs.mkdir(traces, recursive=true)
  }
  let prefix = traces + "/" + command + "-\{@fs.readdir(traces).length()}"
  let completed = @harness.run_with_deadline(
    @harness.command_program(),
    @harness.command_args(root, command, args),
    15000,
    stdin~,
    cwd?,
    extra_env~,
  )
  @fs.write_file(prefix + ".stdout.bin", completed.output.stdout)
  @fs.write_file(prefix + ".stderr.bin", completed.output.stderr)
  @fs.write_file(prefix + ".status.txt", completed.output.status.to_string())
  if completed.cleanup_error is Some(error) {
    fail("cleanup infrastructure: " + error)
  }
  if completed.timed_out {
    fail("scenario command deadline expired; streams are partial")
  }
  completed.output
}

///|
fn shell_quote(value : String) -> String {
  "'" + value.replace_all(old="'", new="'\\''") + "'"
}

///|
pub async fn run_test_helper(args : ArrayView[String]) -> Unit {
  match args {
    ["jobserver-bridge", work] => jobserver_bridge(work)
    ["environment", name] =>
      @stdio.stdout.write(@env.get_env_var(name).unwrap_or("") + "\n")
    ["wait-ready"] => {
      @stdio.stdout.write("ready\n")
      @async.sleep(60000)
    }
    ["capture-then-wait"] => {
      @stdio.stdout.write("partial stdout\n")
      @stdio.stderr.write("partial stderr\n")
      @async.sleep(60000)
    }
    ["alternating-streams"] => {
      for _ in 0..<64 {
        @stdio.stdout.write("out-one\n")
        @stdio.stderr.write("err-one\n")
        @stdio.stdout.write("out-two\n")
        @stdio.stderr.write("err-two\n")
      }
      @sys.exit(7)
    }
    ["status-124"] => @sys.exit(124)
    ["read-line"] =>
      for ;; {
        guard @stdio.stdin.read_some(max_len=1) is Some(byte) else { break }
        @stdio.stdout.write(byte)
        if byte == b"\n" {
          break
        }
      }
    ["ready", root, name] => {
      @fs.write_file(root + "/" + name + ".ready", "ready")
      @async.with_timeout(10000, () => {
        while !@fs.exists(root + "/" + name + ".ack") {
          @async.sleep(5)
        }
      })
      @fs.write_file(root + "/" + name + ".done", "done")
    }
    _ => fail("unknown test helper")
  }
}
