///|
/// An error from running a command.
pub suberror CommandError {
  /// An I/O error (e.g. the command could not be spawned).
  CommandIo(@sys.IOError)
  /// The command failed; the payload is its stderr.
  CommandStderr(Bytes)
} derive(Debug)

///|
pub fn CommandError::to_string(self : CommandError) -> String {
  match self {
    CommandIo(e) => e.to_string()
    CommandStderr(bytes) => {
      let msg = @utf8.decode_lossy(bytes)
      if msg.trim().is_empty() {
        "<stderr is empty>"
      } else {
        let div = "-".repeat(79)
        "\n\{div}\n\{msg.trim()}\n\{div}"
      }
    }
  }
}

///|
pub impl Show for CommandError with fn output(self, logger) {
  logger.write_string(self.to_string())
}

///|
/// Reads the stdout of a command as it runs (like grep-cli's
/// `CommandReader`): stopping early closes the command's stdout, which
/// makes a well-behaved command exit.
pub struct CommandReader {
  priv child : @sys.Process
  priv mut eof : Bool
  priv mut closed : Bool
}

///|
/// Runs `program` with `args`, optionally feeding `stdin_path` as stdin.
pub async fn CommandReader::new(
  program : String,
  args : Array[String],
  stdin_path? : String,
) -> CommandReader {
  let child = @sys.Process::spawn(program, args, stdin_path?) catch {
    e => raise CommandIo(@sys.from_error(e))
  }
  { child, eof: false, closed: false, }
}

///|
/// Reads into `buf[start:start+len]`, checking process status at EOF.
pub async fn CommandReader::read(
  self : CommandReader,
  buf : FixedArray[Byte],
  start : Int32,
  len : Int32,
) -> Int32 {
  if self.closed {
    return 0
  }
  let n = self.child.read(buf, start, len) catch {
    e => raise CommandIo(@sys.from_error(e))
  }
  if n == 0 {
    self.eof = true
    self.close()
  }
  n
}

///|
/// Closes the command's stdout and waits for it to exit, raising an error
/// if it failed. Like ripgrep, a failure without any stderr output is
/// ignored if the output wasn't read to the end (the command was most likely
/// killed by the closed pipe).
pub async fn CommandReader::close(self : CommandReader) -> Unit {
  if self.closed {
    return
  }
  self.closed = true
  let (status, stderr) = self.child.finish() catch {
    e => raise CommandIo(@sys.from_error(e))
  }
  if status == 0 {
    return
  }
  if !self.eof && stderr.length() == 0 {
    return
  }
  raise CommandStderr(stderr)
}

///|
/// Returns all of the command's stdout, raising if it failed.
pub async fn CommandReader::read_to_end(self : CommandReader) -> Bytes {
  let out = Buffer()
  let chunk = FixedArray::make(65536, b'\x00')
  for ;; {
    let n = self.read(chunk, 0, chunk.length())
    if n == 0 {
      break
    }
    out.write_bytes(chunk.unsafe_reinterpret_as_bytes()[0:n])
  }
  out.to_bytes()
}
