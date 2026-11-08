///|
#derive(Eq, Debug)
pub(all) enum StandardStream {
  Stdin
  Stdout
  Stderr
}

///|
/// Terminal-sensitive output is command policy, not a side effect of reading
/// stdin. `IfTerminal` is suitable only when the pinned upstream command uses
/// dynamic terminal feedback for that stream.
#derive(Eq, Debug)
pub(all) enum TerminalPolicy {
  Silent
  IfTerminal
}

///|
pub fn is_windows() -> Bool {
  @async.platform is Windows
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
pub fn normalize_input_separators(path : String) -> String {
  if !is_windows() {
    return path
  }
  path.replace_all(old="/", new="\\")
}

///|
fn terminal_policy_allows(
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
fn is_terminal(_stream : StandardStream) -> Bool {
  false
}

///|
pub extend StandardStream with Eq::{not_equal, equal}

///|
pub extend StandardStream with @debug.Debug::{to_repr}

///|
pub extend TerminalPolicy with Eq::{not_equal, equal}

///|
pub extend TerminalPolicy with @debug.Debug::{to_repr}
