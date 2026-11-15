///|
// Adapted from MoonJQ 0.2.0 for local ownership and current syntax.
// See ../../THIRD_PARTY_NOTICES.md for source and license information.

///|
/// Parse reduce and foreach built-ins
fn Parser::parse_builtin_flow_reduce(
  self : Parser,
  name : String,
) -> @ast.Expr? raise ParseError {
  match name {
    "reduce" => {
      self.expect(TLeftParen)
      let gen_expr = self.parse_postfix()
      self.expect(TAs)
      guard self.current() is Some(TVariable(var_name)) else {
        raise InvalidSyntax("reduce expects variable after as")
      }
      self.advance()
      self.expect(TLeftParen)
      let init_expr = self.parse_pipe()
      self.expect(TSemicolon)
      let update_expr = self.parse_pipe()
      self.expect(TRightParen)
      self.expect(TRightParen)
      Some(Reduce(gen_expr, var_name, init_expr, update_expr))
    }
    "foreach" => {
      self.expect(TLeftParen)
      let gen_expr = self.parse_postfix()
      self.expect(TAs)
      guard self.current() is Some(TVariable(var_name)) else {
        raise InvalidSyntax("foreach expects variable after as")
      }
      self.advance()
      self.expect(TLeftParen)
      let init_expr = self.parse_pipe()
      self.expect(TSemicolon)
      let update_expr = self.parse_pipe()
      let extract_expr = if self.consume(TSemicolon) {
        Some(self.parse_pipe())
      } else {
        None
      }
      self.expect(TRightParen)
      self.expect(TRightParen)
      Some(Foreach(gen_expr, var_name, init_expr, update_expr, extract_expr))
    }
    _ => None
  }
}
