///|
// Adapted from MoonJQ 0.2.0 for local ownership and current syntax.
// See ../../THIRD_PARTY_NOTICES.md for source and license information.

///|
/// Evaluate Any
fn eval_any(input : Json) -> Iter[Json] raise InterpreterError {
  guard input is Array(arr) else {
    raise TypeMismatch("array", json_type_name(input))
  }
  Iter::singleton(Json::boolean(arr.any(is_truthy)))
}

///|
/// Evaluate All
fn eval_all(input : Json) -> Iter[Json] raise InterpreterError {
  guard input is Array(arr) else {
    raise TypeMismatch("array", json_type_name(input))
  }
  Iter::singleton(Json::boolean(arr.all(is_truthy)))
}
