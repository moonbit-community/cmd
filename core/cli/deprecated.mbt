///|
/// Kept as a source-compatible no-op for clients of cli/core 0.1.x.
/// Upstream utilities silently wait for implicit terminal input unless the
/// utility itself defines a prompt.
#deprecated("Upstream-compatible commands must not emit a generic stdin prompt")
pub fn warn_stdin_wait(_command : String) -> Unit {
  ()
}
