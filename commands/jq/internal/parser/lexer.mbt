///|
// Adapted from MoonJQ 0.2.0 for local ownership and current syntax.
// See ../../THIRD_PARTY_NOTICES.md for source and license information.

///|
/// Main lexing function
pub fn lex(input : String) -> Array[Token] raise LexError {
  lex_positions(input).0
}

///|
fn lex_positions(
  input : String,
) -> (Array[Token], Array[Int32], Map[Int32, Array[Int32]]) raise LexError {
  let lexer = Lexer::new(input)
  while true {
    lexer.skip_whitespace()
    lexer.start = lexer.pos
    match lexer.current() {
      None => break
      Some('#') => {
        lexer.skip_comment()
        continue
      }
      Some('"') => {
        lexer.lex_string()
        continue
      }
      Some('$') => {
        lexer.lex_variable()
        continue
      }
      Some('@') => {
        lexer.lex_format()
        continue
      }
      Some(c) if is_digit(c) ||
        (
          c == '-' &&
          lexer.peek().map(is_digit).unwrap_or(false) &&
          lexer.starts_operand()
        ) => {
        lexer.lex_number()
        continue
      }
      Some(c) if is_alpha(c) => {
        lexer.lex_identifier()
        continue
      }
      Some(c) => {
        lexer.lex_symbol(c)
        continue
      }
    }
  }
  lexer.add_token(TEof)
  (lexer.tokens, lexer.positions, lexer.interpolations)
}

///|
fn Lexer::starts_operand(self : Lexer) -> Bool {
  match self.tokens.last() {
    Some(
      TNumber(_)
      | TString(_)
      | TStringInterpolation(_)
      | TTrue
      | TFalse
      | TNull
      | TIdentifier(_)
      | TVariable(_)
      | TFormat(_)
      | TDot
      | TDotDot
      | TRParen
      | TRBracket
      | TRBrace
      | TQuestion
      | TNot
    ) => false
    _ => true
  }
}
