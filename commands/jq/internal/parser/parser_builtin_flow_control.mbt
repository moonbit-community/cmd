///|
// Adapted from MoonJQ 0.2.0 for local ownership and current syntax.
// See ../../THIRD_PARTY_NOTICES.md for source and license information.

///|
/// Parse flow control built-ins
fn Parser::parse_builtin_flow_control(
  self : Parser,
  name : String,
) -> @ast.Expr? raise ParseError {
  match name {
    "limit" => {
      self.expect(TLeftParen)
      guard self.current() is Some(TNumber(n)) else {
        raise InvalidSyntax("limit expects number argument")
      }
      self.advance()
      self.expect(TSemicolon)
      let expr = self.parse_pipe()
      self.expect(TRightParen)
      Some(Limit(n.to_int(), expr))
    }
    "until" => {
      self.expect(TLeftParen)
      let cond = self.parse_pipe()
      self.expect(TSemicolon)
      let update = self.parse_pipe()
      self.expect(TRightParen)
      Some(Until(cond, update))
    }
    "while" => {
      self.expect(TLeftParen)
      let cond = self.parse_pipe()
      self.expect(TSemicolon)
      let update = self.parse_pipe()
      self.expect(TRightParen)
      Some(While(cond, update))
    }
    _ => None
  }
}
