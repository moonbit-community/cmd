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
  match @async.platform {
    Windows => Windows
    Linux | MacOS => Posix
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
pub fn file_kind_reads_supported() -> Bool {
  true
}

///|
pub fn regular_file_size_reads_supported() -> Bool {
  true
}

///|
pub fn access_time_reads_supported() -> Bool {
  true
}

///|
pub fn modification_time_reads_supported() -> Bool {
  true
}

///|
pub fn status_change_time_reads_supported() -> Bool {
  true
}

///|
pub fn access_checks_supported() -> Bool {
  true
}

///|
pub fn symbolic_link_creation_supported() -> Bool {
  symbolic_links_supported()
}

///|
/// Compatibility alias for callers that only need the original aggregate
/// metadata gate.
pub fn metadata_reads_supported() -> Bool {
  file_kind_reads_supported() &&
  regular_file_size_reads_supported() &&
  modification_time_reads_supported()
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
  !is_windows()
}

///|
/// Linux and Darwin use POSIX EXDEV (18). Windows errors remain unclassified
/// until the runtime's rename error domain has a verified public contract.
pub fn is_cross_device_error(error : @os_error.OSError) -> Bool {
  match (@async.platform, error) {
    (Linux | MacOS, @os_error.OSError(18, ..)) => true
    _ => false
  }
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
/// Return whether standard input is proven to be a terminal.
/// Currently false until a public isatty API is available.
pub async fn stdin_is_terminal() -> Bool {
  is_terminal(Stdin)
}

///|
/// Return whether standard output is proven to be a terminal.
pub async fn stdout_is_terminal() -> Bool {
  is_terminal(Stdout)
}

///|
/// Return whether standard error is proven to be a terminal.
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
/// async 0.22.1 has no public isatty operation. A character device (for
/// example /dev/null) does not prove terminal ownership. Explicit interactive
/// modes remain available without pretending this capability is present.
// Retain the asynchronous public signature for existing callers.
#warnings("-unused_async")
pub async fn is_terminal(_stream : StandardStream) -> Bool {
  false
}
