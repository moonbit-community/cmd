///|
// Adapted from MoonJQ 0.2.0 for local ownership and current syntax.
// See ../../THIRD_PARTY_NOTICES.md for source and license information.

///|
/// Serialize a JSON value as compact JSON text (jq's `tojson`).
fn json_to_text(value : Json) -> String {
  value.stringify()
}

///|
/// jq's `tostring`: strings are returned unchanged, everything else is
/// serialized as JSON text.
fn json_to_display_string(value : Json) -> String {
  match value {
    String(s) => s
    _ => json_to_text(value)
  }
}

///|
/// Evaluate ToJsonString
fn eval_to_json_string(input : Json) -> Iter[Json] {
  Iter::singleton(Json::string(json_to_text(input)))
}

///|
/// Evaluate FromJsonString
fn eval_from_json_string(input : Json) -> Iter[Json] raise InterpreterError {
  guard input is String(s) else {
    raise TypeMismatch("string", json_type_name(input))
  }
  let parsed = @json.parse(s) catch {
    e => raise InvalidOperation("JSON parse error: \{e}")
  }
  Iter::singleton(parsed)
}
