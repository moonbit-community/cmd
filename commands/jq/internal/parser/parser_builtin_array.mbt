///|
// Adapted from MoonJQ 0.2.0 for local ownership and current syntax.
// See ../../THIRD_PARTY_NOTICES.md for source and license information.

///|
/// Parse array built-ins
fn Parser::parse_builtin_array(
  self : Parser,
  name : String,
) -> @ast.Expr? raise ParseError {
  match name {
    "map" => {
      self.expect(TLeftParen)
      let expr = self.parse_pipe()
      self.expect(TRightParen)
      Some(Map(expr))
    }
    "select" => {
      self.expect(TLeftParen)
      let expr = self.parse_pipe()
      self.expect(TRightParen)
      Some(Select(expr))
    }
    "sort" => Some(Sort)
    "reverse" => Some(Reverse)
    "flatten" =>
      if self.consume(TLeftParen) {
        let depth = if self.current() is Some(TNumber(n)) {
          self.advance()
          Some(n.to_int())
        } else {
          None
        }
        self.expect(TRightParen)
        Some(Flatten(depth))
      } else {
        Some(Flatten(None))
      }
    "unique" => Some(Unique)
    "unique_by" => {
      self.expect(TLeftParen)
      let expr = self.parse_pipe()
      self.expect(TRightParen)
      Some(UniqueBy(expr))
    }
    "combinations" => Some(Combinations)
    "transpose" => Some(Transpose)
    "indices" => {
      self.expect(TLeftParen)
      let expr = self.parse_pipe()
      self.expect(TRightParen)
      Some(IndicesOf(expr))
    }
    "index" => {
      self.expect(TLeftParen)
      let expr = self.parse_pipe()
      self.expect(TRightParen)
      Some(IndexOf(expr))
    }
    "sort_by" => {
      self.expect(TLeftParen)
      let expr = self.parse_pipe()
      self.expect(TRightParen)
      Some(SortBy(expr))
    }
    "group_by" => {
      self.expect(TLeftParen)
      let expr = self.parse_pipe()
      self.expect(TRightParen)
      Some(GroupBy(expr))
    }
    "nth" => {
      self.expect(TLeftParen)
      guard self.current() is Some(TNumber(n)) else {
        raise InvalidSyntax("nth expects number argument")
      }
      self.advance()
      self.expect(TRightParen)
      Some(Nth(n.to_int()))
    }
    "rindex" => {
      self.expect(TLeftParen)
      let expr = self.parse_pipe()
      self.expect(TRightParen)
      Some(RIndex(expr))
    }
    _ => None
  }
}
