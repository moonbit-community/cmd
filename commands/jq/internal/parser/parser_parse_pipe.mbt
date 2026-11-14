///|
// Adapted from MoonJQ 0.2.0 for local ownership and current syntax.
// See ../../THIRD_PARTY_NOTICES.md for source and license information.

///|
/// Parse pipe expression (lowest precedence)
fn Parser::parse_pipe(self : Parser) -> @ast.Expr raise ParseError {
  if self.current() == Some(TDef) {
    let outer = self.functions
    let definition = self.parse_function_def()
    let body = self.parse_pipe()
    self.functions = outer
    return Pipe(definition, body)
  }
  let mut expr = self.parse_binding()
  while self.consume(TPipe) {
    let right = if self.current() == Some(TDef) {
      self.parse_pipe()
    } else {
      self.parse_binding()
    }
    expr = Pipe(expr, right)
  }
  expr
}

///|
fn Parser::parse_binding(self : Parser) -> @ast.Expr raise ParseError {
  let expr = self.parse_comma()
  if self.consume(TAs) {
    guard self.current() is Some(TVariable(var_name)) else {
      raise InvalidSyntax("Expected variable after 'as'")
    }
    self.advance()
    self.expect(TPipe)
    let body = self.parse_pipe()
    return As(expr, var_name, body)
  }
  expr
}

///|
/// Parse comma expression
fn Parser::parse_comma(self : Parser) -> @ast.Expr raise ParseError {
  let mut current = self.parse_assignment()
  while self.consume(TComma) {
    let right = self.parse_assignment()
    current = Comma(current, right)
  }
  current
}
