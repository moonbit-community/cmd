///|
// Adapted from MoonJQ 0.2.0 for local ownership and current syntax.
// See ../../THIRD_PARTY_NOTICES.md for source and license information.

///|
/// Parse built-in functions
fn Parser::parse_builtin(
  self : Parser,
  name : String,
) -> @ast.Expr raise ParseError {
  if !self.positions.is_empty() {
    let start = self.pos
    let args = self.parse_arguments()
    let end = self.pos
    if self.functions.contains("\{name}/\{args.length()}") {
      return FunctionCall(name, args)
    }
    self.pos = start
    let builtin = self.parse_builtin_by_name(name) catch { _ => None }
    let consumed = self.pos == end
    self.pos = end
    return match builtin {
      Some(body) if consumed => BuiltinCall(name, args, body)
      _ => FunctionCall(name, args)
    }
  }
  if self.functions.iter().any(key => key.has_prefix(name + "/")) {
    let saved = self.pos
    let args = self.parse_arguments()
    if self.functions.contains("\{name}/\{args.length()}") {
      return FunctionCall(name, args)
    }
    self.pos = saved
  }
  match self.parse_builtin_by_name(name) {
    Some(expr) => expr
    None =>
      if self.current() == Some(TLParen) {
        self.advance()
        let args : Array[@ast.Expr] = []
        // Check if there's an expression (not just closing paren)
        if self.current() != Some(TRParen) {
          args.push(self.parse_pipe())
          while self.consume(TSemicolon) {
            args.push(self.parse_pipe())
          }
        }
        self.expect(TRParen)
        FunctionCall(name, args)
      } else {
        FunctionCall(name, [])
      }
  }
}

///|
fn Parser::parse_arguments(self : Parser) -> Array[@ast.Expr] raise ParseError {
  let args : Array[@ast.Expr] = []
  if self.consume(TLParen) {
    if self.current() != Some(TRParen) {
      args.push(self.parse_pipe())
      while self.consume(TSemicolon) {
        args.push(self.parse_pipe())
      }
    }
    self.expect(TRParen)
  }
  args
}

///|
/// Parse built-ins by category - try each category in order
fn Parser::parse_builtin_by_name(
  self : Parser,
  name : String,
) -> @ast.Expr? raise ParseError {
  if self.parse_builtin_core(name) is Some(expr) {
    return Some(expr)
  }
  if self.parse_builtin_numeric(name) is Some(expr) {
    return Some(expr)
  }
  if self.parse_builtin_array(name) is Some(expr) {
    return Some(expr)
  }
  if self.parse_builtin_object(name) is Some(expr) {
    return Some(expr)
  }
  if self.parse_builtin_string(name) is Some(expr) {
    return Some(expr)
  }
  if self.parse_builtin_path(name) is Some(expr) {
    return Some(expr)
  }
  self.parse_builtin_flow(name)
}
