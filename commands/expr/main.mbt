///|
priv suberror ExprError {
  ExprError(String)
}

///|
fn[T] fail(message : String) -> T raise ExprError {
  raise ExprError(message)
}

///|
struct Parser {
  args : Array[String]
  mut pos : Int32
}

///|
fn integer(s : String) -> Bool {
  let start = if s.has_prefix("-") { 1 } else { 0 }
  s.length() > start && s[start:].iter().all(c => c >= '0' && c <= '9')
}

///|
fn truth(s : String) -> Bool {
  s != "" && (!integer(s) || !BigInt::from_string(s).is_zero())
}

///|
fn precedence(s : String) -> Int32 {
  match s {
    "|" => 1
    "&" => 2
    "=" | "==" | "!=" | "<" | ">" | "<=" | ">=" => 3
    "+" | "-" => 4
    "*" | "/" | "%" => 5
    ":" => 6
    _ => 0
  }
}

///|
fn regex_match(value : String, pattern : String) -> String raise {
  let re = @bytere.compile(pattern)
  match re.find(value) {
    Some(hit) if hit.start == 0 =>
      if re.group_count() > 0 {
        hit.groups[1].unwrap_or("")
      } else {
        hit.end.to_string()
      }
    _ => if re.group_count() > 0 { "" } else { "0" }
  }
}

///|
fn Parser::atom(self : Parser, active : Bool) -> String raise {
  guard self.pos < self.args.length() else { fail("missing operand") }
  let token = self.args[self.pos]
  self.pos += 1
  match token {
    "(" => {
      let value = self.expression(1, active)
      guard self.pos < self.args.length() && self.args[self.pos] == ")" else {
        fail("missing closing parenthesis")
      }
      self.pos += 1
      value
    }
    "+" => {
      guard self.pos < self.args.length() else {
        fail("missing quoted operand")
      }
      let value = self.args[self.pos]
      self.pos += 1
      value
    }
    "length" => {
      let value = self.atom(active)
      value.length().to_string()
    }
    "index" => {
      let value = self.atom(active)
      let chars = self.atom(active)
      let mut found = 0
      for i in 0..<value.length() {
        if chars.contains(value[i:i + 1]) {
          found = i + 1
          break
        }
      }
      found.to_string()
    }
    "substr" => {
      let value = self.atom(active)
      let offset = self.atom(active)
      let length = self.atom(active)
      if !active || !integer(offset) || !integer(length) {
        return ""
      }
      let start = BigInt::from_string(offset)
      let count = BigInt::from_string(length)
      if start <= BigInt::from_int(0) ||
        count <= BigInt::from_int(0) ||
        start > BigInt::from_int(value.length()) {
        return ""
      }
      let left = start.to_int() - 1
      let available = value.length() - left
      let take = if count > BigInt::from_int(available) {
        available
      } else {
        count.to_int()
      }
      value[left:left + take].to_owned()
    }
    "match" => {
      let value = self.atom(active)
      let pattern = self.atom(active)
      if active {
        regex_match(value, pattern)
      } else {
        ""
      }
    }
    ")" => fail("unexpected closing parenthesis")
    _ => token
  }
}

///|
fn binary(op : String, left : String, right : String) -> String raise {
  if op == "|" {
    return if truth(left) { left } else if truth(right) { right } else { "0" }
  }
  if op == "&" {
    return if truth(left) && truth(right) { left } else { "0" }
  }
  if op == ":" {
    return regex_match(left, right)
  }
  if ["=", "==", "!=", "<", ">", "<=", ">="].contains(op) {
    let cmp = if integer(left) && integer(right) {
      BigInt::from_string(left).compare(BigInt::from_string(right))
    } else {
      left.compare(right)
    }
    let yes = match op {
      "=" | "==" => cmp == 0
      "!=" => cmp != 0
      "<" => cmp < 0
      ">" => cmp > 0
      "<=" => cmp <= 0
      _ => cmp >= 0
    }
    return if yes { "1" } else { "0" }
  }
  guard integer(left) && integer(right) else { fail("non-integer argument") }
  let a = BigInt::from_string(left)
  let b = BigInt::from_string(right)
  if (op == "/" || op == "%") && b.is_zero() {
    fail("division by zero")
  }
  let value = match op {
    "+" => a + b
    "-" => a - b
    "*" => a * b
    "/" => a / b
    _ => a % b
  }
  value.to_string()
}

///|
fn Parser::expression(
  self : Parser,
  minimum : Int32,
  active : Bool,
) -> String raise {
  let mut left = self.atom(active)
  while self.pos < self.args.length() {
    let op = self.args[self.pos]
    let level = precedence(op)
    if level < minimum {
      break
    }
    self.pos += 1
    let use_right = active &&
      !(op == "|" && truth(left)) &&
      !(op == "&" && !truth(left))
    let right = self.expression(level + 1, use_right)
    if active {
      left = binary(op, left, right)
    }
  }
  left
}

///|
fn evaluate(args : Array[String]) -> String raise {
  let parser = { args, pos: 0, }
  let value = parser.expression(1, true)
  guard parser.pos == args.length() else {
    fail("unexpected argument: " + args[parser.pos])
  }
  value
}

///|
async fn main {
  let metadata_args = @env.args()[1:]
  if metadata_args.length() == 1 && metadata_args[0] == "--version" {
    @stdio.stdout.write("expr 0.1.2\n")
    return
  }
  let args = @env.args()[1:].to_owned()
  if args == ["--help"] {
    @stdio.stdout.write(
      "Usage: expr EXPRESSION\n      --help      display this help and exit\n      --version   display version and exit\nEvaluate integer/string expressions: | & comparisons + - * / % :\nFunctions: match, substr, index, length; + quotes one operand.\nC-locale byte strings; regex backreferences and locale collation are unsupported.\n",
    )
    return
  }
  if args == ["--version"] {
    @stdio.stdout.write("expr 0.1.2\n")
    return
  }
  if args.get(0) == Some("--") {
    ignore(args.remove(0))
  }
  let value = evaluate(args.map(@bytere.argument)) catch {
    ExprError(message) | @bytere.PatternError(message) => {
      @stdio.stderr.write("expr: \{message}\n")
      @sys.exit(2)
      return
    }
    err => {
      @stdio.stderr.write("expr: \{err}\n")
      @sys.exit(2)
      return
    }
  }
  @stdio.stdout.write(@bytere.bytes(value + "\n"))
  if !truth(value) {
    @sys.exit(1)
  }
}
