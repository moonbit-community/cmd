///|
// Adapted from MoonJQ 0.2.0 for local ownership and current syntax.
// See ../../THIRD_PARTY_NOTICES.md for source and license information.

///|
/// Lexing bindings and reduce expressions
test "lex: as expression" {
  let tokens = @parser.lex(". as $x | $x + 1")
  debug_inspect(
    tokens,
    content=(
      #|[
      #|  TDot,
      #|  TAs,
      #|  TVariable("x"),
      #|  TPipe,
      #|  TVariable("x"),
      #|  TPlus,
      #|  TNumber(1),
      #|  TEof,
      #|]
    ),
  )
}

///|
test "lex: reduce expression" {
  let tokens = @parser.lex("reduce .[] as $x (0; . + $x)")
  debug_inspect(
    tokens,
    content=(
      #|[
      #|  TReduce,
      #|  TDot,
      #|  TLBracket,
      #|  TRBracket,
      #|  TAs,
      #|  TVariable("x"),
      #|  TLParen,
      #|  TNumber(0),
      #|  TSemicolon,
      #|  TDot,
      #|  TPlus,
      #|  TVariable("x"),
      #|  TRParen,
      #|  TEof,
      #|]
    ),
  )
}
