///|
// Adapted from MoonJQ 0.2.0 for local ownership and current syntax.
// See ../../THIRD_PARTY_NOTICES.md for source and license information.

///|
/// Parser state
priv struct Parser {
  tokens : Array[Token]
  mut pos : Int32
  mut functions : Set[String]
  mut positions : Array[Int32]
  mut interpolations : Map[Int32, Array[Int32]]
}

///|
/// Create a new parser from tokens
fn Parser::new(tokens : Array[Token]) -> Parser {
  {
    tokens,
    pos: 0,
    functions: Set([]),
    positions: [],
    interpolations: Map([]),
  }
}

///|
/// Get current token
fn Parser::current(self : Parser) -> Token? {
  if self.pos < self.tokens.length() {
    Some(self.tokens[self.pos])
  } else {
    None
  }
}

///|
/// Advance to next token
fn Parser::advance(self : Parser) -> Unit {
  if self.pos < self.tokens.length() {
    self.pos += 1
  }
}

///|
/// Check if current token matches type
fn Parser::check(self : Parser, expected : Token) -> Bool {
  match self.current() {
    Some(t) => t == expected
    None => false
  }
}

///|
/// Consume current token if it matches
fn Parser::consume(self : Parser, expected : Token) -> Bool {
  if self.check(expected) {
    self.advance()
    true
  } else {
    false
  }
}

///|
/// Expect and consume a token, raise error if not found
fn Parser::expect(self : Parser, expected : Token) -> Unit raise ParseError {
  match self.current() {
    Some(t) if t == expected => self.advance()
    Some(t) => raise UnexpectedToken(t.to_string(), expected.to_string())
    None => raise UnexpectedEnd(expected.to_string())
  }
}
