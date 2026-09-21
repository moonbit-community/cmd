///|
pub(all) struct TimedRun {
  output : RunResult
  timed_out : Bool
  cleanup_error : String?
}

///|
/// Capture bytes as they arrive so a driver deadline retains partial output.
/// Cleanup covers the direct child; inherited descriptors in grandchildren are
/// not a process-tree ownership guarantee.
pub async fn run_with_deadline(
  program : String,
  args : Array[String],
  timeout_ms : Int,
  stdin? : Bytes = b"",
  cwd? : String,
  extra_env? : Map[String, String] = Map([]),
  inherit_env? : Bool = true,
) -> TimedRun {
  let stdout_buffer = @buffer.Buffer()
  let stderr_buffer = @buffer.Buffer()
  let exit_status = Ref(-1)
  let cleanup_error : Ref[String?] = Ref(None)
  // Keep handles alive until the task group has finished cancelling pending
  // IO. Closing them from the group's body races Windows IO completion.
  let (input, writer) = @process.write_to_process()
  defer writer.close()
  let (reader_out, output) = @process.read_from_process()
  defer reader_out.close()
  let (reader_err, error_output) = @process.read_from_process()
  defer reader_err.close()
  let finished = @async.with_timeout_opt(timeout_ms, () => {
    @async.with_task_group(group => {
      let child = @process.spawn(
        group,
        program,
        args,
        stdin=input,
        stdout=output,
        stderr=error_output,
        cwd?=cwd.map(value => value[:]),
        extra_env~,
        inherit_env~,
        no_wait=true,
        no_console_window=true,
        cancel_handler=@process.hard_cancel(),
      )
      group.add_defer(() => {
        writer.close()
        child.cancel()
        @async.protect_from_cancel(() => {
          exit_status.val = child.wait() catch {
            error => {
              cleanup_error.val = Some(error.to_string())
              -1
            }
          }
        })
        reader_out.close()
        reader_err.close()
      })
      let out_task = group.spawn(() => {
        while reader_out.read_some() is Some(bytes) {
          stdout_buffer.write_bytes(bytes)
        }
      })
      let err_task = group.spawn(() => {
        while reader_err.read_some() is Some(bytes) {
          stderr_buffer.write_bytes(bytes)
        }
      })
      let input_task = group.spawn(() => {
        defer writer.close()
        writer.write(stdin) catch {
          error =>
            match (@async.platform, error) {
              (Linux | MacOS, @os_error.OSError(32, ..)) => ()
              (Windows, @os_error.OSError(109, ..)) => ()
              (_, @io.PipeClosed) => ()
              _ => raise error
            }
        }
      })
      exit_status.val = child.wait()
      input_task.wait()
      out_task.wait()
      err_task.wait()
    })
  })
  {
    output: {
      status: exit_status.val,
      stdout: stdout_buffer.to_bytes(),
      stderr: stderr_buffer.to_bytes(),
    },
    timed_out: finished is None,
    cleanup_error: cleanup_error.val,
  }
}
