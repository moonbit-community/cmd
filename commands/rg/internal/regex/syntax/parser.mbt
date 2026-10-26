///|
/// A combined parse + translate configuration.
pub(all) struct ParseConfig {
  case_insensitive : Bool
  multi_line : Bool
  dot_matches_new_line : Bool
  crlf : Bool
  swap_greed : Bool
  ignore_whitespace : Bool
  unicode : Bool
  utf8 : Bool
  octal : Bool
  nest_limit : Int32
  line_terminator : Int32
}

///|
pub fn ParseConfig::default() -> ParseConfig {
  {
    case_insensitive: false,
    multi_line: false,
    dot_matches_new_line: false,
    crlf: false,
    swap_greed: false,
    ignore_whitespace: false,
    unicode: true,
    utf8: true,
    octal: false,
    nest_limit: 250,
    line_terminator: '\n',
  }
}

///|
/// Parses and translates a pattern into an HIR.
pub fn parse(
  pattern : String,
  config~ : ParseConfig = ParseConfig::default(),
) -> Hir raise SyntaxError {
  let ast = parse_ast(pattern, config={
    ignore_whitespace: config.ignore_whitespace,
    nest_limit: config.nest_limit,
    octal: config.octal,
    empty_min_range: false,
  })
  translate(pattern, ast, config={
    utf8: config.utf8,
    line_terminator: config.line_terminator,
    case_insensitive: config.case_insensitive,
    multi_line: config.multi_line,
    dot_matches_new_line: config.dot_matches_new_line,
    crlf: config.crlf,
    swap_greed: config.swap_greed,
    unicode: config.unicode,
  })
}
