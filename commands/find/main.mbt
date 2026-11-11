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
  Size(Comparison, UInt64, UInt64)
  TimeAge(@fsops.TimestampKind, FindTimeTest)
  Newer(@fsops.TimestampKind, @fsops.TimestampKind, String)
  Used(FindTimeTest)
  Readable
  Writable
  Executable
  XKind(Char)
  Action(FindAction)
  Prune
  Not(FindExpr)
  And(FindExpr, FindExpr)
  Or(FindExpr, FindExpr)
}

///|
priv struct FindParser {
  tokens : Array[String]
  now : @fsops.FileTimestamp
  mut pos : Int32
  mut min_depth : Int32
  mut max_depth : Int32
  mut depth_first : Bool
  mut explicit_depth : Bool
  mut action : FindAction?
}

///|
priv struct FindEntry {
  path : String
  kind : @fs.FileKind
  mut size : FindMetadata[Int64]
  mut atime : FindMetadata[@fsops.FileTimestamp]
  mut mtime : FindMetadata[@fsops.FileTimestamp]
  mut ctime : FindMetadata[@fsops.FileTimestamp]
  mut failed : Bool
  directory : DirectoryVisit?
}

///|
priv struct MetadataNeeds {
  size : Bool
  regular_size : Bool
  atime : Bool
  mtime : Bool
  ctime : Bool
}

///|
priv struct FindEvaluation {
  times : FindContext
  batch : FindBatch?
}

///|
priv struct ReferenceTime {
  path : String
  kind : @fsops.TimestampKind
  timestamp : @fsops.FileTimestamp
}

///|
priv struct FindContext {
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
fn parse_depth(text : String, option : String) -> Int32 raise FindError {
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
fn parse_size(text : String) -> (Comparison, UInt64, UInt64) raise FindError {
  if text == "" {
    raise FindError("invalid null argument to -size")
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
    Some(suffix) => raise FindError("invalid -size type `\{suffix}'")
    None => raise FindError("Invalid argument `\{text}' to -size")
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
    raise FindError("Invalid argument `\{text}' to -size")
  }
  let mut value = 0UL
  while index < end {
    guard chars[index] is ('0'..<='9') else {
      raise FindError("Invalid argument `\{text}' to -size")
    }
    let digit = (chars[index].to_int() - 0x30).to_uint64()
    if value > (0xffffffffffffffffUL - digit) / 10UL {
      raise FindError("Invalid argument `\{text}' to -size")
    }
    value = value * 10UL + digit
    index += 1
  }
  (comparison, value, unit)
}

///|
fn size_units(bytes : Int64, unit : UInt64) -> UInt64 {
  let bytes = bytes.reinterpret_as_uint64()
  bytes / unit + (if bytes % unit == 0UL { 0UL } else { 1UL })
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
        raise FindError("invalid file type: '\{kind}'")
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
      Action(Exec(command, terminator == "+"))
    }
    "-delete" => {
      self.depth_first = true
      self.set_action(Delete)
      Action(Delete)
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
    regular_size: false,
    atime: false,
    mtime: false,
    ctime: false,
  }
}

///|
fn merge_needs(left : MetadataNeeds, right : MetadataNeeds) -> MetadataNeeds {
  {
    size: left.size || right.size,
    regular_size: left.regular_size || right.regular_size,
    atime: left.atime || right.atime,
    mtime: left.mtime || right.mtime,
    ctime: left.ctime || right.ctime,
  }
}

///|
fn FindExpr::metadata_needs(self : FindExpr) -> MetadataNeeds {
  let needs = no_metadata_needs()
  match self {
    Empty => { ..needs, regular_size: true, }
    Size(_, _, _) => { ..needs, size: true, }
    TimeAge(kind, _) | Newer(kind, _, _) =>
      match kind {
        AccessTime => { ..needs, atime: true, }
        ModificationTime => { ..needs, mtime: true, }
        StatusChangeTime => { ..needs, ctime: true, }
      }
    Used(_) => { ..needs, atime: true, ctime: true, }
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
      let timestamp = @fsops.read_file_timestamp(
        find_lookup_path(path),
        kind,
        follow_symlink=false,
      )
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
async fn entry_timestamp(
  entry : FindEntry,
  kind : @fsops.TimestampKind,
) -> @fsops.FileTimestamp? {
  entry.timestamp(kind)
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
async fn FindExpr::evaluate(
  self : FindExpr,
  entry : FindEntry,
  context : FindEvaluation,
) -> (Bool, Bool) {
  match self {
    Always(value) => (value, false)
    Name(regex) => (regex.execute(base_name(entry.path)) is Some(_), false)
    Path(regex) => (regex.execute(entry.path) is Some(_), false)
    Kind(wanted) => (kind_matches(entry.kind, wanted), false)
    Empty =>
      (
        match entry.directory {
          Some(directory) =>
            match directory.names(fresh=true) {
              Some(names) => names.is_empty()
              None => {
                entry.failed = true
                false
              }
            }
          None => entry.kind == Regular && entry.byte_size() == Some(0L)
        },
        false,
      )
    Size(comparison, value, unit) => {
      guard entry.byte_size() is Some(actual_bytes) else {
        return (false, false)
      }
      let actual = size_units(actual_bytes, unit)
      let matched = match comparison {
        Exact => actual == value
        Less => actual < value
        Greater => actual > value
      }
      (matched, false)
    }
    TimeAge(kind, query) => {
      guard entry_timestamp(entry, kind) is Some(timestamp) else {
        return (false, false)
      }
      (query.matches(timestamp), false)
    }
    Newer(source_kind, reference_kind, reference) => {
      guard entry_timestamp(entry, source_kind) is Some(source) &&
        reference_timestamp(context.times.references, reference, reference_kind)
        is Some(target) else {
        return (false, false)
      }
      (@fsops.compare_timestamps(source, target) > 0, false)
    }
    Used(query) => {
      guard entry.timestamp(AccessTime) is Some(atime) &&
        entry.timestamp(StatusChangeTime) is Some(ctime) else {
        return (false, false)
      }
      (query.matches_used(atime, ctime), false)
    }
    Readable => (find_access(entry.path, 'r'), false)
    Writable => (find_access(entry.path, 'w'), false)
    Executable => (find_access(entry.path, 'x'), false)
    XKind(wanted) => (entry.followed_kind_matches(wanted), false)
    Action(action) => (action.execute(entry, context), false)
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
fn begins_expression(token : String) -> Bool {
  token == "(" || token == "!" || token.has_prefix("-")
}

///|
async fn main {
  let now = @fsops.current_timestamp()
  let metadata_args = @env.args()[1:]
  if metadata_args.length() == 1 && metadata_args[0] == "--version" {
    @stdio.stdout.write("find \{MODULE_VERSION}\n")
    return
  }
  let args = @env.args()[1:]
  if args.length() == 1 && args[0] == "--help" {
    @stdio.stdout.write(
      "Usage: find [PATH...] [EXPRESSION]\n      --help      display this help and exit\n      --version   display version and exit\nPredicates include names, portable kinds, size, a/c/m times, newerXY, access checks, -used, -xtype, depth controls, actions, and boolean operators.\n-size rounds up in b/c/w/k/M/G units (default b); K is a project alias for k.\nTime arguments accept finite decimal, exponent and hexadecimal numbers within signed 64-bit seconds.\nDirectory names are read only for descent or an evaluated -empty; stat fields precede directory reads and child effects.\nActions execute at their expression position; -delete with -prune requires explicit -depth.\n-exec ... + runs completed batches during traversal with a 64 KiB UTF-8 argument budget.\nUnavailable size/timestamp metadata is an error, not a nonmatch.\n",
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
    now,
    pos: 0,
    min_depth: 0,
    max_depth: 0x7FFFFFFF,
    depth_first: false,
    explicit_depth: false,
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
  let references : Array[ReferenceTime] = []
  load_reference_times(expression, references) catch {
    err => {
      @stdio.stderr.write("find: cannot read reference timestamp: \{err}\n")
      @sys.exit(1)
      return
    }
  }
  if parser.action is Some(Delete) &&
    !parser.explicit_depth &&
    expression.contains_prune() {
    @stdio.stderr.write(
      "find: -delete with -prune requires explicit -depth; depth-first traversal makes -prune ineffective\n",
    )
    @sys.exit(1)
    return
  }
  let context : FindContext = { references, }
  let failed = walk_find(paths, parser, expression, context)
  if failed {
    @sys.exit(1)
  }
}
