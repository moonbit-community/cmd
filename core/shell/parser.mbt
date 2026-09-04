///|
priv struct Parser {
  tokens : Array[Token]
  mut pos : Int
}

///|
fn Parser::peek(self : Parser) -> Token? {
  self.tokens.get(self.pos)
}

///|
fn word_literal(word : Word) -> String? {
  match word.parts {
    [Text(value)] => Some(value)
    _ => None
  }
}

///|
fn Parser::peek_word(self : Parser) -> String? {
  match self.peek() {
    Some(WordToken(word)) => word_literal(word)
    _ => None
  }
}

///|
fn Parser::skip_sequences(self : Parser) -> Unit {
  while self.peek() == Some(Sequence) {
    self.pos += 1
  }
}

///|
fn Parser::take_word(self : Parser) -> Word raise ShellError {
  guard self.peek() is Some(WordToken(word)) else {
    raise ShellError("expected a word")
  }
  self.pos += 1
  word
}

///|
fn Parser::take_reserved(
  self : Parser,
  value : String,
) -> Unit raise ShellError {
  if self.peek_word() != Some(value) {
    raise ShellError("expected '\\{value}'")
  }
  self.pos += 1
}

///|
fn Parser::parse_command(self : Parser) -> Command raise ShellError {
  let words : Array[Word] = []
  let mut stdin : Word? = None
  let mut stdin_data : String? = None
  let mut stdout : Redirect? = None
  let mut stderr : Redirect? = None
  let mut keep = true
  while keep {
    match self.peek() {
      Some(WordToken(word)) => {
        words.push(word)
        self.pos += 1
      }
      Some(RedirectIn) => {
        self.pos += 1
        stdin = Some(self.take_word())
      }
      Some(RedirectHereDoc) => {
        self.pos += 1
        match self.take_word().parts {
          [Text(value)] => stdin_data = Some(value)
          _ => raise ShellError("invalid here-document body")
        }
      }
      Some(RedirectOut) => {
        self.pos += 1
        stdout = Some({ target: self.take_word(), append: false, })
      }
      Some(RedirectAppend) => {
        self.pos += 1
        stdout = Some({ target: self.take_word(), append: true, })
      }
      Some(RedirectError) => {
        self.pos += 1
        stderr = Some({ target: self.take_word(), append: false, })
      }
      Some(RedirectErrorAppend) => {
        self.pos += 1
        stderr = Some({ target: self.take_word(), append: true, })
      }
      _ => keep = false
    }
  }
  if words.is_empty() {
    raise ShellError("expected a command")
  }
  { words, stdin, stdin_data, stdout, stderr, }
}

///|
fn Parser::parse_pipeline(self : Parser) -> Pipeline raise ShellError {
  let commands : Array[Command] = [self.parse_command()]
  while self.peek() == Some(Pipe) {
    self.pos += 1
    commands.push(self.parse_command())
  }
  { commands, }
}

///|
fn Parser::parse_until(
  self : Parser,
  stop : Array[String],
) -> Array[Job] raise ShellError {
  let jobs : Array[Job] = []
  let mut connector = Always
  self.skip_sequences()
  while self.pos < self.tokens.length() {
    match self.peek() {
      Some(RParen) | Some(RBrace) | Some(CaseEnd) => break
      _ => ()
    }
    match self.peek_word() {
      Some(word) if stop.contains(word) => break
      _ => ()
    }
    jobs.push({ connector, statement: self.parse_statement(), })
    match self.peek() {
      Some(AndIf) => {
        connector = OnSuccess
        self.pos += 1
      }
      Some(OrIf) => {
        connector = OnFailure
        self.pos += 1
      }
      Some(Sequence) => {
        connector = Always
        self.skip_sequences()
      }
      Some(RParen) | Some(RBrace) | Some(CaseEnd) | None => break
      _ => raise ShellError("unexpected token after command")
    }
  }
  jobs
}

///|
fn Parser::parse_if(self : Parser) -> Statement raise ShellError {
  self.take_reserved("if")
  let condition = self.parse_until(["then"])
  self.take_reserved("then")
  let then_body = self.parse_until(["else", "fi"])
  let else_body = if self.peek_word() == Some("else") {
    self.pos += 1
    self.parse_until(["fi"])
  } else {
    []
  }
  self.take_reserved("fi")
  IfStatement(condition, then_body, else_body)
}

///|
fn Parser::parse_case(self : Parser) -> Statement raise ShellError {
  self.take_reserved("case")
  let subject = self.take_word()
  self.take_reserved("in")
  self.skip_sequences()
  let arms : Array[CaseArm] = []
  while self.peek_word() != Some("esac") {
    let patterns : Array[Word] = []
    while self.peek() != Some(RParen) {
      patterns.push(self.take_word())
      if self.peek() == Some(Pipe) {
        self.pos += 1
      } else if self.peek() != Some(RParen) {
        raise ShellError("expected ')' in case")
      }
    }
    self.pos += 1
    let body = self.parse_until([])
    arms.push({ patterns, body, })
    if self.peek() == Some(CaseEnd) {
      self.pos += 1
      self.skip_sequences()
    } else {
      break
    }
  }
  self.take_reserved("esac")
  CaseStatement(subject, arms)
}

///|
fn Parser::parse_for(self : Parser) -> Statement raise ShellError {
  self.take_reserved("for")
  let name = match word_literal(self.take_word()) {
    Some(value) => value
    _ => raise ShellError("for variable must be a name")
  }
  let words : Array[Word] = []
  if self.peek_word() == Some("in") {
    self.pos += 1
    while self.peek() is Some(WordToken(_)) {
      words.push(self.take_word())
    }
  }
  self.skip_sequences()
  self.take_reserved("do")
  let body = self.parse_until(["done"])
  self.take_reserved("done")
  ForStatement(name, words, body)
}

///|
fn Parser::parse_loop(
  self : Parser,
  until : Bool,
) -> Statement raise ShellError {
  self.take_reserved(if until { "until" } else { "while" })
  let condition = self.parse_until(["do"])
  self.take_reserved("do")
  let body = self.parse_until(["done"])
  self.take_reserved("done")
  LoopStatement(condition, body, until)
}

///|
fn Parser::parse_statement(self : Parser) -> Statement raise ShellError {
  match self.peek_word() {
    Some("if") => self.parse_if()
    Some("case") => self.parse_case()
    Some("for") => self.parse_for()
    Some("while") => self.parse_loop(false)
    Some("until") => self.parse_loop(true)
    Some(name) if self.pos + 3 < self.tokens.length() &&
      self.tokens[self.pos + 1] == LParen &&
      self.tokens[self.pos + 2] == RParen &&
      self.tokens[self.pos + 3] == LBrace => {
      self.pos += 4
      let body = self.parse_until([])
      if self.peek() != Some(RBrace) {
        raise ShellError("unterminated function body")
      }
      self.pos += 1
      FunctionStatement(name, body)
    }
    None =>
      match self.peek() {
        Some(LParen) => {
          self.pos += 1
          let body = self.parse_until([])
          if self.peek() != Some(RParen) {
            raise ShellError("unterminated subshell")
          }
          self.pos += 1
          GroupStatement(body, true)
        }
        Some(LBrace) => {
          self.pos += 1
          let body = self.parse_until([])
          if self.peek() != Some(RBrace) {
            raise ShellError("unterminated group")
          }
          self.pos += 1
          GroupStatement(body, false)
        }
        _ => Pipeline(self.parse_pipeline())
      }
    _ => Pipeline(self.parse_pipeline())
  }
}

///|
fn parse(script : String) -> Array[Job] raise ShellError {
  let parser : Parser = { tokens: lex(script), pos: 0, }
  parser.parse_until([])
}
