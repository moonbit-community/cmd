///|
priv enum SortMode {
  SortByName
  SortByTime
  SortBySize
} derive(Eq)

///|
priv enum LinkMode {
  NeverFollowLinks
  FollowCommandLineDirectories
  FollowCommandLineLinks
  FollowAllLinks
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
  links : LinkMode
}

///|
priv struct LsEntry {
  name : String
  path : String
  kind : @fs.FileKind?
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
  links : LinkMode,
  command_line : Bool,
) -> @fs.FileKind {
  let kind = @fs.kind(path, follow_symlink=false)
  if kind == SymLink {
    if links == FollowAllLinks ||
      (links == FollowCommandLineLinks && command_line) {
      // Explicit dereferencing must report dangling links and access failures.
      return @fs.kind(path, follow_symlink=true)
    }
    if links == FollowCommandLineDirectories && command_line {
      let target = @fs.kind(path, follow_symlink=true) catch {
        @os_error.OSError(_) as error if error.is_ENOENT() ||
          is_symlink_loop(error) => SymLink
        error => raise error
      }
      return if target == Directory { Directory } else { SymLink }
    }
  }
  kind
}

///|
fn is_symlink_loop(error : @os_error.OSError) -> Bool {
  match (@async.platform, error) {
    (Linux, @os_error.OSError(40, ..)) | (MacOS, @os_error.OSError(62, ..)) =>
      true
    _ => false
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
  let size = if options.sort == SortBySize &&
    !(kind == Directory && command_line && !options.directory) {
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
  { name, path, kind: Some(kind), timestamp, size, }
}

///|
fn compare_entries(left : LsEntry, right : LsEntry, options : LsOptions) -> Int {
  let primary = match options.sort {
    SortByName => c_locale_compare(left.name, right.name)
    SortByTime =>
      match (left.timestamp, right.timestamp) {
        (Some(left), Some(right)) => -@fsops.compare_timestamps(left, right)
        (Some(_), None) => -1
        (None, Some(_)) => 1
        (None, None) => 0
      }
    SortBySize =>
      if left.size.unwrap_or(-1L) > right.size.unwrap_or(-1L) {
        -1
      } else if left.size.unwrap_or(-1L) < right.size.unwrap_or(-1L) {
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
async fn sorted_entries(
  path : String,
  options : LsOptions,
  status : Ref[Int],
) -> Array[LsEntry] {
  let names = @fs.readdir(
    path,
    include_hidden=options.all || options.almost_all,
    include_special=options.all,
    sort=false,
  )
  let entries : Array[LsEntry] = []
  for name in names {
    let full_path = join_path(path, name)
    let entry = read_entry(name, full_path, options, false) catch {
      @fsops.FsOpError(_) as error => raise error
      error => {
        @stdio.stderr.write("ls: cannot access '\{full_path}': \{error}\n")
        status.val = status.val.max(1)
        let fallback_kind = try
          @fs.kind(full_path, follow_symlink=false)
        catch {
          _ => None
        } noraise {
          kind => Some(kind)
        }
        {
          name,
          path: full_path,
          kind: fallback_kind,
          timestamp: None,
          size: None,
        }
      }
    }
    entries.push(entry)
  }
  entries.sort_by((left, right) => compare_entries(left, right, options))
  entries
}

///|
async fn print_entry(entry : LsEntry, options : LsOptions) -> Unit {
  let suffix = match entry.kind {
    Some(kind) if options.classify => indicator(entry.path, kind)
    _ => ""
  }
  @stdio.stdout.write(entry.name + suffix + "\n")
}

///|
async fn print_directory(
  path : String,
  options : LsOptions,
  show_header : Bool,
  printed_section : Ref[Bool],
  status : Ref[Int],
) -> Array[String] {
  if show_header {
    if printed_section.val {
      @stdio.stdout.write("\n")
    }
    @stdio.stdout.write(path + ":\n")
  }
  printed_section.val = true
  let entries = sorted_entries(path, options, status)
  let child_dirs : Array[String] = []
  for entry in entries {
    print_entry(entry, options)
    if options.recursive &&
      entry.kind == Some(Directory) &&
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
fn parse_arguments(
  args : ArrayView[String],
) -> @cli.ParsedArgs raise @cli.CliError {
  @cli.parse(args, [
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
  ])
}

///|
fn ls_options(parsed : @cli.ParsedArgs) -> LsOptions raise @cli.CliError {
  let selected_time = match
    parsed.last_occurrence(["access-time", "change-time", "time"]) {
    Some("access-time") => @fsops.TimestampKind::AccessTime
    Some("change-time") => @fsops.TimestampKind::StatusChangeTime
    Some("time") => parse_time(parsed.last_value("time").unwrap())
    _ => @fsops.TimestampKind::ModificationTime
  }
  let links = match
    parsed.last_occurrence([
      "dereference-command-line", "dereference", "no-dereference",
    ]) {
    Some("dereference") => FollowAllLinks
    Some("dereference-command-line") => FollowCommandLineLinks
    Some("no-dereference") => NeverFollowLinks
    _ =>
      if parsed.contains("directory") || parsed.contains("classify") {
        NeverFollowLinks
      } else {
        FollowCommandLineDirectories
      }
  }
  let sort = match parsed.last_occurrence(["sort-time", "sort-size"]) {
    Some("sort-time") => SortByTime
    Some("sort-size") => SortBySize
    _ =>
      if parsed.last_occurrence(["access-time", "change-time", "time"])
        is Some(_) {
        SortByTime
      } else {
        SortByName
      }
  }
  {
    all: parsed.last_occurrence(["all", "almost-all"]) == Some("all"),
    almost_all: parsed.contains("almost-all"),
    directory: parsed.contains("directory"),
    classify: parsed.contains("classify"),
    recursive: parsed.contains("recursive"),
    reverse: parsed.contains("reverse"),
    sort,
    time: selected_time,
    links,
  }
}

///|
async fn main {
  let parsed = parse_arguments(@env.args()[1:]) catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.write("ls: \{message}: '\{option}'\n")
      @sys.exit(2)
      return
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.write(
      "Usage: ls [-aAdF1RrtucS] [-H|-L|-P] [--time=WORD] [FILE...]\n  -H follows command-line links; -L follows all links; -P follows none (extension).\n  -u, -c and --time select and imply time sorting unless -S or -t selects a sort.\n  -S requires regular files; metadata-rich long listing is not supported.\n",
    )
    return
  }
  let options = ls_options(parsed) catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.write("ls: \{message}: '\{option}'\n")
      @sys.exit(2)
      return
    }
  }
  let operands = parsed.operands
  let paths = if operands.is_empty() { ["."] } else { operands }
  let status = Ref(0)
  let directories : Array[LsEntry] = []
  let files : Array[LsEntry] = []
  for path in paths {
    let entry = read_entry(path, path, options, true) catch {
      err => {
        @stdio.stderr.write("ls: cannot access '\{path}': \{err}\n")
        status.val = 2
        continue
      }
    }
    if entry.kind == Some(Directory) && !options.directory {
      directories.push(entry)
    } else {
      files.push(entry)
    }
  }
  files.sort_by((left, right) => compare_entries(left, right, options))
  if options.sort == SortBySize && directories.length() > 1 {
    @stdio.stderr.write(
      "ls: -S cannot sort multiple directory operands without directory size metadata\n",
    )
    @sys.exit(2)
    return
  }
  directories.sort_by((left, right) => compare_entries(left, right, options))
  for entry in files {
    print_entry(entry, options)
  }
  let printed_section = Ref(!files.is_empty())
  let show_top_header = paths.length() > 1 || options.recursive
  for directory in directories {
    let pending : Array[(String, Array[String])] = [(directory.path, [])]
    let mut first = true
    while pending.pop() is Some((path, ancestors)) {
      let real = @fs.realpath(path) catch {
        err => {
          @stdio.stderr.write("ls: cannot resolve '\{path}': \{err}\n")
          status.val = 2
          continue
        }
      }
      if ancestors.contains(real) {
        @stdio.stderr.write("ls: recursive symbolic-link cycle at '\{path}'\n")
        status.val = 2
        continue
      }
      let next_ancestors = ancestors.copy()
      next_ancestors.push(real)
      let children = print_directory(
        path,
        options,
        show_top_header || !first,
        printed_section,
        status,
      ) catch {
        err => {
          @stdio.stderr.write("ls: cannot open '\{path}': \{err}\n")
          status.val = 2
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
  if status.val != 0 {
    @sys.exit(status.val)
  }
}
