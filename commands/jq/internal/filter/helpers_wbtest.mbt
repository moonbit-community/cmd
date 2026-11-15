///|
fn parse_filter(source : String) -> @ast.Expr raise {
  lower(@parser.parse(source))
}
