///|
priv suberror TestError {
  TestError(String)
}

///|
priv struct Parser {
  args : Array[String]
  mut pos : Int32
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
  op == "-L" ||
  op == "-h" ||
  op == "-p" ||
  op == "-S" ||
  op == "-b" ||
  op == "-c" ||
  op == "-s" ||
  op == "-N" ||
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
  op == "-ge" ||
  op == "-nt" ||
  op == "-ot"
}

///|
async fn eval_unary(op : String, value : String) -> Bool {
  match op {
    "-n" => value != ""
    "-z" => value == ""
    _ if is_unary(op) => test_file(op, value)
    _ => raise TestError("unknown unary operator: '\{op}'")
  }
}

///|
fn parse_integer(text : String) -> Int64 raise TestError {
  let mut start = 0
  let mut end = text.length()
  while start < end &&
        text[start] is (' ' | '\t' | '\n' | '\r' | '\u000b' | '\u000c') {
    start += 1
  }
  while end > start &&
        text[end - 1] is (' ' | '\t' | '\n' | '\r' | '\u000b' | '\u000c') {
    end -= 1
  }
  let mut digits = start
  if digits < end && text[digits] is ('+' | '-') {
    digits += 1
  }
  guard digits < end else {
    raise TestError("integer expression expected: '\{text}'")
  }
  for i = digits; i < end; i = i + 1 {
    guard text[i] is ('0'..<='9') else {
      raise TestError("integer expression expected: '\{text}'")
    }
  }
  @string.parse_int64(text[start:end], base=10) catch {
    _ => raise TestError("integer expression expected: '\{text}'")
  }
}

///|
async fn optional_mtime(path : String) -> @fsops.FileTimestamp? {
  if path == "" {
    return None
  }
  try {
    guard test_lookup_path(path) is Some(path) else { return None }
    Some(@fsops.read_file_timestamp(path, ModificationTime))
  } catch {
    @os_error.OSError(_) => None
    error => raise error
  }
}

///|
async fn eval_binary(left : String, op : String, right : String) -> Bool {
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
    "-nt" =>
      match (optional_mtime(left), optional_mtime(right)) {
        (Some(left), Some(right)) => @fsops.compare_timestamps(left, right) > 0
        (Some(_), None) => true
        _ => false
      }
    "-ot" =>
      match (optional_mtime(left), optional_mtime(right)) {
        (Some(left), Some(right)) => @fsops.compare_timestamps(left, right) < 0
        (None, Some(_)) => true
        _ => false
      }
    _ => raise TestError("unknown binary operator: '\{op}'")
  }
}

///|
async fn Parser::parse_primary(self : Parser) -> Bool {
  let token = self.take()
  if token == "(" {
    let mut count = 1
    while self.pos + count < self.args.length() &&
          self.args[self.pos + count] != ")" {
      if count == 4 {
        count = self.args.length() - self.pos
        break
      }
      count += 1
    }
    let value = self.evaluate_count(count)
    if self.take() != ")" {
      raise TestError("expected ')'")
    }
    return value
  }
  match self.peek() {
    Some(op) if self.pos + 1 < self.args.length() && is_binary(op) => {
      ignore(self.take())
      eval_binary(token, op, self.take())
    }
    _ if token.length() == 2 && token.has_prefix("-") =>
      eval_unary(token, self.take())
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
  let metadata_args = @env.args()[1:]
  if metadata_args.length() == 1 && metadata_args[0] == "--version" {
    @stdio.stdout.write("test 0.2.4\n")
    return
  }
  let args = @env.args()[1:].to_owned()
  if args == ["--help"] {
    @stdio.stdout.write(
      "Usage: test EXPRESSION\n      --help      display this help and exit\n      --version   display version and exit\nSupports string, integer, portable file-kind, access, size, and timestamp expressions.\nOne through four arguments have standalone test precedence; a lone nonempty operator-looking string is true.\nInteger operands are signed 64-bit decimal with optional sign and surrounding ASCII whitespace.\n-s reads followed target metadata without opening the file; unavailable metadata exits 2.\nUnary -a is a project alias for -e. Exit 0 for true, 1 for false, and 2 for errors.\n",
    )
    return
  }
  if args.is_empty() {
    @sys.exit(1)
    return
  }
  let parser : Parser = { args, pos: 0, }
  let result = parser.evaluate_count(args.length()) catch {
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
