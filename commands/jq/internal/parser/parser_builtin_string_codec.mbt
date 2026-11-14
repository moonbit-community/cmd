///|
// Adapted from MoonJQ 0.2.0 for local ownership and current syntax.
// See ../../THIRD_PARTY_NOTICES.md for source and license information.

///|
/// Parse string codec built-ins
fn Parser::parse_builtin_string_codec(
  self : Parser,
  name : String,
) -> @ast.Expr? raise ParseError {
  match name {
    "explode" => Some(Explode)
    "implode" => Some(Implode)
    "tojson" => Some(ToJsonString)
    // jq: `def tostring: if type == "string" then . else tojson end;`
    "tostring" =>
      Some(
        IfThenElse(
          Operation(Type, Equal, Literal(String("string"))),
          Identity,
          ToJsonString,
        ),
      )
    "fromjson" => Some(FromJsonString)
    "scan" => {
      self.expect(TLParen)
      guard self.current() is Some(TString(s)) else {
        raise InvalidSyntax("scan expects string argument")
      }
      self.advance()
      self.expect(TRParen)
      Some(Scan(s))
    }
    _ => None
  }
}
