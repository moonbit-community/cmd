///|
// Adapted from MoonJQ 0.2.0 for local ownership and current syntax.
// See ../../THIRD_PARTY_NOTICES.md for source and license information.

///|
/// Parse core built-ins
fn Parser::parse_builtin_core(_self : Parser, name : String) -> @ast.Expr? {
  match name {
    "length" => Some(Length)
    "keys" => Some(Keys)
    "values" => Some(Values)
    "type" => Some(Type)
    "empty" => Some(Empty)
    "not" => Some(Not)
    _ => None
  }
}
