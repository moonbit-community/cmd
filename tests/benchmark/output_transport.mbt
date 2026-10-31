///|
// Deliberate consumer delay is part of this transport scenario. This duration
// is not raw engine throughput and the delay is never subtracted.
async fn measure_invocation_slow_output(
  invocation : BenchmarkInvocation,
  stdout_path : String,
  stderr_path : String,
  timeout_ms : Int32,
  chunk_bytes : Int32,
  delay_ms : Int32,
  fail_after? : Int64,
) -> ProcessObservation {
  guard chunk_bytes > 0 &&
    chunk_bytes <= 65537 &&
    delay_ms >= 1 &&
    delay_ms <= 20 &&
    timeout_ms > 0 else {
    fail("invalid slow output bounds")
  }
  let capture = @fs.create(stdout_path)
  defer capture.close()
  let errors = @process.redirect_to_file(stderr_path)
  defer errors.close()
  let input = @process.redirect_from_file(invocation.stdin_path)
  let status : Ref[Int32?] = Ref(None)
  let cleanup_error : Ref[String?] = Ref(None)
  let mut error : String? = None
  let started = @bench.monotonic_clock_start()
  let finished = @async.with_timeout_opt(timeout_ms, () => {
    let (reader, output) = @process.read_from_process()
    defer reader.close()
    @async.with_task_group(group => {
      let child = @process.spawn(
        group,
        invocation.program,
        invocation.args,
        stdin=input,
        stdout=output,
        stderr=errors,
        cwd=invocation.cwd[:],
        extra_env=invocation.environment,
        no_wait=true,
        no_console_window=true,
        cancel_handler=@process.hard_cancel(),
      )
      group.add_defer(() => {
        reader.close()
        child.cancel()
        @async.protect_from_cancel(() => {
          try child.wait() catch {
            failure => cleanup_error.val = Some(failure.to_string())
          } noraise {
            exited => status.val = Some(exited)
          }
        })
      })
      let consumer = group.spawn(() => {
        let mut copied = 0L
        while reader.read_some(max_len=chunk_bytes) is Some(bytes) {
          capture.write(bytes)
          copied += bytes.length().to_int64()
          if fail_after is Some(limit) && copied >= limit {
            fail("injected slow consumer failure")
          }
          @async.sleep(delay_ms)
        }
      })
      status.val = Some(child.wait())
      consumer.wait()
    })
  }) catch {
    failure => {
      error = Some(failure.to_string())
      None
    }
  }
  let timed_out = finished is None && error is None
  if cleanup_error.val is Some(cleanup) {
    error = Some(
      error.map(value => value + "; ").unwrap_or("") +
      "direct-child cleanup failed: " +
      cleanup,
    )
  }
  {
    elapsed_us: @bench.monotonic_clock_end(started),
    status: status.val,
    timed_out,
    error,
  }
}
