///|
// Adapted from MoonJQ 0.2.0 for local ownership and current syntax.
// See ../../THIRD_PARTY_NOTICES.md for source and license information.

///|
/// Parse flow range and stream built-ins
fn Parser::parse_builtin_flow_range(
  self : Parser,
  name : String,
) -> @ast.Expr? raise ParseError {
  match name {
    "range" => {
      self.expect(TLeftParen)
      let first_expr = self.parse_pipe()
      if self.consume(TSemicolon) {
        let second_expr = self.parse_pipe()
        if self.consume(TSemicolon) {
          let third_expr = self.parse_pipe()
          self.expect(TRightParen)
          Some(RangeWithStep(first_expr, second_expr, third_expr))
        } else {
          self.expect(TRightParen)
          Some(RangeFromTo(first_expr, second_expr))
        }
      } else {
        self.expect(TRightParen)
        guard first_expr is Literal(Number(n)) else {
          raise InvalidSyntax("range(n) expects literal number")
        }
        Some(Range(n.to_int()))
      }
    }
    "first" =>
      if self.consume(TLeftParen) {
        let expr = self.parse_pipe()
        self.expect(TRightParen)
        Some(FirstGen(expr))
      } else {
        Some(First)
      }
    "last" =>
      if self.consume(TLeftParen) {
        let expr = self.parse_pipe()
        self.expect(TRightParen)
        Some(LastGen(expr))
      } else {
        Some(Last)
      }
    "repeat" => {
      self.expect(TLeftParen)
      let expr = self.parse_pipe()
      self.expect(TRightParen)
      Some(Repeat(expr))
    }
    _ => None
  }
}
