///|
priv suberror TestError {
  TestError(String)
}

///|
priv struct Parser {
  args : Array[String]
  mut pos : Int
}

///|
fn Parser::peek(self : Parser) -> String? {
  self.args.get(self.pos)
}

///|
fn Parser::take(self : Parser) -> String raise TestError {
  guard self.args.get(self.pos) is Some(value) else {
    raise TestError("missing argument")
  }
  self.pos += 1
  value
}

///|
fn is_unary(op : String) -> Bool {
  op == "-n" ||
  op == "-z" ||
  op == "-e" ||
  op == "-a" ||
  op == "-f" ||
  op == "-d" ||
  op == "-r" ||
  op == "-w" ||
  op == "-x"
}

///|
fn is_binary(op : String) -> Bool {
  op == "=" ||
  op == "==" ||
  op == "!=" ||
  op == "<" ||
  op == ">" ||
  op == "-eq" ||
  op == "-ne" ||
  op == "-lt" ||
  op == "-le" ||
  op == "-gt" ||
  op == "-ge"
}

///|
async fn eval_unary(op : String, value : String) -> Bool {
  match op {
    "-n" => value != ""
    "-z" => value == ""
    "-e" | "-a" => @fs.exists(value)
    "-f" => (@fs.kind(value) catch { _ => Unknown }) == Regular
    "-d" => (@fs.kind(value) catch { _ => Unknown }) == Directory
    "-r" => @fs.can_read(value)
    "-w" => @fs.can_write(value)
    "-x" => @fs.can_execute(value)
    _ => raise TestError("unknown unary operator: '\{op}'")
  }
}

///|
fn parse_integer(text : String) -> Int64 raise TestError {
  @string.parse_int64(text) catch {
    _ => raise TestError("integer expression expected: '\{text}'")
  }
}

///|
fn eval_binary(
  left : String,
  op : String,
  right : String,
) -> Bool raise TestError {
  match op {
    "=" | "==" => left == right
    "!=" => left != right
    "<" => left < right
    ">" => left > right
    "-eq" => parse_integer(left) == parse_integer(right)
    "-ne" => parse_integer(left) != parse_integer(right)
    "-lt" => parse_integer(left) < parse_integer(right)
    "-le" => parse_integer(left) <= parse_integer(right)
    "-gt" => parse_integer(left) > parse_integer(right)
    "-ge" => parse_integer(left) >= parse_integer(right)
    _ => raise TestError("unknown binary operator: '\{op}'")
  }
}

///|
async fn Parser::parse_primary(self : Parser) -> Bool {
  let token = self.take()
  if token == "(" {
    let value = self.parse_or()
    if self.take() != ")" {
      raise TestError("expected ')'")
    }
    return value
  }
  if is_unary(token) {
    return eval_unary(token, self.take())
  }
  match self.peek() {
    Some(op) if is_binary(op) => {
      ignore(self.take())
      eval_binary(token, op, self.take())
    }
    _ => token != ""
  }
}

///|
async fn Parser::parse_not(self : Parser) -> Bool {
  if self.peek() == Some("!") {
    ignore(self.take())
    !self.parse_not()
  } else {
    self.parse_primary()
  }
}

///|
async fn Parser::parse_and(self : Parser) -> Bool {
  let mut value = self.parse_not()
  while self.peek() == Some("-a") {
    ignore(self.take())
    let right = self.parse_not()
    value = value && right
  }
  value
}

///|
async fn Parser::parse_or(self : Parser) -> Bool {
  let mut value = self.parse_and()
  while self.peek() == Some("-o") {
    ignore(self.take())
    let right = self.parse_and()
    value = value || right
  }
  value
}

///|
async fn main {
  let args = @env.args()[1:].to_owned()
  if args == ["--help"] {
    @stdio.stdout.write(
      "Usage: test EXPRESSION\nSupports string, integer, file, !, -a, and -o expressions.\n",
    )
    return
  }
  if args.is_empty() {
    @sys.exit(1)
    return
  }
  let parser : Parser = { args, pos: 0, }
  let result = parser.parse_or() catch {
    TestError(message) => {
      @stdio.stderr.write("test: \{message}\n")
      @sys.exit(2)
      return
    }
    err => {
      @stdio.stderr.write("test: \{err}\n")
      @sys.exit(2)
      return
    }
  }
  if parser.pos != args.length() {
    @stdio.stderr.write("test: unexpected argument: '\{args[parser.pos]}'\n")
    @sys.exit(2)
    return
  }
  if !result {
    @sys.exit(1)
  }
}
