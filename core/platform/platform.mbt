///|
pub(all) enum Platform {
  Windows
  Posix
} derive(Eq, Debug)

///|
pub(all) enum StandardStream {
  Stdin
  Stdout
  Stderr
} derive(Eq, Debug)

///|
/// Terminal-sensitive output is command policy, not a side effect of reading
/// stdin. `IfTerminal` is suitable only when the pinned upstream command uses
/// dynamic terminal feedback for that stream.
pub(all) enum TerminalPolicy {
  Silent
  IfTerminal
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
/// The portable filesystem exposes kind, size, and modification timestamps;
/// owner/group and permission-bit reads are intentionally not inferred.
pub fn metadata_reads_supported() -> Bool {
  true
}

///|
pub fn permission_reads_supported() -> Bool {
  false
}

///|
pub fn timestamp_mutation_supported() -> Bool {
  false
}

///|
pub fn hard_links_supported() -> Bool {
  false
}

///|
pub fn readlink_supported() -> Bool {
  false
}

///|
pub fn cross_device_rename_classification_supported() -> Bool {
  false
}

///|
pub fn special_file_policy_supported() -> Bool {
  false
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
  is_terminal(Stdin)
}

///|
/// Return whether standard output is a proven interactive character device.
pub async fn stdout_is_terminal() -> Bool {
  is_terminal(Stdout)
}

///|
/// Return whether standard error is an interactive character device.
pub async fn stderr_is_terminal() -> Bool {
  is_terminal(Stderr)
}

///|
pub fn terminal_policy_allows(
  policy : TerminalPolicy,
  proven_terminal : Bool,
) -> Bool {
  policy == IfTerminal && proven_terminal
}

///|
pub async fn terminal_output_enabled(
  policy : TerminalPolicy,
  stream : StandardStream,
) -> Bool {
  terminal_policy_allows(policy, is_terminal(stream))
}

///|
/// The public async filesystem API can open the POSIX `/dev/fd` aliases and
/// expose the kind recorded on the returned file handle. Windows keeps the
/// conservative false result because `CONIN$`/`CONOUT$` do not describe
/// redirected handles.
pub async fn is_terminal(stream : StandardStream) -> Bool {
  if is_windows() {
    return false
  }
  let (path, mode) = match stream {
    Stdin => ("/dev/fd/0", @fs.Mode::ReadOnly)
    Stdout => ("/dev/fd/1", @fs.Mode::WriteOnly)
    Stderr => ("/dev/fd/2", @fs.Mode::WriteOnly)
  }
  let file = @fs.open(path, mode~) catch { _ => return false }
  defer file.close()
  file.kind() is @fs.FileKind::CharDevice
}
