///|
fn pipe_writer_closed(error : Error) -> Bool {
  match error {
    @os_error.OSError(code, context~) =>
      context == "@process.WriteToProcess::write()" &&
      (if @async.platform is Windows {
        // Raw Win32 ERROR_BROKEN_PIPE and ERROR_NO_DATA from the async SDK.
        code == 109 || code == 232
      } else {
        // POSIX EPIPE on the supported Unix tool hosts.
        code == 32
      })
    _ => false
  }
}

///|
// Source opening, pipe allocation, bounded reads, writes and direct-child
// cleanup belong to this duration. Output redirection is untimed setup, as it
// is for the regular-file transport; output goes to files in both modes.
async fn measure_invocation_pipe(
  invocation : BenchmarkInvocation,
  stdout_path : String,
  stderr_path : String,
  timeout_ms : Int32,
  chunk_bytes : Int32,
  allow_early_close~ : Bool = false,
) -> ProcessObservation {
  measure_invocation_pipe_with_source(
    invocation,
    stdout_path,
    stderr_path,
    timeout_ms,
    chunk_bytes,
    allow_early_close~,
  )
}

///|
async fn measure_invocation_pipe_with_source(
  invocation : BenchmarkInvocation,
  stdout_path : String,
  stderr_path : String,
  timeout_ms : Int32,
  chunk_bytes : Int32,
  allow_early_close~ : Bool = false,
  read_chunk~ : async (@fs.File, Int64, Int32) -> Bytes = (
    source,
    offset,
    length,
  ) => source.read_exactly_at(length, position=offset),
) -> ProcessObservation {
  guard chunk_bytes > 0 && chunk_bytes <= 1048576 else {
    fail("pipe producer chunk_bytes must be between 1 and 1048576")
  }
  guard timeout_ms > 0 else { fail("pipe producer timeout must be positive") }
  let output = @process.redirect_to_file(stdout_path)
  defer output.close()
  let errors = @process.redirect_to_file(stderr_path)
  defer errors.close()
  let status : Ref[Int32?] = Ref(None)
  let cleanup_error : Ref[String?] = Ref(None)
  let write_error : Ref[Error?] = Ref(None)
  let started = @bench.monotonic_clock_start()
  let mut error : String? = None
  let finished = @async.with_timeout_opt(timeout_ms, () => {
    let source = @fs.open(invocation.stdin_path, mode=ReadOnly)
    defer source.close()
    let size = source.size()
    // Open the source before creating temporary process input. Missing sources
    // then fail without leaving an unconsumed temporary read descriptor.
    let (input, writer) = @process.write_to_process()
    // Keep these handles alive until task-group cancellation has joined
    // pending IO, following the ownership in testkit/deadline.
    defer writer.close()
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
        no_console_window=true,
        no_wait=true,
        cancel_handler=@process.hard_cancel(),
      )
      group.add_defer(() => {
        writer.close()
        child.cancel()
        @async.protect_from_cancel(() => {
          try child.wait() catch {
            failure => cleanup_error.val = Some(failure.to_string())
          } noraise {
            exited => status.val = Some(exited)
          }
        })
      })
      let producer = group.spawn(() => {
        defer writer.close()
        let mut offset = 0L
        while offset < size {
          let length = (size - offset).min(chunk_bytes.to_int64()).to_int()
          let bytes = read_chunk(source, offset, length)
          guard bytes.length() == length else {
            fail("pipe producer returned a short source chunk")
          }
          // Await each complete write before reading another chunk. The OS may
          // split or combine writes; chunk_bytes describes producer writes,
          // rather than promising the child's individual read boundaries.
          // Catch only this pipe write. A source read error must still cancel
          // the group, even when a workload permits an early consumer exit.
          let written = try {
            writer.write(bytes)
            true
          } catch {
            failure => {
              write_error.val = Some(failure)
              false
            }
          }
          if !written {
            break
          }
          offset += length.to_int64()
        }
      })
      status.val = Some(child.wait())
      producer.wait()
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
  if !timed_out && error is None && write_error.val is Some(failure) {
    if !(allow_early_close &&
      status.val == Some(0) &&
      pipe_writer_closed(failure)) {
      error = Some("pipe producer write failed: " + failure.to_string())
    }
  }
  {
    elapsed_us: @bench.monotonic_clock_end(started),
    status: status.val,
    timed_out,
    error,
  }
}
