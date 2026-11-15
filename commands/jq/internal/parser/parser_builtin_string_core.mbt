///|
// Adapted from MoonJQ 0.2.0 for local ownership and current syntax.
// See ../../THIRD_PARTY_NOTICES.md for source and license information.

///|
/// Parse core string built-ins
fn Parser::parse_builtin_string_core(
  self : Parser,
  name : String,
) -> @ast.Expr? raise ParseError {
  match name {
    "split" => {
      self.expect(TLeftParen)
      guard self.current() is Some(TString(sep)) else {
        raise InvalidSyntax("split expects string argument")
      }
      self.advance()
      self.expect(TRightParen)
      Some(Split(sep))
    }
    "join" => {
      self.expect(TLeftParen)
      guard self.current() is Some(TString(sep)) else {
        raise InvalidSyntax("join expects string argument")
      }
      self.advance()
      self.expect(TRightParen)
      Some(Join(sep))
    }
    "startswith" => {
      self.expect(TLeftParen)
      guard self.current() is Some(TString(prefix)) else {
        raise InvalidSyntax("startswith expects string argument")
      }
      self.advance()
      self.expect(TRightParen)
      Some(StartsWith(prefix))
    }
    "endswith" => {
      self.expect(TLeftParen)
      guard self.current() is Some(TString(suffix)) else {
        raise InvalidSyntax("endswith expects string argument")
      }
      self.advance()
      self.expect(TRightParen)
      Some(EndsWith(suffix))
    }
    "contains" => {
      self.expect(TLeftParen)
      let expr = self.parse_pipe()
      self.expect(TRightParen)
      Some(Contains(expr))
    }
    "inside" => {
      self.expect(TLeftParen)
      let expr = self.parse_pipe()
      self.expect(TRightParen)
      Some(Inside(expr))
    }
    _ => None
  }
}
