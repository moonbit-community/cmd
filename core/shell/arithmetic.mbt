///|
priv struct ArithmeticParser {
  chars : Array[Char]
  mut pos : Int
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
fn arithmetic_precedence(operator : String) -> Int {
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
  if self.pos + 1 < self.chars.length() {
    let pair = String::from_array(self.chars[self.pos:self.pos + 2])
    if arithmetic_precedence(pair) > 0 {
      return pair
    }
  }
  self.chars.get(self.pos).map(c => c.to_string()).unwrap_or("")
}

///|
fn arithmetic_number(value : String) -> Int64 raise ShellError {
  if value == "" {
    return 0L
  }
  let (digits, base) = if value.has_prefix("0x") || value.has_prefix("0X") {
    (value[2:].to_owned(), 16)
  } else if value.length() > 1 && value.has_prefix("0") {
    (value[1:].to_owned(), 8)
  } else {
    (value, 10)
  }
  @string.parse_int64(digits, base~) catch {
    _ => raise ShellError("invalid arithmetic value: '\{value}'")
  }
}

///|
fn ArithmeticParser::primary(
  self : ArithmeticParser,
  evaluate : Bool,
) -> Int64 raise ShellError {
  self.skip()
  guard self.chars.get(self.pos) is Some(ch) else {
    raise ShellError("incomplete arithmetic expression")
  }
  if ch is ('+' | '-' | '!' | '~') {
    self.pos += 1
    let value = self.primary(evaluate)
    return match ch {
      '-' => -value
      '!' => if value == 0L { 1L } else { 0L }
      '~' => value.lnot()
      _ => value
    }
  }
  if ch == '(' {
    self.pos += 1
    let value = self.expression(1, evaluate)
    self.skip()
    if self.chars.get(self.pos) != Some(')') {
      raise ShellError("missing ')' in arithmetic expression")
    }
    self.pos += 1
    return value
  }
  let start = self.pos
  if is_name_start(ch) {
    while self.pos < self.chars.length() && is_name_char(self.chars[self.pos]) {
      self.pos += 1
    }
    let name = String::from_array(self.chars[start:self.pos])
    return if evaluate {
      arithmetic_number(self.context.env.get(name).unwrap_or(""))
    } else {
      0L
    }
  }
  if ch is ('0'..='9') {
    while self.pos < self.chars.length() &&
          self.chars[self.pos]
          is ('0'..='9' | 'a'..='f' | 'A'..='F' | 'x' | 'X') {
      self.pos += 1
    }
    return arithmetic_number(String::from_array(self.chars[start:self.pos]))
  }
  raise ShellError("unsupported arithmetic operator '\{ch}'")
}

///|
fn ArithmeticParser::expression(
  self : ArithmeticParser,
  minimum : Int,
  evaluate : Bool,
) -> Int64 raise ShellError {
  let mut value = self.primary(evaluate)
  for ;; {
    let operator = self.operator()
    let precedence = arithmetic_precedence(operator)
    if precedence < minimum {
      break
    }
    self.pos += operator.length()
    let active = evaluate &&
      !(operator == "&&" && value == 0L) &&
      !(operator == "||" && value != 0L)
    let right = self.expression(precedence + 1, active)
    if !evaluate {
      value = 0L
      continue
    }
    value = match operator {
      "+" => value + right
      "-" => value - right
      "*" => value * right
      "/" | "%" => {
        if right == 0L {
          raise ShellError("arithmetic division by zero")
        }
        if operator == "/" {
          value / right
        } else {
          value % right
        }
      }
      "<<" => value << right.to_int()
      ">>" => value >> right.to_int()
      "&" => value.land(right)
      "|" => value.lor(right)
      "^" => value.lxor(right)
      "==" => if value == right { 1L } else { 0L }
      "!=" => if value != right { 1L } else { 0L }
      "<" => if value < right { 1L } else { 0L }
      ">" => if value > right { 1L } else { 0L }
      "<=" => if value <= right { 1L } else { 0L }
      ">=" => if value >= right { 1L } else { 0L }
      "&&" => if value != 0L && right != 0L { 1L } else { 0L }
      "||" => if value != 0L || right != 0L { 1L } else { 0L }
      _ => raise ShellError("unsupported arithmetic operator")
    }
  }
  value
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
  let value = parser.expression(1, true)
  parser.skip()
  if parser.pos != parser.chars.length() {
    raise ShellError("unsupported arithmetic syntax")
  }
  value
}
