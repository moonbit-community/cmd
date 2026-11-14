///|
// Adapted from MoonJQ 0.2.0 for local ownership and current syntax.
// See ../../THIRD_PARTY_NOTICES.md for source and license information.

///|
// Adapted from moonjq 0.2.0: helpers are private to the local evaluator.

///|
/// Return the jq type name for a JSON value.
///
/// The result matches jq's `type` builtin and the names used in interpreter
/// diagnostics. Both JSON boolean values are reported as `"boolean"`; all other
/// constructors map directly to their JSON type names.
fn json_type_name(json : Json) -> String {
  match json {
    Null => "null"
    True | False => "boolean"
    Number(_) => "number"
    String(_) => "string"
    Array(_) => "array"
    Object(_) => "object"
  }
}
