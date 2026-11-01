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
pub fn symbolic_link_creation_supported() -> Bool {
  !is_windows()
}

///|
pub fn permission_reads_supported() -> Bool {
  false
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
pub fn terminal_policy_allows(
  policy : TerminalPolicy,
  proven_terminal : Bool,
) -> Bool {
  policy == IfTerminal && proven_terminal
}

///|
pub fn terminal_output_enabled(
  policy : TerminalPolicy,
  stream : StandardStream,
) -> Bool {
  terminal_policy_allows(policy, is_terminal(stream))
}

///|
/// The current async dependency has no public isatty operation. A character device (for
/// example /dev/null) does not prove terminal ownership. Explicit interactive
/// modes remain available without pretending this capability is present.
pub fn is_terminal(_stream : StandardStream) -> Bool {
  false
}

///|
pub extend Platform with Eq::{not_equal, equal}

///|
pub extend Platform with @debug.Debug::{to_repr}

///|
pub extend StandardStream with Eq::{not_equal, equal}

///|
pub extend StandardStream with @debug.Debug::{to_repr}

///|
pub extend TerminalPolicy with Eq::{not_equal, equal}

///|
pub extend TerminalPolicy with @debug.Debug::{to_repr}
