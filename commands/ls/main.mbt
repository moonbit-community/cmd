///|
priv enum SortMode {
  SortByName
  SortByTime
  SortBySize
} derive(Eq)

///|
priv struct LsOptions {
  all : Bool
  almost_all : Bool
  directory : Bool
  classify : Bool
  recursive : Bool
  reverse : Bool
  sort : SortMode
  time : @fsops.TimestampKind
  links : @fsops.LinkTraversal
}

///|
priv struct LsEntry {
  name : String
  path : String
  kind : @fs.FileKind
  timestamp : @fsops.FileTimestamp?
  size : Int64?
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
fn c_locale_compare(left : String, right : String) -> Int {
  let left = @utf8.encode(left)
  let right = @utf8.encode(right)
  let shared = left.length().min(right.length())
  for index = 0; index < shared; index = index + 1 {
    if left[index] < right[index] {
      return -1
    }
    if left[index] > right[index] {
      return 1
    }
  }
  if left.length() < right.length() {
    -1
  } else if left.length() > right.length() {
    1
  } else {
    0
  }
}

///|
async fn displayed_kind(
  path : String,
  links : @fsops.LinkTraversal,
  command_line : Bool,
) -> @fs.FileKind {
  let kind = @fs.kind(path, follow_symlink=false)
  if kind == SymLink &&
    (
      links == FollowAllLinks ||
      (links == FollowCommandLineLinks && command_line)
    ) {
    @fs.kind(path, follow_symlink=true) catch {
      _ => SymLink
    }
  } else {
    kind
  }
}

///|
async fn indicator(path : String, kind : @fs.FileKind) -> String {
  match kind {
    Directory => "/"
    SymLink => "@"
    Pipe => "|"
    Socket => "="
    Regular => if @fs.can_execute(path) { "*" } else { "" }
    _ => ""
  }
}

///|
async fn read_entry(
  name : String,
  path : String,
  options : LsOptions,
  command_line : Bool,
) -> LsEntry {
  let kind = displayed_kind(path, options.links, command_line)
  let follow = kind != SymLink
  let timestamp = if options.sort == SortByTime {
    Some(@fsops.read_file_timestamp(path, options.time, follow_symlink=follow))
  } else {
    None
  }
  let size = if options.sort == SortBySize {
    if kind != Regular {
      raise @fsops.FsOpError(
        "-S is limited to sets of regular files: '\{path}'",
      )
    }
    let file = @fs.open(path, mode=ReadOnly)
    defer file.close()
    Some(file.size())
  } else {
    None
  }
  { name, path, kind, timestamp, size, }
}

///|
fn compare_entries(left : LsEntry, right : LsEntry, options : LsOptions) -> Int {
  let primary = match options.sort {
    SortByName => c_locale_compare(left.name, right.name)
    SortByTime =>
      -@fsops.compare_timestamps(
        left.timestamp.unwrap(),
        right.timestamp.unwrap(),
      )
    SortBySize =>
      if left.size.unwrap() > right.size.unwrap() {
        -1
      } else if left.size.unwrap() < right.size.unwrap() {
        1
      } else {
        0
      }
  }
  let compared = if primary == 0 {
    c_locale_compare(left.name, right.name)
  } else {
    primary
  }
  if options.reverse {
    -compared
  } else {
    compared
  }
}

///|
async fn sorted_entries(path : String, options : LsOptions) -> Array[LsEntry] {
  let names = @fs.readdir(
    path,
    include_hidden=options.all || options.almost_all,
    include_special=options.all,
    sort=false,
  )
  let entries : Array[LsEntry] = []
  for name in names {
    entries.push(read_entry(name, join_path(path, name), options, false))
  }
  entries.sort_by((left, right) => compare_entries(left, right, options))
  entries
}

///|
async fn print_operand(path : String, options : LsOptions) -> Unit {
  let entry = read_entry(path, path, options, true)
  let suffix = if options.classify { indicator(path, entry.kind) } else { "" }
  @stdio.stdout.write(path + suffix + "\n")
}

///|
async fn print_directory(
  path : String,
  options : LsOptions,
  show_header : Bool,
  printed_section : Ref[Bool],
) -> Array[String] {
  if show_header {
    if printed_section.val {
      @stdio.stdout.write("\n")
    }
    @stdio.stdout.write(path + ":\n")
  }
  printed_section.val = true
  let entries = sorted_entries(path, options)
  let child_dirs : Array[String] = []
  for entry in entries {
    let suffix = if options.classify {
      indicator(entry.path, entry.kind)
    } else {
      ""
    }
    @stdio.stdout.write(entry.name + suffix + "\n")
    if options.recursive &&
      entry.kind == Directory &&
      entry.name != "." &&
      entry.name != ".." {
      child_dirs.push(entry.path)
    }
  }
  child_dirs
}

///|
fn parse_time(value : String) -> @fsops.TimestampKind raise @cli.CliError {
  match value {
    "atime" | "access" | "use" => AccessTime
    "ctime" | "status" => StatusChangeTime
    "mtime" | "modification" => ModificationTime
    _ =>
      raise @cli.CliError(
        kind=InvalidValue,
        option="time",
        message="invalid time selector",
      )
  }
}

///|
async fn main {
  let args = @env.args()[1:]
  let parsed = @cli.parse(args, [
    @cli.flag("all", short='a'),
    @cli.flag("almost-all", short='A'),
    @cli.flag("directory", short='d'),
    @cli.flag("classify", short='F'),
    @cli.flag("recursive", short='R'),
    @cli.flag("one", short='1'),
    @cli.flag("sort-time", short='t'),
    @cli.flag("access-time", short='u'),
    @cli.flag("change-time", short='c'),
    @cli.flag("reverse", short='r'),
    @cli.flag("sort-size", short='S'),
    @cli.flag("dereference-command-line", short='H'),
    @cli.flag("dereference", short='L'),
    @cli.flag("no-dereference", short='P'),
    @cli.option("time"),
    @cli.flag("help"),
  ]) catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.write("ls: \{message}: '\{option}'\n")
      @sys.exit(2)
      return
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.write(
      "Usage: ls [-aAdF1RrtucS] [-H|-L|-P] [--time=WORD] [FILE...]\n",
    )
    return
  }
  let selected_time = match
    parsed.last_occurrence(["access-time", "change-time", "time"]) {
    Some("access-time") => @fsops.TimestampKind::AccessTime
    Some("change-time") => @fsops.TimestampKind::StatusChangeTime
    Some("time") =>
      parse_time(parsed.last_value("time").unwrap()) catch {
        @cli.CliError(option~, message~, ..) => {
          @stdio.stderr.write("ls: \{message}: '\{option}'\n")
          @sys.exit(2)
          return
        }
      }
    _ => @fsops.TimestampKind::ModificationTime
  }
  let links = match
    parsed.last_occurrence([
      "dereference-command-line", "dereference", "no-dereference",
    ]) {
    Some("dereference") => @fsops.LinkTraversal::FollowAllLinks
    Some("no-dereference") => @fsops.LinkTraversal::NeverFollowLinks
    _ => @fsops.LinkTraversal::NeverFollowLinks
  }
  let sort = match parsed.last_occurrence(["sort-time", "sort-size"]) {
    Some("sort-time") => SortByTime
    Some("sort-size") => SortBySize
    _ => SortByName
  }
  let options : LsOptions = {
    all: parsed.contains("all"),
    almost_all: parsed.contains("almost-all"),
    directory: parsed.contains("directory"),
    classify: parsed.contains("classify"),
    recursive: parsed.contains("recursive"),
    reverse: parsed.contains("reverse"),
    sort,
    time: selected_time,
    links,
  }
  let operands = parsed.operands
  let paths = if operands.is_empty() { ["."] } else { operands }
  let mut failed = false
  let directories : Array[String] = []
  for path in paths {
    let kind = displayed_kind(path, options.links, true) catch {
      err => {
        @stdio.stderr.write("ls: cannot access '\{path}': \{err}\n")
        failed = true
        continue
      }
    }
    if kind == Directory && !options.directory {
      directories.push(path)
    } else {
      print_operand(path, options) catch {
        err => {
          @stdio.stderr.write("ls: cannot access '\{path}': \{err}\n")
          failed = true
        }
      }
    }
  }
  let printed_section = Ref(false)
  let show_top_header = paths.length() > 1 || options.recursive
  for directory in directories {
    let pending : Array[(String, Array[String])] = [(directory, [])]
    let mut first = true
    while pending.pop() is Some((path, ancestors)) {
      let real = @fs.realpath(path) catch {
        err => {
          @stdio.stderr.write("ls: cannot resolve '\{path}': \{err}\n")
          failed = true
          continue
        }
      }
      if ancestors.contains(real) {
        @stdio.stderr.write("ls: recursive symbolic-link cycle at '\{path}'\n")
        failed = true
        continue
      }
      let next_ancestors = ancestors.copy()
      next_ancestors.push(real)
      let children = print_directory(
        path,
        options,
        show_top_header || !first,
        printed_section,
      ) catch {
        err => {
          @stdio.stderr.write("ls: cannot open '\{path}': \{err}\n")
          failed = true
          first = false
          continue
        }
      }
      let mut index = children.length()
      while index > 0 {
        index -= 1
        pending.push((children[index], next_ancestors.copy()))
      }
      first = false
      if !options.recursive {
        pending.clear()
      }
    }
  }
  if failed {
    @sys.exit(1)
  }
}
