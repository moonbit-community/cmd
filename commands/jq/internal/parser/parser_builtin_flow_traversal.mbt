///|
// Adapted from MoonJQ 0.2.0 for local ownership and current syntax.
// See ../../THIRD_PARTY_NOTICES.md for source and license information.

///|
/// Parse recursion and traversal built-ins
fn Parser::parse_builtin_flow_traversal(
  self : Parser,
  name : String,
) -> @ast.Expr? raise ParseError {
  match name {
    "recurse" =>
      if self.consume(TLeftParen) {
        let f = self.parse_pipe()
        self.expect(TSemicolon)
        let cond = self.parse_pipe()
        self.expect(TRightParen)
        Some(RecurseWith(f, cond))
      } else {
        Some(Recurse)
      }
    "walk" => {
      self.expect(TLeftParen)
      let expr = self.parse_pipe()
      self.expect(TRightParen)
      Some(Walk(expr))
    }
    _ => None
  }
}
