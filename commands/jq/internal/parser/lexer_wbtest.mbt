///|
// Adapted from MoonJQ 0.2.0 for local ownership and current syntax.
// See ../../THIRD_PARTY_NOTICES.md for source and license information.

///|
test "wb: lexer invalid number slice" {
  let lexer = Lexer::new("1")
  lexer.pos = 2
  try lexer.lex_number() catch {
    _ => ()
  } noraise {
    _ => fail("expected lex_number error")
  }
}

///|
test "wb: lexer invalid number parse" {
  let lexer = Lexer::new("-")
  try lexer.lex_number() catch {
    _ => ()
  } noraise {
    _ => fail("expected lex_number error")
  }
}
