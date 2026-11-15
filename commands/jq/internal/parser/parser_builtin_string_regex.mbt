///|
// Adapted from MoonJQ 0.2.0 for local ownership and current syntax.
// See ../../THIRD_PARTY_NOTICES.md for source and license information.

///|
/// Parse regex-like string built-ins
fn Parser::parse_builtin_string_regex(
  self : Parser,
  name : String,
) -> @ast.Expr? raise ParseError {
  match name {
    "test" => {
      self.expect(TLeftParen)
      guard self.current() is Some(TString(s)) else {
        raise InvalidSyntax("test expects string argument")
      }
      self.advance()
      self.expect(TRightParen)
      Some(Test(s))
    }
    "match" => {
      self.expect(TLeftParen)
      guard self.current() is Some(TString(s)) else {
        raise InvalidSyntax("match expects string argument")
      }
      self.advance()
      self.expect(TRightParen)
      Some(Match(s))
    }
    "capture" => {
      self.expect(TLeftParen)
      guard self.current() is Some(TString(s)) else {
        raise InvalidSyntax("capture expects string argument")
      }
      self.advance()
      self.expect(TRightParen)
      Some(Capture(s))
    }
    "splits" => {
      self.expect(TLeftParen)
      guard self.current() is Some(TString(s)) else {
        raise InvalidSyntax("splits expects string argument")
      }
      self.advance()
      self.expect(TRightParen)
      Some(Splits(s))
    }
    "sub" => {
      self.expect(TLeftParen)
      guard self.current() is Some(TString(pattern)) else {
        raise InvalidSyntax("sub expects string pattern")
      }
      self.advance()
      self.expect(TSemicolon)
      guard self.current() is Some(TString(replacement)) else {
        raise InvalidSyntax("sub expects string replacement")
      }
      self.advance()
      self.expect(TRightParen)
      Some(Sub(pattern, replacement))
    }
    "gsub" => {
      self.expect(TLeftParen)
      guard self.current() is Some(TString(pattern)) else {
        raise InvalidSyntax("gsub expects string pattern")
      }
      self.advance()
      self.expect(TSemicolon)
      guard self.current() is Some(TString(replacement)) else {
        raise InvalidSyntax("gsub expects string replacement")
      }
      self.advance()
      self.expect(TRightParen)
      Some(GSub(pattern, replacement))
    }
    _ => None
  }
}
