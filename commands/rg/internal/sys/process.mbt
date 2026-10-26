///|
pub struct Process {
  priv reader : @io.MemoryReader
  priv child : Ref[@process.Process?]
  priv failure : Ref[Error?]
  priv stderr : @buffer.Buffer
  priv complete : Ref[Bool]
  priv changed : @cond_var.Cond
  priv mut eof : Bool
  priv mut closed : Bool
}

///|
pub(all) struct ProcessOutput {
  status : Int32
  stdout : Bytes
  stderr : Bytes
} derive(Debug, Eq)

///|
pub async fn Process::spawn(
  program : String,
  args : Array[String],
  stdin_path? : String,
) -> Process {
  let child = Ref(None)
  let failure = Ref(None)
  let complete = Ref(false)
  let started = Ref(false)
  let changed = @cond_var.Cond()
  let stderr = @buffer.Buffer()
  let reader = @io.MemoryReader(output => {
    defer {
      complete.val = true
      changed.broadcast()
    }
    started.val = true
    try {
      // Pending Windows reads must finish cancellation before pipe handles close.
      let (stdout_reader, stdout_sink) = @process.read_from_process()
      defer stdout_reader.close()
      let (stderr_reader, stderr_sink) = @process.read_from_process()
      defer stderr_reader.close()
      let stderr_complete = Ref(false)
      @async.with_task_group() <| group => {
        group.spawn_bg() <| () => {
          defer {
            stderr_complete.val = true
            changed.broadcast()
          }
          let chunk = FixedArray::make(8192, b'\x00')
          for ;; {
            let count = stderr_reader.read(chunk)
            if count == 0 {
              break
            }
            stderr.write_bytes(Bytes::from_array(chunk[:count]))
          }
        }
        let stdin = match stdin_path {
          Some(path) => Some(@process.redirect_from_file(path))
          None => None
        }
        let process = @process.spawn(
          group,
          program,
          args,
          stdin?,
          stdout=stdout_sink,
          stderr=stderr_sink,
          inherit_env=true,
          no_wait=true,
          cancel_handler=@process.hard_cancel(),
        )
        child.val = Some(process)
        changed.broadcast()
        output.write_reader(stdout_reader)
        ignore(process.wait())
        while !stderr_complete.val {
          changed.wait()
        }
      }
    } catch {
      error => {
        failure.val = Some(error)
        changed.broadcast()
      }
    }
  })
  let mut delivered = false
  defer (if !delivered {
    reader.close()
    @async.protect_from_cancel() <| () => {
      while started.val && !complete.val {
        changed.wait()
      }
    }
  })
  while child.val is None && !complete.val {
    changed.wait()
  }
  if child.val is None {
    reader.close()
    raise from_error(
      failure.val.unwrap_or(IOError::other(Other, "preprocessor did not start")),
    )
  }
  delivered = true
  {
    reader,
    child,
    failure,
    stderr,
    complete,
    changed,
    eof: false,
    closed: false,
  }
}

///|
pub async fn Process::read(
  self : Process,
  buf : FixedArray[Byte],
  start : Int32,
  len : Int32,
) -> Int32 {
  if self.closed {
    return 0
  }
  let count = self.reader.read(buf, offset=start, max_len=len)
  if count == 0 {
    self.eof = true
  }
  count
}

///|
pub async fn Process::finish(self : Process) -> (Int32, Bytes) {
  if !self.closed {
    self.closed = true
    if !self.eof {
      self.reader.close()
    }
  }
  @async.protect_from_cancel() <| () => {
    while !self.complete.val {
      self.changed.wait()
    }
    let status = match self.child.val {
      Some(child) => child.try_wait().unwrap_or(-1)
      None => -1
    }
    if self.eof && self.failure.val is Some(error) {
      raise from_error(error)
    }
    (status, self.stderr.to_bytes())
  }
}

///|
pub async fn run_command(
  program : String,
  args : Array[String],
  stdin_path? : String,
) -> ProcessOutput {
  let child = Process::spawn(program, args, stdin_path?)
  defer ignore(child.finish())
  let stdout = @buffer.Buffer()
  let chunk = FixedArray::make(65536, b'\x00')
  for ;; {
    let count = child.read(chunk, 0, chunk.length())
    if count == 0 {
      break
    }
    stdout.write_bytes(Bytes::from_array(chunk[:count]))
  }
  let (status, stderr) = child.finish()
  { status, stdout: stdout.to_bytes(), stderr, }
}
