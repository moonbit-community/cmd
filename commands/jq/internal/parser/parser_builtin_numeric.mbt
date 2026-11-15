///|
// Adapted from MoonJQ 0.2.0 for local ownership and current syntax.
// See ../../THIRD_PARTY_NOTICES.md for source and license information.

///|
/// Parse numeric built-ins
fn Parser::parse_builtin_numeric(
  self : Parser,
  name : String,
) -> @ast.Expr? raise ParseError {
  match name {
    "add" => Some(Add)
    "floor" => Some(Floor)
    "sqrt" => Some(Sqrt)
    "min" => Some(Min)
    "min_by" => {
      self.expect(TLeftParen)
      let expr = self.parse_pipe()
      self.expect(TRightParen)
      Some(MinBy(expr))
    }
    "max" => Some(Max)
    "max_by" => {
      self.expect(TLeftParen)
      let expr = self.parse_pipe()
      self.expect(TRightParen)
      Some(MaxBy(expr))
    }
    "round" => Some(Round)
    "ceil" => Some(Ceil)
    "abs" => Some(Abs)
    "pow" => {
      self.expect(TLeftParen)
      let base = self.parse_pipe()
      if self.consume(TSemicolon) {
        let exponent = self.parse_pipe()
        self.expect(TRightParen)
        Some(Pipe(base, Pow(exponent)))
      } else {
        self.expect(TRightParen)
        Some(Pow(base))
      }
    }
    "log" => Some(Log)
    "exp" => Some(Exp)
    "sin" => Some(Sin)
    "cos" => Some(Cos)
    "tan" => Some(Tan)
    "asin" => Some(Asin)
    "acos" => Some(Acos)
    "atan" => Some(Atan)
    _ => None
  }
}
