///|
pub fn os() -> Os {
  match @async.platform {
    Linux => Linux
    MacOS => MacOs
    Windows => Windows
  }
}

///|
pub fn supports_binary_stdout() -> Bool {
  true
}

///|
pub async fn write_stdout(data : Bytes) -> Unit raise IoError {
  @stdio.stdout.write(data) catch {
    error => raise IoError(Other, error.to_string())
  }
}

///|
pub async fn write_stdout_buffered(data : Bytes) -> Unit raise IoError {
  write_stdout(data)
}

///|
pub async fn print_stdout(text : String) -> Unit raise IoError {
  @stdio.stdout.write(text) catch {
    error => raise IoError(Other, error.to_string())
  }
}

///|
pub async fn print_stderr(text : String) -> Unit {
  @stdio.stderr.write(text)
}

///|
pub fn flush_stdout() -> Unit {

}

///|
pub fn flush_stderr() -> Unit {

}

///|
pub async fn read_stdin() -> Bytes raise IoError {
  @stdio.stdin.read_all().binary() catch {
    error => raise IoError(Other, error.to_string())
  }
}
