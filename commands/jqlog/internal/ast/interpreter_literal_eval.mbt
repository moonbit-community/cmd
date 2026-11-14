///|
// Adapted from MoonJQ 0.2.0 for local ownership and current syntax.
// See ../../THIRD_PARTY_NOTICES.md for source and license information.

///|
/// Evaluate a literal to JSON
fn eval_literal(lit : Literal) -> Json {
  lit.to_runtime_json()
}
