///|
async fn source(path : String) -> Bytes {
  if path == "-" {
    @stdio.stdin.read_all().binary()
  } else {
    @fs.read_file(path).binary()
  }
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
    @cli.flag("help"),
    @cli.flag("version"),
  ])
  if parsed.contains("help") {
    @stdio.stdout.write(
      "Usage: diff [-qsauc] [-U LINES | -C LINES] [--label LABEL] FILE1 FILE2\n      --help      display this help and exit\n      --version   display version and exit\nCompare regular files or one stdin operand. Normal, unified and context output.\n-q reports differences only; -s reports equality; -a treats binary input as text.\nTimestamp headers use TZ=UTC or public TZif files; label stdin explicitly.\nDirectory recursion and whitespace/locale options are unsupported.\n",
    )
    return 0
  }
  if parsed.contains("version") {
    @stdio.stdout.write("diff 0.1.3\n")
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
  let a = source(names[0])
  let b = if names[0] == names[1] { a } else { source(names[1]) }
  let display_left = labels.get(0).unwrap_or(names[0])
  let display_right = labels.get(1).unwrap_or(names[1])
  if a == b {
    if parsed.contains("report-identical-files") {
      @stdio.stdout.write(
        "Files \{display_left} and \{display_right} are identical\n",
      )
    }
    return 0
  }
  if parsed.contains("brief") {
    @stdio.stdout.write("Files \{display_left} and \{display_right} differ\n")
    return 1
  }
  if !parsed.contains("text") &&
    (a.iter().any(v => v == b'\x00') || b.iter().any(v => v == b'\x00')) {
    @stdio.stdout.write(
      "Binary files \{display_left} and \{display_right} differ\n",
    )
    return 1
  }
  let changes = edits(lines(a), lines(b))
  if unified_mode || context_mode {
    let left = if labels.length() > 0 {
      labels[0]
    } else {
      header(names[0], context_mode)
    }
    let right = if labels.length() > 1 {
      labels[1]
    } else {
      header(names[1], context_mode)
    }
    @stdio.stdout.write(
      unified(
        changes,
        context,
        @bytere.argument(left),
        @bytere.argument(right),
        context_format=context_mode,
      ),
    )
  } else {
    @stdio.stdout.write(normal(changes))
  }
  1
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
async fn header(path : String, context : Bool) -> String {
  if path == "-" {
    fail("unified stdin headers require an explicit --label")
  }
  let zone = @time_zone.load()
  let (seconds, nanos) = @fs.mtime(path)
  let date = zone.at_unix(seconds, nanosecond=nanos)
  if context {
    return path + "\t" + context_date(date)
  }
  let offset = date.offset().seconds()
  let magnitude = if offset < 0 { -offset } else { offset }
  path +
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
