///|
// Adapted from MoonJQ 0.2.0 for local ownership and current syntax.
// See ../../THIRD_PARTY_NOTICES.md for source and license information.

///|
// Adapted from moonjq 0.2.0: helpers are private to the local evaluator.

///|
/// Return whether a JSON value is truthy according to jq semantics.
///
/// jq treats only `false` and `null` as falsy. Numbers, strings, arrays, and
/// objects are truthy even when they are zero or empty, so this helper should be
/// used for conditionals and logical operators instead of language-level
/// truthiness rules.
fn is_truthy(value : Json) -> Bool {
  match value {
    False | Null => false
    _ => true
  }
}
