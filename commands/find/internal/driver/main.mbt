///|
priv struct Entry {
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
fn Expression::metadata_needs(self : Expression) -> MetadataNeeds {
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
  expression : Expression,
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
  entry : Entry,
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
async fn Expression::evaluate(
  self : Expression,
  entry : Entry,
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
      let actual = @expression.size_units(actual_bytes, unit)
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
pub async fn run_main() -> Unit {
  let now = @fsops.current_timestamp()
  let metadata_args = @env.args()[1:]
  if metadata_args.length() == 1 && metadata_args[0] == "--version" {
    @stdio.stdout.write("find \{MODULE_VERSION}\n")
    return
  }
  let args = @env.args()[1:]
  if args.length() == 1 && args[0] == "--help" {
    @stdio.stdout.write(metadata_help())
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
  let parser : Parser = {
    tokens: expression_tokens,
    now,
    pos: 0,
    min_depth: 0,
    max_depth: 0x7FFFFFFF,
    depth_first: false,
    explicit_depth: false,
    action: None,
  }
  let expression : Expression = if expression_tokens.is_empty() {
    Always(true)
  } else {
    parser.parse_or() catch {
      @expression.ParseError(message) => {
        @stdio.stderr.write("find: \{message}\n")
        @env.exit(1)
        return
      }
    }
  }
  if parser.pos != expression_tokens.length() {
    @stdio.stderr.write("find: unexpected expression token\n")
    @env.exit(1)
    return
  }
  let references : Array[ReferenceTime] = []
  load_reference_times(expression, references) catch {
    err => {
      @stdio.stderr.write("find: cannot read reference timestamp: \{err}\n")
      @env.exit(1)
      return
    }
  }
  if parser.action is Some(Delete) &&
    !parser.explicit_depth &&
    expression.contains_prune() {
    @stdio.stderr.write(
      "find: -delete with -prune requires explicit -depth; depth-first traversal makes -prune ineffective\n",
    )
    @env.exit(1)
    return
  }
  let context : FindContext = { references, }
  let failed = walk_find(paths, parser, expression, context)
  if failed {
    @env.exit(1)
  }
}
