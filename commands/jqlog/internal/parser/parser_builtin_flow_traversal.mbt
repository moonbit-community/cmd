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
      if self.consume(TLParen) {
        let f = self.parse_pipe()
        self.expect(TSemicolon)
        let cond = self.parse_pipe()
        self.expect(TRParen)
        Some(RecurseWith(f, cond))
      } else {
        Some(Recurse)
      }
    "walk" => {
      self.expect(TLParen)
      let expr = self.parse_pipe()
      self.expect(TRParen)
      Some(Walk(expr))
    }
    _ => None
  }
}
