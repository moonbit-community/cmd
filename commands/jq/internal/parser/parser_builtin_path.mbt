///|
// Adapted from MoonJQ 0.2.0 for local ownership and current syntax.
// See ../../THIRD_PARTY_NOTICES.md for source and license information.

///|
/// Parse path built-ins
fn Parser::parse_builtin_path(
  self : Parser,
  name : String,
) -> @ast.Expr? raise ParseError {
  match name {
    "paths" =>
      if self.consume(TLeftParen) {
        let expr = self.parse_pipe()
        self.expect(TRightParen)
        Some(PathsWithFilter(expr))
      } else {
        Some(Paths)
      }
    "leaf_paths" => Some(LeafPaths)
    "path" => {
      self.expect(TLeftParen)
      let expr = self.parse_pipe()
      self.expect(TRightParen)
      Some(Path(expr))
    }
    "getpath" => {
      self.expect(TLeftParen)
      let expr = self.parse_pipe()
      self.expect(TRightParen)
      Some(GetPath(expr))
    }
    "setpath" => {
      self.expect(TLeftParen)
      let path = self.parse_pipe()
      self.expect(TSemicolon)
      let value = self.parse_pipe()
      self.expect(TRightParen)
      Some(SetPath(path, value))
    }
    "delpaths" => {
      self.expect(TLeftParen)
      let expr = self.parse_pipe()
      self.expect(TRightParen)
      Some(DelPaths(expr))
    }
    _ => None
  }
}
