///|
// Adapted from MoonJQ 0.2.0 for local ownership and current syntax.
// See ../../THIRD_PARTY_NOTICES.md for source and license information.

///|
/// Evaluate length
fn eval_length(input : Json) -> Iter[Json] raise InterpreterError {
  let len = match input {
    Array(arr) => arr.length()
    Object(obj) => obj.length()
    // jq counts Unicode code points, not UTF-16 code units.
    String(s) => s.char_length()
    Null => 0
    // jq's length of a number is its absolute value.
    Number(n, ..) => return Iter::singleton(Json::number(n.abs()))
    _ => raise TypeMismatch("array/object/string", json_type_name(input))
  }
  Iter::singleton(Json::number(len.to_double()))
}

///|
/// Evaluate keys
fn eval_keys(input : Json) -> Iter[Json] raise InterpreterError {
  match input {
    Object(obj) => {
      let keys = obj.keys().map(Json::string).collect()
      Iter::singleton(Json::array(keys))
    }
    Array(arr) => {
      let indices = arr.mapi(fn(i, _) { Json::number(i.to_double()) })
      Iter::singleton(Json::array(indices))
    }
    _ => raise TypeMismatch("object/array", json_type_name(input))
  }
}

///|
/// Evaluate values
fn eval_values(input : Json) -> Iter[Json] raise InterpreterError {
  match input {
    Object(obj) => {
      let values = obj.values().collect()
      Iter::singleton(Json::array(values))
    }
    Array(arr) => Iter::singleton(Json::array(arr))
    _ => raise TypeMismatch("object/array", json_type_name(input))
  }
}

///|
/// Evaluate type
fn eval_type(input : Json) -> Iter[Json] {
  Iter::singleton(Json::string(json_type_name(input)))
}

///|
/// Evaluate empty
fn eval_empty() -> Iter[Json] {
  Iter::empty()
}

///|
/// Evaluate logical not
fn eval_not(input : Json) -> Iter[Json] {
  Iter::singleton(Json::boolean(!is_truthy(input)))
}
