///|
fn test_integer(value : String) -> Int64 raise ShellError {
  let chars = value.iter().collect()
  let mut start = 0
  let mut end = chars.length()
  while start < end &&
        chars[start] is (' ' | '\t' | '\n' | '\r' | '\u000b' | '\u000c') {
    start += 1
  }
  while end > start &&
        chars[end - 1] is (' ' | '\t' | '\n' | '\r' | '\u000b' | '\u000c') {
    end -= 1
  }
  let mut digit = start
  if digit < end && chars[digit] is ('+' | '-') {
    digit += 1
  }
  if digit == end {
    raise ShellError("test: integer expected")
  }
  for index = digit; index < end; index = index + 1 {
    if chars[index] < '0' || chars[index] > '9' {
      raise ShellError("test: integer expected")
    }
  }
  @string.parse_int64(String::from_array(chars[start:end]), base=10) catch {
    _ => raise ShellError("test: integer expected")
  }
}

///|
priv struct TestParser {
  args : Array[String]
  context : Context
  mut cursor : Int32
}

///|
fn test_binary(operator : String) -> Bool {
  [
    "=", "==", "!=", "<", ">", "-eq", "-ne", "-lt", "-le", "-gt", "-ge", "-nt", "-ot",
    "-ef",
  ].contains(operator)
}

///|
fn test_unary(operator : String) -> Bool {
  [
    "-n", "-z", "-e", "-f", "-d", "-b", "-c", "-p", "-S", "-L", "-h", "-r", "-w",
    "-x", "-s", "-u", "-g", "-k", "-O", "-G", "-t",
  ].contains(operator)
}

///|
async fn TestParser::primary(self : TestParser) -> Bool {
  guard self.args.get(self.cursor) is Some(value) else { return false }
  let remaining = self.args.length() - self.cursor
  if value == "(" && remaining > 1 {
    self.cursor += 1
    if self.args.get(self.cursor) == Some(")") {
      self.cursor += 1
      return false
    }
    let result = self.disjunction()
    guard self.args.get(self.cursor) == Some(")") else {
      raise ShellError("test: closing parenthesis expected")
    }
    self.cursor += 1
    return result
  }
  let binary = self.args.get(self.cursor + 1).map(test_binary).unwrap_or(false)
  if test_unary(value) && remaining > 1 && !(binary && remaining > 2) {
    let argument = self.args[self.cursor + 1]
    self.cursor += 2
    return test_term([value, argument], self.context)
  }
  if binary {
    guard self.args.get(self.cursor + 2) is Some(right) else {
      raise ShellError("test: binary argument expected")
    }
    let operator = self.args[self.cursor + 1]
    self.cursor += 3
    return test_term([value, operator, right], self.context)
  }
  self.cursor += 1
  value != ""
}

///|
async fn TestParser::negation(self : TestParser) -> Bool {
  if self.args.get(self.cursor) == Some("!") {
    self.cursor += 1
    !self.negation()
  } else {
    self.primary()
  }
}

///|
async fn TestParser::conjunction(self : TestParser) -> Bool {
  let mut value = self.negation()
  while self.args.get(self.cursor) == Some("-a") {
    self.cursor += 1
    let right = self.negation()
    value = value && right
  }
  value
}

///|
async fn TestParser::disjunction(self : TestParser) -> Bool {
  let mut value = self.conjunction()
  while self.args.get(self.cursor) == Some("-o") {
    self.cursor += 1
    let right = self.conjunction()
    value = value || right
  }
  value
}

///|
async fn test_expression(args : Array[String], context : Context) -> Bool {
  let mut operands = args
  let mut invert = false
  while operands.length() == 3 || operands.length() == 4 {
    if operands is [left, operator, right] && test_binary(operator) {
      return test_term([left, operator, right], context) != invert
    }
    if operands[0] == "(" && operands.last() == Some(")") {
      operands = operands[1:operands.length() - 1].to_owned()
      break
    }
    if operands[0] != "!" {
      break
    }
    // Dash's finite argument-count recheck sets inversion, rather than
    // toggling it again when a four-argument case becomes a three-argument one.
    invert = true
    operands = operands[1:].to_owned()
  }
  let parser : TestParser = { args: operands, context, cursor: 0, }
  let result = parser.disjunction()
  if parser.cursor != operands.length() {
    raise ShellError("test: unexpected operator '\{operands[parser.cursor]}'")
  }
  result != invert
}
