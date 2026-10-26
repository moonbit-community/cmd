///|
/// An error produced by ripgrep's core. The message is fully rendered,
/// including any context chain (like anyhow's `{:#}` formatting).
pub suberror RgError {
  RgError(String)
} derive(Debug)

///|
pub fn RgError::message(self : RgError) -> String {
  let RgError(msg) = self
  msg
}

///|
pub impl Show for RgError with fn output(self, logger) {
  logger.write_string(self.message())
}

///|
/// Wraps any error raised by `f` with the given context, rendering it as
/// `"{context}: {error}"`.
fn[T] with_context(ctx : String, f : () -> T raise RgError) -> T raise RgError {
  f() catch {
    RgError(msg) => raise RgError("\{ctx}: \{msg}")
  }
}
