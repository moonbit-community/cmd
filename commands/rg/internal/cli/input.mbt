///|
/// Returns true if stdin can be usefully read (a file or pipe, not a tty).
pub fn is_readable_stdin() -> @sys.Capability[Bool] {
  @sys.stdin_is_readable()
}

///|
/// Returns the hostname of the current system.
pub fn hostname() -> String? {
  @sys.hostname()
}

///|
/// Reads patterns from a file, one per line, with errors that include the
/// path (and line number).
pub async fn patterns_from_path(path : String) -> Array[String] {
  let data = @sys.read_file(path) catch {
    e => raise PatternsError("\{path}: \{e}")
  }
  patterns_from_bytes(data) catch {
    PatternsError(msg) => raise PatternsError("\{path}:\{msg}")
  }
}

///|
/// Reads patterns from stdin, one per line.
pub async fn patterns_from_stdin() -> Array[String] {
  let buf = Buffer()
  let chunk = FixedArray::make(65536, b'\x00')
  while true {
    let n = @sys.read_fd(0, chunk, 0, chunk.length()) catch {
      e => raise PatternsError("<stdin>:\{e}")
    }
    if n == 0 {
      break
    }
    for i in 0..<n {
      buf.write_byte(chunk[i])
    }
  }
  patterns_from_bytes(buf.to_bytes()) catch {
    PatternsError(msg) => raise PatternsError("<stdin>:\{msg}")
  }
}
