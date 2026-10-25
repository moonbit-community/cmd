///|
async fn source(path : String) -> Bytes {
  if path == "-" {
    @stdio.stdin.read_all().binary()
  } else {
    @fs.read_file(path).binary()
  }
}

///|
priv suberror DiffError {
  DiffError(String)
}

///|
priv struct DiffSettings {
  comparison : CompareOptions
  brief : Bool
  report_identical : Bool
  text : Bool
  unified : Bool
  context_format : Bool
  context : Int32
  labels : Array[String]
  recursive : Bool
  new_file : Bool
  unidirectional : Bool
  command : String
}

///|
priv struct Comparison {
  left : String
  right : String
  nested : Bool
  left_present : Bool
  right_present : Bool
  left_ancestors : Array[String]
  right_ancestors : Array[String]
}

///|
fn quoted(value : String) -> String {
  if !value.is_empty() &&
    value
    .iter()
    .all(char => {
      (char >= 'a' && char <= 'z') ||
      (char >= 'A' && char <= 'Z') ||
      (char >= '0' && char <= '9') ||
      "_./=-+,:".contains(char.to_string())
    }) {
    value
  } else {
    "'" + value.replace_all(old="'", new="'\\''") + "'"
  }
}

///|
fn directory_operand(value : String, always~ : Bool = false) -> String {
  let bytes = @bytere.argument(value)
  if !always &&
    !bytes.is_empty() &&
    !bytes
    .iter()
    .any(char => char <= ' ' || char >= '\u007f' || char == '\\' || char == '"') {
    return value
  }
  let out = StringBuilder()
  out.write_char('"')
  for char in bytes {
    match char {
      '\\' => out.write_string("\\\\")
      '"' => out.write_string("\\\"")
      '\n' => out.write_string("\\n")
      '\t' => out.write_string("\\t")
      '\r' => out.write_string("\\r")
      '\u0007' => out.write_string("\\a")
      '\u0008' => out.write_string("\\b")
      '\u000b' => out.write_string("\\v")
      '\u000c' => out.write_string("\\f")
      _ => {
        let code = char.to_int()
        if code < 32 || code >= 127 {
          out.write_char('\\')
          out.write_char((48 + code / 64).unsafe_to_char())
          out.write_char((48 + code / 8 % 8).unsafe_to_char())
          out.write_char((48 + code % 8).unsafe_to_char())
        } else {
          out.write_char(char)
        }
      }
    }
  }
  out.write_char('"')
  out.to_string()
}

///|
fn diagnostic_path(value : String) -> String {
  let bytes = @bytere.argument(value)
  let mut quote = bytes.is_empty()
  let mut compatible = true
  let mut apostrophe = false
  for i in 0..<bytes.length() {
    let char = bytes[i].to_int().unsafe_to_char()
    let special = "? !\"$&()*;<=>[^`|\\'".contains(char.to_string())
    let unusual = char < ' ' || char >= '\u007f'
    if unusual ||
      special ||
      (i == 0 && (char == '#' || char == '~')) ||
      (bytes.length() == 1 && (char == '{' || char == '}')) {
      quote = true
    }
    if char == '\'' {
      apostrophe = true
    }
    if unusual ||
      (special && char != ' ' && char != '\'') ||
      char == '#' ||
      char == '~' ||
      char == '{' ||
      char == '}' {
      compatible = false
    }
  }
  if !quote {
    return value
  }
  if apostrophe && compatible {
    return directory_operand(value, always=true)
  }
  let out = StringBuilder()
  out.write_char('\'')
  let mut escaped = false
  for char in bytes {
    let code = char.to_int()
    if code < 32 || code >= 127 {
      if !escaped {
        out.write_string("'$'")
        escaped = true
      }
      out.write_char('\\')
      match char {
        '\n' => out.write_char('n')
        '\r' => out.write_char('r')
        '\t' => out.write_char('t')
        '\u0007' => out.write_char('a')
        '\u0008' => out.write_char('b')
        '\u000b' => out.write_char('v')
        '\u000c' => out.write_char('f')
        _ => {
          out.write_char((48 + code / 64).unsafe_to_char())
          out.write_char((48 + code / 8 % 8).unsafe_to_char())
          out.write_char((48 + code % 8).unsafe_to_char())
        }
      }
    } else if char == '\'' {
      out.write_string("'\\''")
      escaped = false
    } else {
      if escaped {
        out.write_string("''")
        escaped = false
      }
      out.write_char(char)
    }
  }
  out.write_char('\'')
  out.to_string()
}

///|
fn command_prefix(args : ArrayView[String]) -> String {
  let out = StringBuilder()
  out.write_string("diff")
  let mut options = true
  let mut value = false
  for arg in args {
    if value {
      out.write_string(" " + quoted(arg))
      value = false
    } else if options && arg == "--" {
      out.write_string(" --")
      options = false
    } else if options && arg != "-" && arg.has_prefix("-") {
      out.write_string(" " + quoted(arg))
      value = arg == "--label" ||
        arg == "--unified-lines" ||
        arg == "--context-lines" ||
        (!arg.has_prefix("--") && (arg.has_suffix("U") || arg.has_suffix("C")))
    }
  }
  out.to_string()
}

///|
fn separator(char : UInt16) -> Bool {
  char.to_int() == 47 || (@async.platform is Windows && char.to_int() == 92)
}

///|
fn path_parts(path : String) -> (String, String) {
  let mut last = -1
  for i in 0..<path.length() {
    if separator(path[i]) {
      last = i
    }
  }
  if last < 0 {
    (".", path)
  } else {
    (
      if last == 0 {
        path[0:1].to_owned()
      } else {
        path[:last].to_owned()
      },
      path[last + 1:].to_owned(),
    )
  }
}

///|
fn join_path(parent : String, name : String) -> String {
  parent + (if parent.has_suffix("/") { "" } else { "/" }) + name
}

///|
async fn file_kind(path : String) -> @fs.FileKind? {
  if path == "-" {
    return Some(Regular)
  }
  try @fs.kind(path) catch {
    @os_error.OSError(_) as err if err.is_ENOENT() => None
    err => raise err
  } noraise {
    kind => Some(kind)
  }
}

///|
fn kind_name(kind : @fs.FileKind) -> String {
  match kind {
    Directory => "a directory"
    Regular => "a regular file"
    Pipe => "a fifo"
    Socket => "a socket"
    CharDevice => "a character special file"
    BlockDevice => "a block special file"
    SymLink => "a symbolic link"
    Unknown => "an unknown file type"
  }
}

///|
async fn compare_files(
  task : Comparison,
  settings : DiffSettings,
  missing_left : Bool,
  missing_right : Bool,
) -> Int32 {
  let display_left = settings.labels
    .get(0)
    .unwrap_or_else(() => diagnostic_path(task.left))
  let display_right = settings.labels
    .get(1)
    .unwrap_or_else(() => diagnostic_path(task.right))
  if task.left == task.right && !missing_left && !missing_right {
    if settings.report_identical {
      @stdio.stdout.write(
        "Files \{display_left} and \{display_right} are identical\n",
      )
    }
    return 0
  }
  let a = if missing_left { b"" } else { source(task.left) }
  let b = if missing_right { b"" } else { source(task.right) }
  let binary = !settings.text &&
    (a.iter().any(v => v == b'\x00') || b.iter().any(v => v == b'\x00'))
  let changes = if a == b || binary {
    []
  } else {
    edits(
      lines(a),
      lines(b),
      options=settings.comparison,
      context=if settings.unified || settings.context_format {
        settings.context
      } else {
        0
      },
    )
  }
  let differs = if binary {
    a != b
  } else {
    changes.iter().any(edit => meaningful(edit, settings.comparison))
  }
  if !differs {
    if settings.report_identical {
      @stdio.stdout.write(
        "Files \{display_left} and \{display_right} are identical\n",
      )
    }
    return 0
  }
  if settings.brief || binary {
    let word = if settings.brief { "Files" } else { "Binary files" }
    @stdio.stdout.write("\{word} \{display_left} and \{display_right} differ\n")
    return 1
  }
  if task.nested {
    @stdio.stdout.write(
      settings.command +
      " " +
      directory_operand(task.left) +
      " " +
      directory_operand(task.right) +
      "\n",
    )
  }
  if settings.unified || settings.context_format {
    let left = settings.labels.get(0).unwrap_or_else(() => "")
    let right = settings.labels.get(1).unwrap_or_else(() => "")
    let left = if settings.labels.length() > 0 {
      left
    } else {
      header(task.left, settings.context_format, missing=missing_left)
    }
    let right = if settings.labels.length() > 1 {
      right
    } else {
      header(task.right, settings.context_format, missing=missing_right)
    }
    @stdio.stdout.write(
      unified(
        changes,
        settings.context,
        @bytere.argument(left),
        @bytere.argument(right),
        context_format=settings.context_format,
        options=settings.comparison,
      ),
    )
  } else {
    @stdio.stdout.write(normal(changes, options=settings.comparison))
  }
  1
}

///|
async fn report_types(
  task : Comparison,
  settings : DiffSettings,
  left : @fs.FileKind,
  right : @fs.FileKind,
) -> Int32 {
  let display_left = settings.labels
    .get(0)
    .unwrap_or_else(() => diagnostic_path(task.left))
  let display_right = settings.labels
    .get(1)
    .unwrap_or_else(() => diagnostic_path(task.right))
  @stdio.stdout.write(
    "File \{display_left} is \{kind_name(left)} while file \{display_right} is \{kind_name(right)}\n",
  )
  1
}

///|
async fn compare_path(
  task : Comparison,
  settings : DiffSettings,
  pending : Array[Comparison],
) -> Int32 {
  let left = if task.left_present { file_kind(task.left) } else { None }
  let right = if task.right_present { file_kind(task.right) } else { None }
  let allow_left = settings.new_file || settings.unidirectional
  let allow_right = settings.new_file
  if left is None && right is None {
    if task.left_present {
      @stdio.stderr.write(
        "diff: " + diagnostic_path(task.left) + ": No such file or directory\n",
      )
    }
    if task.right_present {
      @stdio.stderr.write(
        "diff: " + diagnostic_path(task.right) + ": No such file or directory\n",
      )
    }
    return 2
  }
  if (left is None && !allow_left) || (right is None && !allow_right) {
    if task.nested && (!task.left_present || !task.right_present) {
      let (parent, name) = path_parts(
        if !task.left_present {
          task.right
        } else {
          task.left
        },
      )
      @stdio.stdout.write(
        "Only in " +
        diagnostic_path(parent) +
        ": " +
        diagnostic_path(name) +
        "\n",
      )
      return 1
    }
    let path = if left is None { task.left } else { task.right }
    raise DiffError(diagnostic_path(path) + ": No such file or directory")
  }
  let left_kind = left.unwrap_or(
    if right == Some(Directory) {
      Directory
    } else {
      Regular
    },
  )
  let right_kind = right.unwrap_or(
    if left == Some(Directory) {
      Directory
    } else {
      Regular
    },
  )
  if task.nested && left_kind != right_kind {
    return report_types(task, settings, left_kind, right_kind)
  }
  if left_kind != Directory {
    if task.nested {
      match left_kind {
        Pipe | Socket | Unknown =>
          return report_types(task, settings, left_kind, right_kind)
        CharDevice | BlockDevice => {
          if @fs.realpath(task.left) == @fs.realpath(task.right) {
            return 0
          }
          raise DiffError(
            "unsupported capability: directory device-number comparison",
          )
        }
        _ => ()
      }
    }
    return compare_files(task, settings, left is None, right is None)
  }
  if task.nested && !settings.recursive {
    @stdio.stdout.write(
      "Common subdirectories: " +
      diagnostic_path(task.left) +
      " and " +
      diagnostic_path(task.right) +
      "\n",
    )
    return 0
  }
  let left_ancestors = task.left_ancestors.copy()
  let right_ancestors = task.right_ancestors.copy()
  if left is Some(_) {
    let real = @fs.realpath(task.left)
    if left_ancestors.contains(real) {
      raise DiffError(diagnostic_path(task.left) + ": recursive directory loop")
    }
    left_ancestors.push(real)
  }
  if right is Some(_) {
    let real = @fs.realpath(task.right)
    if right_ancestors.contains(real) {
      raise DiffError(
        diagnostic_path(task.right) + ": recursive directory loop",
      )
    }
    right_ancestors.push(real)
  }
  let names : Map[String, Int32] = Map([])
  if left is Some(_) {
    for name in @fs.readdir(task.left) {
      names[name] = 1
    }
  }
  if right is Some(_) {
    for name in @fs.readdir(task.right) {
      names[name] = names.get(name).unwrap_or(0) | 2
    }
  }
  let ordered : Array[(String, Bytes)] = names
    .keys()
    .map(name => (name, @bytere.bytes(@bytere.argument(name))))
    .collect()
  ordered.sort_by((a, b) => a.1.lexical_compare(b.1))
  for i = ordered.length() - 1; i >= 0; i = i - 1 {
    let name = ordered[i].0
    let sides = names[name]
    pending.push({
      left: join_path(task.left, name),
      right: join_path(task.right, name),
      nested: true,
      left_present: (sides & 1) != 0,
      right_present: (sides & 2) != 0,
      left_ancestors,
      right_ancestors,
    })
  }
  0
}

///|
async fn run(args : ArrayView[String]) -> Int32 {
  let normalized : Array[String] = []
  let mut options = true
  for arg in args {
    if arg == "--" {
      options = false
    }
    if options && arg.has_prefix("--unified=") {
      normalized.push("-U" + arg[10:].to_owned())
    } else if options && arg.has_prefix("--context=") {
      normalized.push("-C" + arg[10:].to_owned())
    } else {
      normalized.push(arg)
    }
  }
  let parsed = @cli.parse(normalized, [
    @cli.flag("brief", short='q'),
    @cli.flag("report-identical-files", short='s'),
    @cli.flag("text", short='a'),
    @cli.flag("unified", short='u'),
    @cli.option("unified-lines", short='U'),
    @cli.flag("context", short='c'),
    @cli.option("context-lines", short='C'),
    @cli.option("label"),
    @cli.flag("ignore-case", short='i'),
    @cli.flag("ignore-all-space", short='w'),
    @cli.flag("ignore-space-change", short='b'),
    @cli.flag("ignore-blank-lines", short='B'),
    @cli.flag("ignore-trailing-space", short='Z'),
    @cli.flag("strip-trailing-cr"),
    @cli.flag("recursive", short='r'),
    @cli.flag("new-file", short='N'),
    @cli.flag("unidirectional-new-file"),
    @cli.flag("help"),
    @cli.flag("version"),
  ])
  if parsed.contains("help") {
    @stdio.stdout.write(
      "Usage: diff [-qsauciwbBZrN] [-U LINES | -C LINES] [--label LABEL] FILE1 FILE2\n      --help      display this help and exit\n      --version   display version and exit\nCompare files, directories or one stdin operand. Normal, unified and context output.\n-q reports differences only; -s reports equality; -a treats binary input as text.\n-i ignores ASCII case; -w ignores whitespace; -b ignores changes in whitespace.\n-Z ignores trailing whitespace; -B ignores blank-only change groups.\n--strip-trailing-cr removes one CR before each LF on input, including displayed lines.\n-r recurses; -N treats missing files as empty; --unidirectional-new-file applies only to the left side.\nTimestamp headers use TZ=UTC or public TZif files; label stdin explicitly.\nNon-C locale collation and link-target-text comparison remain unsupported.\n",
    )
    return 0
  }
  if parsed.contains("version") {
    @stdio.stdout.write("diff 0.2.1\n")
    return 0
  }
  guard parsed.operands.length() == 2 else {
    fail("expected two file operands")
  }
  let names = parsed.operands
  let unified_mode = parsed.contains("unified") ||
    parsed.contains("unified-lines")
  let context_mode = parsed.contains("context") ||
    parsed.contains("context-lines")
  if unified_mode && context_mode {
    fail("conflicting output style options")
  }
  let labels = parsed.values("label")
  if labels.length() > 2 {
    fail("too many labels")
  }
  let context = @string.parse_int(
    parsed
    .last_value(if context_mode { "context-lines" } else { "unified-lines" })
    .unwrap_or("3"),
  )
  guard context >= 0 && context <= 1000000 else {
    fail("context must be between 0 and 1000000")
  }
  let settings : DiffSettings = {
    comparison: compare_options(
      ignore_case=parsed.contains("ignore-case"),
      ignore_all_space=parsed.contains("ignore-all-space"),
      ignore_space_change=parsed.contains("ignore-space-change"),
      ignore_trailing_space=parsed.contains("ignore-trailing-space"),
      strip_trailing_cr=parsed.contains("strip-trailing-cr"),
      ignore_blank_lines=parsed.contains("ignore-blank-lines"),
    ),
    brief: parsed.contains("brief"),
    report_identical: parsed.contains("report-identical-files"),
    text: parsed.contains("text"),
    unified: unified_mode,
    context_format: context_mode,
    context,
    labels,
    recursive: parsed.contains("recursive"),
    new_file: parsed.contains("new-file"),
    unidirectional: parsed.contains("unidirectional-new-file"),
    command: command_prefix(args),
  }
  let mut left = names[0]
  let mut right = names[1]
  let left_kind = file_kind(left)
  let right_kind = file_kind(right)
  if left_kind == Some(Directory) &&
    right_kind is Some(kind) &&
    kind != Directory {
    if right == "-" {
      raise DiffError("cannot compare '-' to a directory")
    }
    left = join_path(left, path_parts(right).1)
  } else if right_kind == Some(Directory) &&
    left_kind is Some(kind) &&
    kind != Directory {
    if left == "-" {
      raise DiffError("cannot compare '-' to a directory")
    }
    right = join_path(right, path_parts(left).1)
  }
  let pending : Array[Comparison] = [
    {
      left,
      right,
      nested: false,
      left_present: true,
      right_present: true,
      left_ancestors: [],
      right_ancestors: [],
    },
  ]
  let mut status = 0
  while pending.pop() is Some(task) {
    let result = compare_path(task, settings, pending) catch {
      DiffError(message) => {
        @stdio.stderr.write("diff: \{message}\n")
        2
      }
      err => {
        @stdio.stderr.write("diff: \{err}\n")
        2
      }
    }
    status = status.max(result)
  }
  status
}

///|
fn padded(value : Int32, width : Int32) -> String {
  let text = value.to_string()
  "0".repeat(Int32::max(0, width - text.length())) + text
}

///|
fn context_date(date : @time.ZonedDateTime) -> String {
  let weekday = match date.weekday() {
    Monday => "Mon"
    Tuesday => "Tue"
    Wednesday => "Wed"
    Thursday => "Thu"
    Friday => "Fri"
    Saturday => "Sat"
    Sunday => "Sun"
  }
  let month = [
      "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov",
      "Dec",
    ][date.month() - 1]
  weekday +
  " " +
  month +
  " " +
  (if date.day() < 10 { " " } else { "" }) +
  date.day().to_string() +
  " " +
  padded(date.hour(), 2) +
  ":" +
  padded(date.minute(), 2) +
  ":" +
  padded(date.second(), 2) +
  " " +
  date.year().to_string()
}

///|
async fn header(
  path : String,
  context : Bool,
  missing~ : Bool = false,
) -> String {
  if path == "-" {
    fail("unified stdin headers require an explicit --label")
  }
  let zone = @time_zone.load()
  let (seconds, nanos) = if missing { (0L, 0) } else { @fs.mtime(path) }
  let date = zone.at_unix(seconds, nanosecond=nanos)
  let name = directory_operand(path)
  if context {
    return name + "\t" + context_date(date)
  }
  let offset = date.offset().seconds()
  let magnitude = if offset < 0 { -offset } else { offset }
  name +
  "\t" +
  padded(date.year(), 4) +
  "-" +
  padded(date.month(), 2) +
  "-" +
  padded(date.day(), 2) +
  " " +
  padded(date.hour(), 2) +
  ":" +
  padded(date.minute(), 2) +
  ":" +
  padded(date.second(), 2) +
  "." +
  padded(nanos, 9) +
  " " +
  (if offset < 0 { "-" } else { "+" }) +
  padded(magnitude / 3600, 2) +
  padded(magnitude % 3600 / 60, 2)
}

///|
async fn main {
  let status = run(@env.args()[1:]) catch {
    DiffError(message) => {
      @stdio.stderr.write("diff: \{message}\n")
      2
    }
    @cli.CliError(message~, ..) => {
      @stdio.stderr.write("diff: \{message}\n")
      2
    }
    err => {
      @stdio.stderr.write("diff: \{err}\n")
      2
    }
  }
  if status != 0 {
    @sys.exit(status)
  }
}
