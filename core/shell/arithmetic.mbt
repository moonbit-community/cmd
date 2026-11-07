///|
priv struct ArithmeticParser {
  chars : Array[Char]
  mut pos : Int32
  context : Context
}

///|
fn ArithmeticParser::skip(self : ArithmeticParser) -> Unit {
  while self.pos < self.chars.length() &&
        self.chars[self.pos] is (' ' | '\t' | '\n') {
    self.pos += 1
  }
}

///|
fn arithmetic_precedence(operator : String) -> Int32 {
  match operator {
    "||" => 1
    "&&" => 2
    "|" => 3
    "^" => 4
    "&" => 5
    "==" | "!=" => 6
    "<" | ">" | "<=" | ">=" => 7
    "<<" | ">>" => 8
    "+" | "-" => 9
    "*" | "/" | "%" => 10
    _ => 0
  }
}

///|
fn ArithmeticParser::operator(self : ArithmeticParser) -> String {
  self.skip()
  for width in [3, 2] {
    if self.pos + width <= self.chars.length() {
      let operator = String::from_array(self.chars[self.pos:self.pos + width])
      if [
          "<<=", ">>=", "++", "--", "+=", "-=", "*=", "/=", "%=", "&=", "|=", "^=",
          "||", "&&", "==", "!=", "<=", ">=", "<<", ">>",
        ].contains(operator) {
        return operator
      }
    }
  }
  self.chars.get(self.pos).map(c => c.to_string()).unwrap_or("")
}

///|
fn arithmetic_number(value : String) -> Int64 raise ShellError {
  let value = value.trim().to_owned()
  if value == "" {
    return 0L
  }
  let (unsigned, negative) = if value.has_prefix("-") {
    (value[1:].to_owned(), true)
  } else if value.has_prefix("+") {
    (value[1:].to_owned(), false)
  } else {
    (value, false)
  }
  let (digits, base) = if unsigned.has_prefix("0x") || unsigned.has_prefix("0X") {
    (unsigned[2:].to_owned(), 16)
  } else if unsigned.length() > 1 && unsigned.has_prefix("0") {
    (unsigned[1:].to_owned(), 8)
  } else {
    (unsigned, 10)
  }
  @string.parse_int64((if negative { "-" } else { "" }) + digits, base~) catch {
    _ => raise ShellError("invalid arithmetic value: '\{value}'")
  }
}

///|
fn ArithmeticParser::primary(
  self : ArithmeticParser,
  active : Bool,
) -> Int64 raise ShellError {
  let operator = self.operator()
  if ["+", "-", "!", "~", "++", "--"].contains(operator) {
    self.pos += operator.length()
    if operator == "++" || operator == "--" {
      self.skip()
      let start = self.pos
      guard self.chars.get(start) is Some(ch) && is_name_start(ch) else {
        raise ShellError("arithmetic increment requires a variable")
      }
      while self.pos < self.chars.length() && is_name_char(self.chars[self.pos]) {
        self.pos += 1
      }
      let name = String::from_array(self.chars[start:self.pos])
      if !active {
        return 0L
      }
      let value = arithmetic_variable(name, self.context) +
        (if operator == "++" { 1L } else { -1L })
      self.context.env[name] = value.to_string()
      return value
    }
    let value = self.primary(active)
    return if !active {
      0L
    } else {
      match operator {
        "-" => -value
        "!" => if value == 0L { 1L } else { 0L }
        "~" => value.lnot()
        _ => value
      }
    }
  }
  guard self.chars.get(self.pos) is Some(ch) else {
    raise ShellError("incomplete arithmetic expression")
  }
  if ch == '(' {
    self.pos += 1
    let value = self.assignment(active)
    if self.operator() != ")" {
      raise ShellError("missing ')' in arithmetic expression")
    }
    self.pos += 1
    return value
  }
  if is_name_start(ch) {
    let start = self.pos
    while self.pos < self.chars.length() && is_name_char(self.chars[self.pos]) {
      self.pos += 1
    }
    let name = String::from_array(self.chars[start:self.pos])
    let postfix = self.operator()
    if postfix == "++" || postfix == "--" {
      self.pos += 2
      if !active {
        return 0L
      }
      let value = arithmetic_variable(name, self.context)
      self.context.env[name] = (value + (if postfix == "++" { 1L } else { -1L })).to_string()
      return value
    }
    return if active { arithmetic_variable(name, self.context) } else { 0L }
  }
  if ch is ('0'..<='9') {
    let start = self.pos
    while self.pos < self.chars.length() &&
          self.chars[self.pos]
          is ('0'..<='9' | 'a'..<='f' | 'A'..<='F' | 'x' | 'X') {
      self.pos += 1
    }
    return arithmetic_number(String::from_array(self.chars[start:self.pos]))
  }
  raise ShellError("unsupported arithmetic operator '\{ch}'")
}

///|
fn ArithmeticParser::binary(
  self : ArithmeticParser,
  minimum : Int32,
  active : Bool,
) -> Int64 raise ShellError {
  let mut value = self.primary(active)
  for ;; {
    let operator = self.operator()
    let precedence = arithmetic_precedence(operator)
    if precedence < minimum {
      break
    }
    self.pos += operator.length()
    let evaluate_right = active &&
      !(operator == "&&" && value == 0L) &&
      !(operator == "||" && value != 0L)
    let right = self.binary(precedence + 1, evaluate_right)
    value = if active { arithmetic_binary(operator, value, right) } else { 0L }
  }
  value
}

///|
fn ArithmeticParser::conditional(
  self : ArithmeticParser,
  active : Bool,
) -> Int64 raise ShellError {
  let condition = self.binary(1, active)
  if self.operator() != "?" {
    return condition
  }
  self.pos += 1
  let yes = self.assignment(active && condition != 0L)
  if self.operator() != ":" {
    raise ShellError("missing ':' in arithmetic conditional")
  }
  self.pos += 1
  let no = self.conditional(active && condition == 0L)
  if condition != 0L {
    yes
  } else {
    no
  }
}

///|
fn ArithmeticParser::assignment(
  self : ArithmeticParser,
  active : Bool,
) -> Int64 raise ShellError {
  self.skip()
  let start = self.pos
  if self.chars.get(self.pos) is Some(ch) && is_name_start(ch) {
    while self.pos < self.chars.length() && is_name_char(self.chars[self.pos]) {
      self.pos += 1
    }
    let name = String::from_array(self.chars[start:self.pos])
    let operator = self.operator()
    if ["=", "+=", "-=", "*=", "/=", "%=", "<<=", ">>=", "&=", "|=", "^="].contains(
        operator,
      ) {
      self.pos += operator.length()
      let right = self.assignment(active)
      if !active {
        return 0L
      }
      let value = if operator == "=" {
        right
      } else {
        arithmetic_binary(
          operator[:operator.length() - 1].to_owned(),
          arithmetic_variable(name, self.context),
          right,
        )
      }
      self.context.env[name] = value.to_string()
      return value
    }
  }
  self.pos = start
  self.conditional(active)
}

///|
fn arithmetic_binary(
  operator : String,
  left : Int64,
  right : Int64,
) -> Int64 raise ShellError {
  match operator {
    "+" => left + right
    "-" => left - right
    "*" => left * right
    "/" | "%" => {
      if right == 0L {
        raise ShellError("arithmetic division by zero")
      }
      if operator == "/" {
        left / right
      } else {
        left % right
      }
    }
    "<<" => left << right.to_int()
    ">>" => left >> right.to_int()
    "&" => left.land(right)
    "|" => left.lor(right)
    "^" => left.lxor(right)
    "==" => if left == right { 1L } else { 0L }
    "!=" => if left != right { 1L } else { 0L }
    "<" => if left < right { 1L } else { 0L }
    ">" => if left > right { 1L } else { 0L }
    "<=" => if left <= right { 1L } else { 0L }
    ">=" => if left >= right { 1L } else { 0L }
    "&&" => if left != 0L && right != 0L { 1L } else { 0L }
    "||" => if left != 0L || right != 0L { 1L } else { 0L }
    _ => raise ShellError("unsupported arithmetic operator")
  }
}

///|
fn arithmetic_variable(
  name : String,
  context : Context,
) -> Int64 raise ShellError {
  match context.env.get(name) {
    Some(value) => arithmetic_number(value)
    None =>
      if context.nounset {
        raise ShellError("\{name}: parameter not set")
      } else {
        0L
      }
  }
}

///|
fn evaluate_arithmetic(
  expression : String,
  context : Context,
) -> Int64 raise ShellError {
  let parser : ArithmeticParser = {
    chars: expression.iter().collect(),
    pos: 0,
    context,
  }
  parser.skip()
  if parser.pos == parser.chars.length() {
    return 0L
  }
  let value = parser.assignment(true)
  parser.skip()
  if parser.pos != parser.chars.length() {
    raise ShellError("unsupported arithmetic syntax")
  }
  value
}
