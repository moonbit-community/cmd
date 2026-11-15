///|
pub(all) suberror ParseError {
  ParseError(String)
}

///|
pub(all) enum Comparison {
  Exact
  Less
  Greater
}

///|
pub(all) enum Action {
  Print(Bool)
  Exec(Array[String], Bool)
  Delete
}

///|
pub(all) enum Expression {
  Always(Bool)
  Name(Regex)
  Path(Regex)
  Kind(Char)
  Empty
  Size(Comparison, UInt64, UInt64)
  TimeAge(@fsops.TimestampKind, TimeTest)
  Newer(@fsops.TimestampKind, @fsops.TimestampKind, String)
  Used(TimeTest)
  Readable
  Writable
  Executable
  XKind(Char)
  Action(Action)
  Prune
  Not(Expression)
  And(Expression, Expression)
  Or(Expression, Expression)
}

///|
pub(all) struct Parser {
  tokens : Array[String]
  now : @fsops.FileTimestamp
  mut pos : Int32
  mut min_depth : Int32
  mut max_depth : Int32
  mut depth_first : Bool
  mut explicit_depth : Bool
  mut action : Action?
}

///|
pub fn Parser::peek(self : Parser) -> String? {
  self.tokens.get(self.pos)
}

///|
fn Parser::take(self : Parser) -> String raise ParseError {
  guard self.tokens.get(self.pos) is Some(token) else {
    raise ParseError("missing expression argument")
  }
  self.pos += 1
  token
}

///|
fn regex_escape_char(out : StringBuilder, c : Char) -> Unit {
  if c is ('.' | '^' | '$' | '+' | '(' | ')' | '{' | '}' | '|' | '\\') {
    out.write_char('\\')
  }
  out.write_char(c)
}

///|
fn glob_regex(pattern : String) -> Regex raise ParseError {
  let chars : Array[Char] = pattern.iter().collect()
  let out = StringBuilder()
  out.write_char('^')
  let mut i = 0
  while i < chars.length() {
    match chars[i] {
      '*' => out.write_string(".*")
      '?' => out.write_char('.')
      '[' => {
        let mut end = i + 1
        while end < chars.length() && chars[end] != ']' {
          end += 1
        }
        if end >= chars.length() {
          regex_escape_char(out, '[')
        } else {
          out.write_char('[')
          let mut start = i + 1
          if start < end && (chars[start] == '!' || chars[start] == '^') {
            out.write_char('^')
            start += 1
          }
          for j in start..<end {
            if chars[j] == '\\' {
              out.write_char('\\')
            }
            out.write_char(chars[j])
          }
          out.write_char(']')
          i = end
        }
      }
      c => regex_escape_char(out, c)
    }
    i += 1
  }
  out.write_char('$')
  Regex(out.to_string()) catch {
    _ => raise ParseError("invalid pattern: '\{pattern}'")
  }
}

///|
fn parse_depth(text : String, option : String) -> Int32 raise ParseError {
  let value = @string.parse_int(text) catch {
    _ => raise ParseError("invalid \{option}: '\{text}'")
  }
  if value < 0 {
    raise ParseError("invalid \{option}: '\{text}'")
  }
  value
}

///|
fn parse_comparison(text : String) -> (Comparison, String) {
  if text.has_prefix("+") {
    (Greater, text[1:].to_owned())
  } else if text.has_prefix("-") {
    (Less, text[1:].to_owned())
  } else {
    (Exact, text)
  }
}

///|
fn parse_size(text : String) -> (Comparison, UInt64, UInt64) raise ParseError {
  if text == "" {
    raise ParseError("invalid null argument to -size")
  }
  let (comparison, raw) = parse_comparison(text)
  let chars : Array[Char] = raw.iter().collect()
  let (end, unit) = match chars.last() {
    Some('b') => (chars.length() - 1, 512UL)
    Some('c') => (chars.length() - 1, 1UL)
    Some('w') => (chars.length() - 1, 2UL)
    Some('k' | 'K') => (chars.length() - 1, 1024UL)
    Some('M') => (chars.length() - 1, 1048576UL)
    Some('G') => (chars.length() - 1, 1073741824UL)
    Some('0'..<='9') => (chars.length(), 512UL)
    Some(suffix) => raise ParseError("invalid -size type `\{suffix}'")
    None => raise ParseError("Invalid argument `\{text}' to -size")
  }
  let mut index = 0
  while index < end &&
        chars[index] is (' ' | '\t' | '\n' | '\r' | '\u000b' | '\u000c') {
    index += 1
  }
  if index < end && chars[index] == '+' {
    index += 1
  }
  if index == end {
    raise ParseError("Invalid argument `\{text}' to -size")
  }
  let mut value = 0UL
  while index < end {
    guard chars[index] is ('0'..<='9') else {
      raise ParseError("Invalid argument `\{text}' to -size")
    }
    let digit = (chars[index].to_int() - 0x30).to_uint64()
    if value > (0xffffffffffffffffUL - digit) / 10UL {
      raise ParseError("Invalid argument `\{text}' to -size")
    }
    value = value * 10UL + digit
    index += 1
  }
  (comparison, value, unit)
}

///|
pub fn size_units(bytes : Int64, unit : UInt64) -> UInt64 {
  let bytes = bytes.reinterpret_as_uint64()
  bytes / unit + (if bytes % unit == 0UL { 0UL } else { 1UL })
}

///|
fn timestamp_kind(code : Char) -> @fsops.TimestampKind raise ParseError {
  match code {
    'a' => AccessTime
    'c' => StatusChangeTime
    'm' => ModificationTime
    _ => raise ParseError("invalid timestamp selector: '\{code}'")
  }
}

///|
fn Parser::set_action(self : Parser, action : Action) -> Unit raise ParseError {
  if self.action is Some(_) {
    raise ParseError("only one output or execution action is supported")
  }
  self.action = Some(action)
}

///|
fn Parser::parse_primary(self : Parser) -> Expression raise ParseError {
  let token = self.take()
  if token.has_prefix("-newer") && token.length() == 8 {
    let source = timestamp_kind(token.get_char(6).unwrap())
    let reference = timestamp_kind(token.get_char(7).unwrap())
    return Newer(source, reference, self.take())
  }
  match token {
    "(" => {
      let expression = self.parse_or()
      if self.take() != ")" {
        raise ParseError("expected ')'")
      }
      expression
    }
    "!" | "-not" => Not(self.parse_primary())
    "-name" => Name(glob_regex(self.take()))
    "-path" | "-wholename" => Path(glob_regex(self.take()))
    "-type" => {
      let kind = self.take()
      if kind.length() != 1 ||
        !(kind[0] is ('f' | 'd' | 'l' | 'p' | 's' | 'b' | 'c')) {
        raise ParseError("invalid file type: '\{kind}'")
      }
      Kind(kind.get_char(0).unwrap())
    }
    "-empty" => Empty
    "-size" => {
      let (comparison, value, unit) = parse_size(self.take())
      Size(comparison, value, unit)
    }
    "-mtime" =>
      TimeAge(ModificationTime, parse_time_test(self.take(), self.now, 86400L))
    "-mmin" =>
      TimeAge(ModificationTime, parse_time_test(self.take(), self.now, 60L))
    "-atime" =>
      TimeAge(AccessTime, parse_time_test(self.take(), self.now, 86400L))
    "-amin" => TimeAge(AccessTime, parse_time_test(self.take(), self.now, 60L))
    "-ctime" =>
      TimeAge(StatusChangeTime, parse_time_test(self.take(), self.now, 86400L))
    "-cmin" =>
      TimeAge(StatusChangeTime, parse_time_test(self.take(), self.now, 60L))
    "-newer" => Newer(ModificationTime, ModificationTime, self.take())
    "-anewer" => Newer(AccessTime, ModificationTime, self.take())
    "-cnewer" => Newer(StatusChangeTime, ModificationTime, self.take())
    "-used" => Used(parse_time_test(self.take(), self.now, 86400L, used=true))
    "-readable" => Readable
    "-writable" => Writable
    "-executable" => Executable
    "-xtype" => {
      let kind = self.take()
      if kind.length() != 1 ||
        !(kind[0] is ('f' | 'd' | 'l' | 'p' | 's' | 'b' | 'c')) {
        raise ParseError("invalid file type: '\{kind}'")
      }
      XKind(kind.get_char(0).unwrap())
    }
    "-depth" => {
      self.depth_first = true
      self.explicit_depth = true
      Always(true)
    }
    "-prune" => Prune
    "-maxdepth" => {
      self.max_depth = parse_depth(self.take(), "maximum depth")
      Always(true)
    }
    "-mindepth" => {
      self.min_depth = parse_depth(self.take(), "minimum depth")
      Always(true)
    }
    "-print" => {
      self.set_action(Print(false))
      Action(Print(false))
    }
    "-print0" => {
      self.set_action(Print(true))
      Action(Print(true))
    }
    "-exec" => {
      let command : Array[String] = []
      while self.peek() is Some(next) && next != ";" && next != "+" {
        command.push(self.take())
      }
      if command.is_empty() || self.peek() is None {
        raise ParseError("-exec: missing command or terminator")
      }
      let terminator = self.take()
      if self.peek() is Some(_) {
        raise ParseError("-exec ... ; must be the final expression action")
      }
      if terminator == "+" && !command.any(argument => argument == "{}") {
        raise ParseError("-exec ... + requires '{}' placeholder")
      }
      if terminator != ";" && terminator != "+" {
        raise ParseError("-exec: expected ';' or '+' terminator")
      }
      self.set_action(Exec(command, terminator == "+"))
      Action(Exec(command, terminator == "+"))
    }
    "-delete" => {
      self.depth_first = true
      self.set_action(Delete)
      Action(Delete)
    }
    "-true" => Always(true)
    "-false" => Always(false)
    _ => raise ParseError("unknown predicate: '\{token}'")
  }
}

///|
fn starts_primary(token : String?) -> Bool {
  match token {
    Some(")" | "-o" | "-or") | None => false
    _ => true
  }
}

///|
fn Parser::parse_and(self : Parser) -> Expression raise ParseError {
  let mut expression = self.parse_primary()
  while starts_primary(self.peek()) {
    if self.peek() == Some("-a") || self.peek() == Some("-and") {
      ignore(self.take())
    }
    expression = And(expression, self.parse_primary())
  }
  expression
}

///|
pub fn Parser::parse_or(self : Parser) -> Expression raise ParseError {
  let mut expression = self.parse_and()
  while self.peek() == Some("-o") || self.peek() == Some("-or") {
    ignore(self.take())
    expression = Or(expression, self.parse_and())
  }
  expression
}
