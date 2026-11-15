///|
// Adapted from MoonJQ 0.2.0 for local ownership and current syntax.
// See ../../THIRD_PARTY_NOTICES.md for source and license information.

///|
/// Parse object built-ins
fn Parser::parse_builtin_object(
  self : Parser,
  name : String,
) -> @ast.Expr? raise ParseError {
  match name {
    "has" => {
      self.expect(TLeftParen)
      match self.current() {
        Some(TString(key)) => {
          self.advance()
          self.expect(TRightParen)
          Some(Has(key))
        }
        Some(TNumber(n)) => {
          self.advance()
          self.expect(TRightParen)
          Some(Has(n.to_string()))
        }
        _ => raise InvalidSyntax("has expects string or number argument")
      }
    }
    "in" => {
      self.expect(TLeftParen)
      let expr = self.parse_pipe()
      self.expect(TRightParen)
      Some(In(expr))
    }
    "to_entries" => Some(ToEntries)
    "from_entries" => Some(FromEntries)
    "with_entries" => {
      self.expect(TLeftParen)
      let expr = self.parse_pipe()
      self.expect(TRightParen)
      Some(WithEntries(expr))
    }
    "map_values" => {
      self.expect(TLeftParen)
      let expr = self.parse_pipe()
      self.expect(TRightParen)
      Some(MapValues(expr))
    }
    _ => None
  }
}
