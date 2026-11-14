///|
// Adapted from MoonJQ 0.2.0 for local ownership and current syntax.
// See ../../THIRD_PARTY_NOTICES.md for source and license information.

///|
/// Evaluate left trim
fn eval_ltrim_str(
  prefix : String,
  input : Json,
) -> Iter[Json] raise InterpreterError {
  guard input is String(s) else {
    raise TypeMismatch("string", json_type_name(input))
  }
  match s.strip_prefix(prefix) {
    Some(rest) => Iter::singleton(Json::string(rest.to_owned()))
    None => Iter::singleton(input)
  }
}

///|
/// Evaluate right trim
fn eval_rtrim_str(
  suffix : String,
  input : Json,
) -> Iter[Json] raise InterpreterError {
  guard input is String(s) else {
    raise TypeMismatch("string", json_type_name(input))
  }
  match s.strip_suffix(suffix) {
    Some(rest) => Iter::singleton(Json::string(rest.to_owned()))
    None => Iter::singleton(input)
  }
}

///|
/// Evaluate ASCII upcase
fn eval_ascii_upcase(input : Json) -> Iter[Json] raise InterpreterError {
  guard input is String(s) else {
    raise TypeMismatch("string", json_type_name(input))
  }
  let result = StringBuilder()
  for ch in s {
    if ch is ('a'..<='z') {
      result.write_char(Int32::unsafe_to_char(ch.to_int() - 32))
    } else {
      result.write_char(ch)
    }
  }
  Iter::singleton(Json::string(result.to_string()))
}

///|
/// Evaluate ASCII downcase
fn eval_ascii_downcase(input : Json) -> Iter[Json] raise InterpreterError {
  guard input is String(s) else {
    raise TypeMismatch("string", json_type_name(input))
  }
  let result = StringBuilder()
  for ch in s {
    if ch is ('A'..<='Z') {
      result.write_char(Int32::unsafe_to_char(ch.to_int() + 32))
    } else {
      result.write_char(ch)
    }
  }
  Iter::singleton(Json::string(result.to_string()))
}
