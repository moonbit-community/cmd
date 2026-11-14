///|
// Adapted from MoonJQ 0.2.0 for local ownership and current syntax.
// See ../../THIRD_PARTY_NOTICES.md for source and license information.

///|
/// Interpreter error types
#derive(Eq, Debug)
pub(all) suberror InterpreterError {
  TypeMismatch(String, String) // (expected, got)
  KeyNotFound(String)
  IndexOutOfBounds(Int32)
  InvalidOperation(String)
  DivisionByZero
  TypeError(String)
  EvalError(String)
  InputError(String)
}

///|
/// Preserve method-style access to derived equality operations.
pub extend InterpreterError with Eq::{not_equal, equal}

///|
/// Preserve method-style access to derived debug representation.
pub extend InterpreterError with @debug.Debug::{to_repr}

///|
pub impl Show for InterpreterError with fn output(self, logger) {
  logger.write_string(@debug.render(self.to_repr(), max_depth=2147483647))
}

///|
/// Preserve method-style access to display operations.
pub extend InterpreterError with Show::{to_string, output}

///|
pub fn InterpreterError::message(self : InterpreterError) -> String {
  match self {
    InputError(message)
    | EvalError(message)
    | TypeError(message)
    | InvalidOperation(message) => message
    _ => self.to_string()
  }
}
