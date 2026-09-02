///|
priv suberror FindError {
  FindError(String)
}

///|
priv enum FindExpr {
  Always(Bool)
  Name(Regex)
  Path(Regex)
  Kind(Char)
  Not(FindExpr)
  And(FindExpr, FindExpr)
  Or(FindExpr, FindExpr)
}

///|
priv struct FindParser {
  tokens : Array[String]
  mut pos : Int
  mut min_depth : Int
  mut max_depth : Int
  mut print_zero : Bool
  mut print_requested : Bool
  exec_actions : Array[Array[String]]
}

///|
fn FindParser::peek(self : FindParser) -> String? {
  self.tokens.get(self.pos)
}

///|
fn FindParser::take(self : FindParser) -> String raise FindError {
  guard self.tokens.get(self.pos) is Some(token) else {
    raise FindError("missing expression argument")
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
fn glob_regex(pattern : String) -> Regex raise FindError {
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
    _ => raise FindError("invalid pattern: '\{pattern}'")
  }
}

///|
fn parse_depth(text : String, option : String) -> Int raise FindError {
  let value = @string.parse_int(text) catch {
    _ => raise FindError("invalid \{option}: '\{text}'")
  }
  if value < 0 {
    raise FindError("invalid \{option}: '\{text}'")
  }
  value
}

///|
fn FindParser::parse_primary(self : FindParser) -> FindExpr raise FindError {
  let token = self.take()
  match token {
    "(" => {
      let expression = self.parse_or()
      if self.take() != ")" {
        raise FindError("expected ')'")
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
        raise FindError("invalid file type: '\{kind}'")
      }
      Kind(kind.get_char(0).unwrap())
    }
    "-maxdepth" => {
      self.max_depth = parse_depth(self.take(), "maximum depth")
      Always(true)
    }
    "-mindepth" => {
      self.min_depth = parse_depth(self.take(), "minimum depth")
      Always(true)
    }
    "-print" => {
      self.print_zero = false
      self.print_requested = true
      Always(true)
    }
    "-print0" => {
      self.print_zero = true
      self.print_requested = true
      Always(true)
    }
    "-exec" => {
      if self.tokens.any(token => token is ("-o" | "-or" | "!" | "-not")) {
        raise FindError("-exec with OR or negation is not supported")
      }
      let command : Array[String] = []
      while self.peek() is Some(next) && next != ";" && next != "+" {
        command.push(self.take())
      }
      if command.is_empty() || self.peek() is None {
        raise FindError("-exec: missing command or terminator")
      }
      let terminator = self.take()
      if terminator == "+" {
        raise FindError("-exec ... + batching is not supported")
      }
      if self.peek() is Some(_) {
        raise FindError("-exec ... ; must be the final expression action")
      }
      self.exec_actions.push(command)
      Always(true)
    }
    "-true" => Always(true)
    "-false" => Always(false)
    _ => raise FindError("unknown predicate: '\{token}'")
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
fn FindParser::parse_and(self : FindParser) -> FindExpr raise FindError {
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
fn FindParser::parse_or(self : FindParser) -> FindExpr raise FindError {
  let mut expression = self.parse_and()
  while self.peek() == Some("-o") || self.peek() == Some("-or") {
    ignore(self.take())
    expression = Or(expression, self.parse_and())
  }
  expression
}

///|
fn base_name(path : String) -> String {
  if path == "/" {
    return "/"
  }
  let chars : Array[Char] = path.iter().collect()
  let mut end = chars.length()
  while end > 1 && chars[end - 1] == '/' {
    end -= 1
  }
  let mut start = end
  while start > 0 && chars[start - 1] != '/' {
    start -= 1
  }
  let out = StringBuilder()
  for index in start..<end {
    out.write_char(chars[index])
  }
  out.to_string()
}

///|
fn kind_matches(kind : @fs.FileKind, wanted : Char) -> Bool {
  match wanted {
    'f' => kind == Regular
    'd' => kind == Directory
    'l' => kind == SymLink
    'p' => kind == Pipe
    's' => kind == Socket
    'b' => kind == BlockDevice
    'c' => kind == CharDevice
    _ => false
  }
}

///|
fn FindExpr::matches(
  self : FindExpr,
  path : String,
  kind : @fs.FileKind,
) -> Bool {
  match self {
    Always(value) => value
    Name(regex) => regex.execute(base_name(path)) is Some(_)
    Path(regex) => regex.execute(path) is Some(_)
    Kind(wanted) => kind_matches(kind, wanted)
    Not(inner) => !inner.matches(path, kind)
    And(left, right) => left.matches(path, kind) && right.matches(path, kind)
    Or(left, right) => left.matches(path, kind) || right.matches(path, kind)
  }
}

///|
fn join_path(parent : String, name : String) -> String {
  if parent == "/" {
    "/" + name
  } else {
    parent + "/" + name
  }
}

///|
fn begins_expression(token : String) -> Bool {
  token == "(" || token == "!" || token.has_prefix("-")
}

///|
async fn main {
  let args = @env.args()[1:]
  if args.length() == 1 && args[0] == "--help" {
    @stdio.stdout.write(
      "Usage: find [PATH...] [EXPRESSION]\nPredicates: -name, -path, -type, -mindepth, -maxdepth, !, -a, -o, -print, -print0, -exec COMMAND ;\n",
    )
    return
  }
  let paths : Array[String] = []
  let expression_tokens : Array[String] = []
  let mut parsing_paths = true
  let mut options_ended = false
  for arg in args {
    if parsing_paths && arg == "--" && !options_ended {
      options_ended = true
    } else if parsing_paths && (!begins_expression(arg) || options_ended) {
      paths.push(arg)
      options_ended = false
    } else {
      parsing_paths = false
      expression_tokens.push(arg)
    }
  }
  if paths.is_empty() {
    paths.push(".")
  }
  let parser : FindParser = {
    tokens: expression_tokens,
    pos: 0,
    min_depth: 0,
    max_depth: 0x7FFFFFFF,
    print_zero: false,
    print_requested: false,
    exec_actions: [],
  }
  let expression = if expression_tokens.is_empty() {
    Always(true)
  } else {
    parser.parse_or() catch {
      FindError(message) => {
        @stdio.stderr.write("find: \{message}\n")
        @sys.exit(1)
        return
      }
    }
  }
  if parser.pos != expression_tokens.length() {
    @stdio.stderr.write("find: unexpected expression token\n")
    @sys.exit(1)
    return
  }
  let stack : Array[(String, Int)] = []
  let mut path_index = paths.length()
  while path_index > 0 {
    path_index -= 1
    stack.push((paths[path_index], 0))
  }
  let mut failed = false
  while stack.pop() is Some((path, depth)) {
    let kind = @fs.kind(path, follow_symlink=false) catch {
      err => {
        @stdio.stderr.write("find: '\{path}': \{err}\n")
        failed = true
        continue
      }
    }
    if depth >= parser.min_depth &&
      depth <= parser.max_depth &&
      expression.matches(path, kind) {
      if parser.print_requested || parser.exec_actions.is_empty() {
        @stdio.stdout.write(path)
        @stdio.stdout.write(if parser.print_zero { "\u0000" } else { "\n" })
      }
      for action in parser.exec_actions {
        let expanded : Array[String] = []
        for argument in action {
          expanded.push(if argument == "{}" { path } else { argument })
        }
        guard expanded.get(0) is Some(program) else { continue }
        ignore(
          @process.run(@process.child(program, expanded[1:].to_owned())) catch {
            err => {
              @stdio.stderr.write("find: \{err}\n")
              continue
            }
          },
        )
      }
    }
    if kind == Directory && depth < parser.max_depth {
      let entries = @fs.readdir(
        path,
        include_hidden=true,
        include_special=false,
        sort=false,
      ) catch {
        err => {
          @stdio.stderr.write("find: '\{path}': \{err}\n")
          failed = true
          continue
        }
      }
      entries.sort_by((left, right) => left.lexical_compare(right))
      let mut index = entries.length()
      while index > 0 {
        index -= 1
        stack.push((join_path(path, entries[index]), depth + 1))
      }
    }
  }
  if failed {
    @sys.exit(1)
  }
}
