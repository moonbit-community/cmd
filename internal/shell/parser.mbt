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
fn Parser::take_word(self : Parser) -> Word raise ShellError {
  guard self.tokens.get(self.pos) is Some(WordToken(word)) else {
    raise ShellError("redirection requires a path")
  }
  self.pos += 1
  word
}

///|
fn Parser::parse_command(self : Parser) -> Command raise ShellError {
  let words : Array[Word] = []
  let mut stdin : Word? = None
  let mut stdout : Redirect? = None
  let mut stderr : Redirect? = None
  let mut keep_parsing = true
  while keep_parsing {
    match self.peek() {
      Some(WordToken(word)) => {
        words.push(word)
        self.pos += 1
      }
      Some(RedirectIn) => {
        self.pos += 1
        stdin = Some(self.take_word())
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
      _ => keep_parsing = false
    }
  }
  if words.is_empty() {
    raise ShellError("expected a command")
  }
  { words, stdin, stdout, stderr, }
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
fn parse(script : String) -> Array[Job] raise ShellError {
  let parser : Parser = { tokens: lex(script), pos: 0, }
  let jobs : Array[Job] = []
  let mut connector = Always
  while parser.pos < parser.tokens.length() {
    while parser.peek() == Some(Sequence) {
      parser.pos += 1
    }
    if parser.pos >= parser.tokens.length() {
      break
    }
    jobs.push({ connector, pipeline: parser.parse_pipeline(), })
    match parser.peek() {
      Some(AndIf) => {
        connector = OnSuccess
        parser.pos += 1
      }
      Some(OrIf) => {
        connector = OnFailure
        parser.pos += 1
      }
      Some(Sequence) => {
        connector = Always
        parser.pos += 1
      }
      None => ()
      _ => raise ShellError("unexpected token after command")
    }
  }
  jobs
}
