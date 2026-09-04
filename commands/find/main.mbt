///|
priv suberror FindError {
  FindError(String)
}

///|
priv enum Comparison {
  Exact
  Less
  Greater
}

///|
priv enum FindAction {
  Print(Bool)
  Exec(Array[String], Bool)
  Delete
}

///|
priv enum FindExpr {
  Always(Bool)
  Name(Regex)
  Path(Regex)
  Kind(Char)
  Empty
  Size(Comparison, Int64, Bool)
  MTime(Comparison, Int)
  Newer(String)
  Prune
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
  mut depth_first : Bool
  mut action : FindAction?
}

///|
priv struct FindEntry {
  path : String
  kind : @fs.FileKind
  size : Int64?
  mtime_seconds : Int64
  mtime_nanoseconds : Int
  empty : Bool
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
fn parse_size(text : String) -> (Comparison, Int64, Bool) raise FindError {
  let (comparison, raw) = parse_comparison(text)
  guard raw != "" else { raise FindError("invalid size: '{text}'") }
  let chars : Array[Char] = raw.iter().collect()
  let suffix = chars.last()
  let (digits, multiplier, blocks) = match suffix {
    Some('c') => (raw[:raw.length() - 1].to_owned(), 1L, false)
    Some('k') | Some('K') => (raw[:raw.length() - 1].to_owned(), 1024L, false)
    Some('M') => (raw[:raw.length() - 1].to_owned(), 1024L * 1024L, false)
    Some('G') =>
      (raw[:raw.length() - 1].to_owned(), 1024L * 1024L * 1024L, false)
    _ => (raw, 1L, true)
  }
  let value = @string.parse_int(digits) catch {
    _ => raise FindError("invalid size: '{text}'")
  }
  if value < 0 {
    raise FindError("invalid size: '{text}'")
  }
  (comparison, value.to_int64() * multiplier, blocks)
}

///|
fn parse_mtime(text : String) -> (Comparison, Int) raise FindError {
  let (comparison, raw) = parse_comparison(text)
  let value = @string.parse_int(raw) catch {
    _ => raise FindError("invalid mtime: '{text}'")
  }
  if value < 0 {
    raise FindError("invalid mtime: '{text}'")
  }
  (comparison, value)
}

///|
fn FindParser::set_action(
  self : FindParser,
  action : FindAction,
) -> Unit raise FindError {
  if self.action is Some(_) {
    raise FindError("only one output or execution action is supported")
  }
  self.action = Some(action)
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
    "-empty" => Empty
    "-size" => {
      let (comparison, value, blocks) = parse_size(self.take())
      Size(comparison, value, blocks)
    }
    "-mtime" => {
      let (comparison, value) = parse_mtime(self.take())
      MTime(comparison, value)
    }
    "-newer" => Newer(self.take())
    "-depth" => {
      self.depth_first = true
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
      Always(true)
    }
    "-print0" => {
      self.set_action(Print(true))
      Always(true)
    }
    "-exec" => {
      let command : Array[String] = []
      while self.peek() is Some(next) && next != ";" && next != "+" {
        command.push(self.take())
      }
      if command.is_empty() || self.peek() is None {
        raise FindError("-exec: missing command or terminator")
      }
      let terminator = self.take()
      if self.peek() is Some(_) {
        raise FindError("-exec ... ; must be the final expression action")
      }
      if terminator == "+" && !command.any(argument => argument == "{}") {
        raise FindError("-exec ... + requires '{}' placeholder")
      }
      if terminator != ";" && terminator != "+" {
        raise FindError("-exec: expected ';' or '+' terminator")
      }
      self.set_action(Exec(command, terminator == "+"))
      Always(true)
    }
    "-delete" => {
      self.depth_first = true
      self.set_action(Delete)
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
async fn FindExpr::evaluate(self : FindExpr, entry : FindEntry) -> (Bool, Bool) {
  match self {
    Always(value) => (value, false)
    Name(regex) => (regex.execute(base_name(entry.path)) is Some(_), false)
    Path(regex) => (regex.execute(entry.path) is Some(_), false)
    Kind(wanted) => (kind_matches(entry.kind, wanted), false)
    Empty => (entry.empty, false)
    Size(comparison, value, blocks) => {
      let actual_bytes = match entry.size {
        Some(bytes) => bytes
        None => -1L
      }
      let actual = if blocks && actual_bytes >= 0L {
        (actual_bytes + 511L) / 512L
      } else {
        actual_bytes
      }
      let matched = match comparison {
        Exact => actual == value
        Less => actual < value
        Greater => actual > value
      }
      (matched, false)
    }
    MTime(comparison, value) => {
      let age = (
          @env.now().reinterpret_as_int64() / 1000L - entry.mtime_seconds
        ) /
        86400L
      let wanted = value.to_int64()
      let matched = match comparison {
        Exact => age == wanted
        Less => age < wanted
        Greater => age > wanted
      }
      (matched, false)
    }
    Newer(reference) => {
      let matched = match @fsops.metadata_if_exists(reference) {
        Some(metadata) =>
          entry.mtime_seconds > metadata.mtime_seconds ||
          (
            entry.mtime_seconds == metadata.mtime_seconds &&
            entry.mtime_nanoseconds > metadata.mtime_nanoseconds
          )
        None => false
      }
      (matched, false)
    }
    Prune => (true, true)
    Not(inner) => {
      let (matched, prune) = inner.evaluate(entry)
      (!matched, prune)
    }
    And(left, right) => {
      let (left_matched, left_prune) = left.evaluate(entry)
      if !left_matched {
        (false, left_prune)
      } else {
        let (right_matched, right_prune) = right.evaluate(entry)
        (right_matched, left_prune || right_prune)
      }
    }
    Or(left, right) => {
      let (left_matched, left_prune) = left.evaluate(entry)
      if left_matched {
        (true, left_prune)
      } else {
        let (right_matched, right_prune) = right.evaluate(entry)
        (right_matched, left_prune || right_prune)
      }
    }
  }
}

///|
fn join_path(parent : String, name : String) -> String {
  if parent == "." {
    "./" + name
  } else if parent == "/" {
    "/" + name
  } else {
    @fsops.join(parent, name)
  }
}

///|
fn exec_batch_size(command : Array[String], values : Array[String]) -> Int {
  let mut size = 0
  for argument in command {
    if argument == "{}" {
      for value in values {
        size += value.length() + 1
      }
    } else {
      size += argument.length() + 1
    }
  }
  size
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
      "Usage: find [PATH...] [EXPRESSION]\nPredicates: -name, -path, -type, -empty, -size, -mtime, -newer, -mindepth, -maxdepth, -depth, -prune, -delete, !, -a, -o, -print, -print0, -exec COMMAND ;|+\n",
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
    depth_first: false,
    action: None,
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
  let stack : Array[(String, Int, Bool)] = []
  let mut path_index = paths.length()
  while path_index > 0 {
    path_index -= 1
    stack.push((paths[path_index], 0, false))
  }
  let mut failed = false
  let mut batch_command : Array[String]? = None
  let batch_values : Array[String] = []
  let batch_groups : Array[(Array[String], Array[String])] = []
  while stack.pop() is Some((path, depth, postorder)) {
    let metadata = @fsops.metadata_if_exists(path) catch {
      err => {
        @stdio.stderr.write("find: '\{path}': \{err}\n")
        failed = true
        continue
      }
    }
    guard metadata is Some(metadata) else {
      @stdio.stderr.write("find: '\{path}': no such file or directory\n")
      failed = true
      continue
    }
    let entries = if metadata.kind == Directory {
      @fs.readdir(path, include_hidden=true, include_special=false, sort=false) catch {
        err => {
          @stdio.stderr.write("find: '\{path}': \{err}\n")
          failed = true
          []
        }
      }
    } else {
      []
    }
    entries.sort_by((left, right) => left.lexical_compare(right))
    let entry : FindEntry = {
      path,
      kind: metadata.kind,
      size: metadata.size,
      mtime_seconds: metadata.mtime_seconds,
      mtime_nanoseconds: metadata.mtime_nanoseconds,
      empty: if metadata.kind == Directory {
        entries.is_empty()
      } else {
        metadata.size is Some(size) && size == 0L
      },
    }
    if parser.depth_first &&
      !postorder &&
      metadata.kind == Directory &&
      depth < parser.max_depth {
      stack.push((path, depth, true))
      let mut index = entries.length()
      while index > 0 {
        index -= 1
        stack.push((join_path(entry.path, entries[index]), depth + 1, false))
      }
      continue
    }
    let in_depth = depth >= parser.min_depth && depth <= parser.max_depth
    let (matched, prune) = if in_depth {
      expression.evaluate(entry)
    } else {
      (false, false)
    }
    if in_depth && matched && !(prune && parser.action is Some(Print(_))) {
      match parser.action {
        None => {
          @stdio.stdout.write(path)
          @stdio.stdout.write("\n")
        }
        Some(Print(zero)) => {
          @stdio.stdout.write(path)
          @stdio.stdout.write(if zero { "\u0000" } else { "\n" })
        }
        Some(Delete) =>
          if metadata.kind == Directory {
            @fs.rmdir(path)
          } else {
            @fs.remove(path)
          }
        Some(Exec(command, batch)) =>
          if batch {
            if batch_command is Some(_) &&
              !batch_values.is_empty() &&
              exec_batch_size(command, batch_values + [path]) > 64 * 1024 {
              batch_groups.push((command, batch_values.copy()))
              batch_values.clear()
            }
            batch_command = Some(command)
            batch_values.push(path)
          } else {
            let expanded : Array[String] = command.map(argument => {
              if argument == "{}" {
                path
              } else {
                argument
              }
            })
            guard expanded.get(0) is Some(program) else { continue }
            let code = @process.run(
              @process.child(program, expanded[1:].to_owned()),
            ) catch {
              err => {
                @stdio.stderr.write("find: \{err}\n")
                failed = true
                continue
              }
            }
            if code < 0 {
              @stdio.stderr.write("find: child terminated by signal\n")
            }
          }
      }
    }
    if !parser.depth_first &&
      metadata.kind == Directory &&
      depth < parser.max_depth &&
      !prune {
      let mut index = entries.length()
      while index > 0 {
        index -= 1
        stack.push((join_path(entry.path, entries[index]), depth + 1, false))
      }
    }
  }
  if batch_command is Some(command) && !batch_values.is_empty() {
    batch_groups.push((command, batch_values.copy()))
  }
  for group in batch_groups {
    let command = group.0
    let values = group.1
    let argv : Array[String] = []
    for argument in command {
      if argument == "{}" {
        for value in values {
          argv.push(value)
        }
      } else {
        argv.push(argument)
      }
    }
    match argv.get(0) {
      Some(program) => {
        let code = @process.run(@process.child(program, argv[1:].to_owned())) catch {
          err => {
            @stdio.stderr.write("find: \{err}\n")
            failed = true
            -1
          }
        }
        if code != 0 {
          failed = true
        }
      }
      None => failed = true
    }
  }
  if failed {
    @sys.exit(1)
  }
}
