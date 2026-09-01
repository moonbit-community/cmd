///|
pub(all) enum Platform {
  Windows
  Posix
} derive(Eq, Debug)

///|
pub fn current() -> Platform {
  if @path.sep == '\\' {
    Windows
  } else {
    Posix
  }
}

///|
pub fn is_windows() -> Bool {
  current() == Windows
}

///|
pub fn permission_mutation_supported() -> Bool {
  !is_windows()
}

///|
pub fn symbolic_links_supported() -> Bool {
  !is_windows()
}

///|
pub fn native_separator() -> Char {
  @path.sep
}

///|
pub fn accepts_separator(char : Char) -> Bool {
  char == '/' || (is_windows() && char == '\\')
}

///|
pub fn normalize_input_separators(path : String) -> String {
  if !is_windows() {
    return path
  }
  path.replace_all(old="/", new="\\")
}

///|
/// Return whether standard input is an interactive character device.
/// Errors and non-terminal inputs are treated as non-interactive so that
/// pipelines and redirected input keep their normal blocking semantics.
pub async fn stdin_is_terminal() -> Bool {
  stdio_is_terminal(0)
}

///|
/// Return whether standard error is an interactive character device.
pub async fn stderr_is_terminal() -> Bool {
  stdio_is_terminal(2)
}

///|
/// The public async filesystem API can open the POSIX `/dev/fd` aliases and
/// expose the kind recorded on the returned file handle. Windows keeps the
/// conservative false result because `CONIN$`/`CONOUT$` do not describe
/// redirected handles.
async fn stdio_is_terminal(fd : Int) -> Bool {
  if is_windows() {
    return false
  }
  let path = if fd == 0 { "/dev/fd/0" } else { "/dev/fd/2" }
  let mode = if fd == 0 { @fs.Mode::ReadOnly } else { @fs.Mode::WriteOnly }
  let file = @fs.open(path, mode~) catch { _ => return false }
  defer file.close()
  file.kind() is @fs.FileKind::CharDevice
}
