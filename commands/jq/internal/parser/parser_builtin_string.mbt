///|
// Adapted from MoonJQ 0.2.0 for local ownership and current syntax.
// See ../../THIRD_PARTY_NOTICES.md for source and license information.

///|
/// Parse string built-ins
fn Parser::parse_builtin_string(
  self : Parser,
  name : String,
) -> @ast.Expr? raise ParseError {
  if self.parse_builtin_string_core(name) is Some(expr) {
    return Some(expr)
  }
  if self.parse_builtin_string_trim(name) is Some(expr) {
    return Some(expr)
  }
  if self.parse_builtin_string_codec(name) is Some(expr) {
    return Some(expr)
  }
  self.parse_builtin_string_regex(name)
}
