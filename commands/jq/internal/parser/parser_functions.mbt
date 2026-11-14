///|
// Adapted from MoonJQ 0.2.0 for local ownership and current syntax.
// See ../../THIRD_PARTY_NOTICES.md for source and license information.

///|
/// Parse function definition: def name(params): body;
fn Parser::parse_function_def(self : Parser) -> @ast.Expr raise ParseError {
  self.expect(TDef)
  guard self.current() is Some(TIdentifier(name)) else {
    raise UnexpectedToken("identifier", "function name")
  }
  self.advance()
  let params : Array[String] = []
  // Optional parameters
  if self.consume(TLParen) {
    if self.current() != Some(TRParen) {
      while true {
        let param = match self.current() {
          Some(TIdentifier(name)) => name
          Some(TVariable(name)) => "$" + name
          _ => raise InvalidSyntax("Expected a filter or value parameter")
        }
        self.advance()
        params.push(param)
        if !self.consume(TSemicolon) {
          break
        }
      }
    }
    self.expect(TRParen)
  }
  self.expect(TColon)
  let visible = self.functions.copy()
  visible.add("\{name}/\{params.length()}")
  self.functions = visible.copy()
  for param in params {
    if !param.has_prefix("$") {
      self.functions.add(param + "/0")
    }
  }
  let body = self.parse_pipe()
  self.functions = visible
  self.expect(TSemicolon)
  FunctionDef(name, params, body)
}
