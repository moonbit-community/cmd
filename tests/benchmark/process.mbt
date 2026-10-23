///|
priv struct BenchmarkInvocation {
  program : String
  args : Array[String]
  cwd : String
  environment : Map[String, String]
  stdin_path : String
} derive(ToJson)

///|
priv struct ProcessObservation {
  elapsed_us : Double
  status : Int32?
  timed_out : Bool
  error : String?
} derive(ToJson)

///|
// Redirect setup is outside timing; process startup, IO, flush and exit are in
// the measured call. Public process.run waits for direct-child termination even
// when cancelled. Failed or timed-out observations never supply passing samples.
async fn measure_invocation(
  invocation : BenchmarkInvocation,
  stdout_path : String,
  stderr_path : String,
  timeout_ms : Int32,
) -> ProcessObservation {
  let output = @process.redirect_to_file(stdout_path)
  defer output.close()
  let errors = @process.redirect_to_file(stderr_path)
  defer errors.close()
  let input = @process.redirect_from_file(invocation.stdin_path)
  let started = @bench.monotonic_clock_start()
  let mut error = None
  let status = @async.with_timeout_opt(timeout_ms, () => {
    @process.run(
      invocation.program,
      invocation.args,
      stdin=input,
      stdout=output,
      stderr=errors,
      cwd=invocation.cwd[:],
      extra_env=invocation.environment,
      no_console_window=true,
      cancel_handler=@process.hard_cancel(),
    )
  }) catch {
    failure => {
      error = Some(failure.to_string())
      None
    }
  }
  {
    elapsed_us: @bench.monotonic_clock_end(started),
    status,
    timed_out: status is None && error is None,
    error,
  }
}

///|
// Large captures are compared after timing without retaining them in memory.
async fn files_equal(left : String, right : String) -> Bool {
  let left_file = @fs.open(left, mode=ReadOnly)
  defer left_file.close()
  let right_file = @fs.open(right, mode=ReadOnly)
  defer right_file.close()
  let size = left_file.size()
  if size != right_file.size() {
    return false
  }
  let mut offset = 0L
  while offset < size {
    let count = (size - offset).min(65536L).to_int()
    if left_file.read_exactly_at(count, position=offset) !=
      right_file.read_exactly_at(count, position=offset) {
      return false
    }
    offset += count.to_int64()
  }
  true
}
