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
  TimeAge(@fsops.TimestampKind, Comparison, Int, Int64)
  Newer(@fsops.TimestampKind, @fsops.TimestampKind, String)
  Used(Comparison, Int)
  Readable
  Writable
  Executable
  XKind(Char)
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
  followed_kind : @fs.FileKind?
  size : Int64?
  atime : @fsops.FileTimestamp?
  mtime : @fsops.FileTimestamp?
  ctime : @fsops.FileTimestamp?
  readable : Bool?
  writable : Bool?
  executable : Bool?
  empty : Bool
}

///|
priv struct MetadataNeeds {
  size : Bool
  atime : Bool
  mtime : Bool
  ctime : Bool
  followed_kind : Bool
  readable : Bool
  writable : Bool
  executable : Bool
}

///|
priv struct ReferenceTime {
  path : String
  kind : @fsops.TimestampKind
  timestamp : @fsops.FileTimestamp
}

///|
priv struct FindContext {
  now : @fsops.FileTimestamp
  references : Array[ReferenceTime]
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
fn timestamp_kind(code : Char) -> @fsops.TimestampKind raise FindError {
  match code {
    'a' => AccessTime
    'c' => StatusChangeTime
    'm' => ModificationTime
    _ => raise FindError("invalid timestamp selector: '\{code}'")
  }
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
  if token.has_prefix("-newer") && token.length() == 8 {
    let source = timestamp_kind(token.get_char(6).unwrap())
    let reference = timestamp_kind(token.get_char(7).unwrap())
    return Newer(source, reference, self.take())
  }
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
      TimeAge(ModificationTime, comparison, value, 86400L)
    }
    "-mmin" => {
      let (comparison, value) = parse_mtime(self.take())
      TimeAge(ModificationTime, comparison, value, 60L)
    }
    "-atime" => {
      let (comparison, value) = parse_mtime(self.take())
      TimeAge(AccessTime, comparison, value, 86400L)
    }
    "-amin" => {
      let (comparison, value) = parse_mtime(self.take())
      TimeAge(AccessTime, comparison, value, 60L)
    }
    "-ctime" => {
      let (comparison, value) = parse_mtime(self.take())
      TimeAge(StatusChangeTime, comparison, value, 86400L)
    }
    "-cmin" => {
      let (comparison, value) = parse_mtime(self.take())
      TimeAge(StatusChangeTime, comparison, value, 60L)
    }
    "-newer" => Newer(ModificationTime, ModificationTime, self.take())
    "-anewer" => Newer(AccessTime, ModificationTime, self.take())
    "-cnewer" => Newer(StatusChangeTime, ModificationTime, self.take())
    "-used" => {
      let (comparison, value) = parse_mtime(self.take())
      Used(comparison, value)
    }
    "-readable" => Readable
    "-writable" => Writable
    "-executable" => Executable
    "-xtype" => {
      let kind = self.take()
      if kind.length() != 1 ||
        !(kind[0] is ('f' | 'd' | 'l' | 'p' | 's' | 'b' | 'c')) {
        raise FindError("invalid file type: '\{kind}'")
      }
      XKind(kind.get_char(0).unwrap())
    }
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
fn no_metadata_needs() -> MetadataNeeds {
  {
    size: false,
    atime: false,
    mtime: false,
    ctime: false,
    followed_kind: false,
    readable: false,
    writable: false,
    executable: false,
  }
}

///|
fn merge_needs(left : MetadataNeeds, right : MetadataNeeds) -> MetadataNeeds {
  {
    size: left.size || right.size,
    atime: left.atime || right.atime,
    mtime: left.mtime || right.mtime,
    ctime: left.ctime || right.ctime,
    followed_kind: left.followed_kind || right.followed_kind,
    readable: left.readable || right.readable,
    writable: left.writable || right.writable,
    executable: left.executable || right.executable,
  }
}

///|
fn FindExpr::metadata_needs(self : FindExpr) -> MetadataNeeds {
  let needs = no_metadata_needs()
  match self {
    Empty | Size(_, _, _) => { ..needs, size: true, }
    TimeAge(kind, _, _, _) | Newer(kind, _, _) =>
      match kind {
        AccessTime => { ..needs, atime: true, }
        ModificationTime => { ..needs, mtime: true, }
        StatusChangeTime => { ..needs, ctime: true, }
      }
    Used(_, _) => { ..needs, atime: true, ctime: true, }
    Readable => { ..needs, readable: true, }
    Writable => { ..needs, writable: true, }
    Executable => { ..needs, executable: true, }
    XKind(_) => { ..needs, followed_kind: true, }
    Not(inner) => inner.metadata_needs()
    And(left, right) | Or(left, right) =>
      merge_needs(left.metadata_needs(), right.metadata_needs())
    _ => needs
  }
}

///|
async fn load_reference_times(
  expression : FindExpr,
  references : Array[ReferenceTime],
) -> Unit {
  match expression {
    Newer(_, kind, path) => {
      if references.any(reference => {
          reference.path == path && reference.kind == kind
        }) {
        return
      }
      let timestamp = @fsops.read_file_timestamp(path, kind)
      references.push({ path, kind, timestamp, })
    }
    Not(inner) => load_reference_times(inner, references)
    And(left, right) | Or(left, right) => {
      load_reference_times(left, references)
      load_reference_times(right, references)
    }
    _ => ()
  }
}

///|
fn entry_timestamp(
  entry : FindEntry,
  kind : @fsops.TimestampKind,
) -> @fsops.FileTimestamp? {
  match kind {
    AccessTime => entry.atime
    ModificationTime => entry.mtime
    StatusChangeTime => entry.ctime
  }
}

///|
fn reference_timestamp(
  references : Array[ReferenceTime],
  path : String,
  kind : @fsops.TimestampKind,
) -> @fsops.FileTimestamp? {
  for reference in references {
    if reference.path == path && reference.kind == kind {
      return Some(reference.timestamp)
    }
  }
  None
}

///|
fn compare_age(actual : Int64, comparison : Comparison, wanted : Int) -> Bool {
  let wanted = wanted.to_int64()
  match comparison {
    Exact => actual == wanted
    Less => actual < wanted
    Greater => actual > wanted
  }
}

///|
async fn FindExpr::evaluate(
  self : FindExpr,
  entry : FindEntry,
  context : FindContext,
) -> (Bool, Bool) {
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
    TimeAge(kind, comparison, value, bucket) => {
      guard entry_timestamp(entry, kind) is Some(timestamp) else {
        return (false, false)
      }
      let age = @fsops.timestamp_age_bucket(context.now, timestamp, bucket)
      (compare_age(age, comparison, value), false)
    }
    Newer(source_kind, reference_kind, reference) => {
      guard entry_timestamp(entry, source_kind) is Some(source) &&
        reference_timestamp(context.references, reference, reference_kind)
        is Some(target) else {
        return (false, false)
      }
      (@fsops.compare_timestamps(source, target) > 0, false)
    }
    Used(comparison, value) => {
      guard entry.atime is Some(atime) && entry.ctime is Some(ctime) else {
        return (false, false)
      }
      let age = @fsops.timestamp_age_bucket(atime, ctime, 86400L)
      (compare_age(age, comparison, value), false)
    }
    Readable => (entry.readable == Some(true), false)
    Writable => (entry.writable == Some(true), false)
    Executable => (entry.executable == Some(true), false)
    XKind(wanted) =>
      (kind_matches(entry.followed_kind.unwrap_or(entry.kind), wanted), false)
    Prune => (true, true)
    Not(inner) => {
      let (matched, prune) = inner.evaluate(entry, context)
      (!matched, prune)
    }
    And(left, right) => {
      let (left_matched, left_prune) = left.evaluate(entry, context)
      if !left_matched {
        (false, left_prune)
      } else {
        let (right_matched, right_prune) = right.evaluate(entry, context)
        (right_matched, left_prune || right_prune)
      }
    }
    Or(left, right) => {
      let (left_matched, left_prune) = left.evaluate(entry, context)
      if left_matched {
        (true, left_prune)
      } else {
        let (right_matched, right_prune) = right.evaluate(entry, context)
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
      "Usage: find [PATH...] [EXPRESSION]\nPredicates include names, portable kinds, size, a/c/m times, newerXY, access checks, -used, -xtype, depth controls, actions, and boolean operators.\n",
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
  let needs = expression.metadata_needs()
  let references : Array[ReferenceTime] = []
  load_reference_times(expression, references) catch {
    err => {
      @stdio.stderr.write("find: cannot read reference timestamp: \{err}\n")
      @sys.exit(1)
      return
    }
  }
  let context : FindContext = { now: @fsops.current_timestamp(), references, }
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
    let kind = @fsops.kind_if_exists(path) catch {
      err => {
        @stdio.stderr.write("find: '\{path}': \{err}\n")
        failed = true
        continue
      }
    }
    guard kind is Some(kind) else {
      @stdio.stderr.write("find: '\{path}': no such file or directory\n")
      failed = true
      continue
    }
    let entries = if kind == Directory {
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
    let size = if needs.size && kind == Regular {
      let file = @fs.open(path, mode=ReadOnly)
      defer file.close()
      Some(file.size())
    } else {
      None
    }
    let atime = if needs.atime {
      Some(@fsops.read_file_timestamp(path, AccessTime, follow_symlink=false))
    } else {
      None
    }
    let mtime = if needs.mtime {
      Some(
        @fsops.read_file_timestamp(path, ModificationTime, follow_symlink=false),
      )
    } else {
      None
    }
    let ctime = if needs.ctime {
      Some(
        @fsops.read_file_timestamp(path, StatusChangeTime, follow_symlink=false),
      )
    } else {
      None
    }
    let followed_kind = if needs.followed_kind {
      if kind == SymLink {
        Some(@fs.kind(path, follow_symlink=true) catch { _ => SymLink })
      } else {
        Some(kind)
      }
    } else {
      None
    }
    let entry : FindEntry = {
      path,
      kind,
      followed_kind,
      size,
      atime,
      mtime,
      ctime,
      readable: if needs.readable {
        Some(@fs.can_read(path))
      } else {
        None
      },
      writable: if needs.writable {
        Some(@fs.can_write(path))
      } else {
        None
      },
      executable: if needs.executable {
        Some(@fs.can_execute(path))
      } else {
        None
      },
      empty: if kind == Directory {
        entries.is_empty()
      } else {
        size is Some(size) && size == 0L
      },
    }
    if parser.depth_first &&
      !postorder &&
      kind == Directory &&
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
      expression.evaluate(entry, context)
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
          if kind == Directory {
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
      kind == Directory &&
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
