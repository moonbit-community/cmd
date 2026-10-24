///|
priv enum BinaryMode {
  Report
  Text
  WithoutMatch
} derive(Eq)

///|
priv struct GrepOptions {
  fixed : Bool
  extended : Bool
  only_matching : Bool
  ignore_case : Bool
  invert : Bool
  line_number : Bool
  byte_offset : Bool
  count : Bool
  files_with_matches : Bool
  files_without_match : Bool
  quiet : Bool
  force_filename : Bool
  no_filename : Bool
  whole_line : Bool
  word : Bool
  recursive : Bool
  suppress_messages : Bool
  zero_terminated : Bool
  before_context : Int32
  after_context : Int32
  context_enabled : Bool
  binary_mode : BinaryMode
}

///|
priv enum Matcher {
  Fixed(Array[Bytes], Bool, Bool)
  Regular(Array[@bytere.Pattern], Bool, Bool)
}

///|
priv suberror GrepError {
  GrepError(String)
}

///|
priv struct Record {
  data : BytesView
  terminated : Bool
  number : Int64
  offset : Int64
}

///|
fn split_lines(text : String) -> Array[String] {
  let lines : Array[String] = text.split("\n").map(v => v.to_owned()).collect()
  if text.has_suffix("\n") {
    ignore(lines.pop())
  }
  lines
}

///|
fn bytes_as_string(bytes : BytesView) -> String {
  let output = StringBuilder(size_hint=bytes.length())
  for byte in bytes {
    output.write_char(byte.to_int().unsafe_to_char())
  }
  output.to_string()
}

///|
fn compile_matcher(
  patterns : Array[String],
  options : GrepOptions,
) -> Matcher raise {
  if options.fixed {
    let literals = patterns.map(text => {
      let bytes = @utf8.encode(text)
      if options.ignore_case {
        folded_bytes(bytes[:])
      } else {
        bytes
      }
    })
    return Fixed(literals, options.whole_line, options.word)
  }
  let compiled : Array[@bytere.Pattern] = []
  for pattern in patterns {
    compiled.push(
      @bytere.compile(
        bytes_as_string(@utf8.encode(pattern)),
        extended=options.extended,
        grep_syntax=true,
        ignore_case=options.ignore_case,
      ),
    )
  }
  Regular(compiled, options.whole_line, options.word)
}

///|
async fn read_text(path : String) -> String {
  if path == "-" {
    @stdio.stdin.read_all().text()
  } else {
    @fs.read_file(path).text()
  }
}

///|
fn join_path(parent : String, name : String) -> String {
  @path.Path(parent).join(Path(name)).to_string()
}

///|
fn glob_matches(pattern : Bytes, name : Bytes, pi : Int32, ni : Int32) -> Bool {
  if pi == pattern.length() {
    return ni == name.length()
  }
  if pattern[pi] is b'*' {
    let mut next = pi + 1
    while next < pattern.length() && pattern[next] is b'*' {
      next += 1
    }
    if next == pattern.length() {
      return true
    }
    for index in ni..<=name.length() {
      if glob_matches(pattern, name, next, index) {
        return true
      }
    }
    return false
  }
  if ni == name.length() {
    return false
  }
  if pattern[pi] is b'?' || pattern[pi] == name[ni] {
    return glob_matches(pattern, name, pi + 1, ni + 1)
  }
  false
}

///|
fn selected_by_globs(
  path : String,
  includes : Array[String],
  excludes : Array[String],
) -> Bool {
  let name = @utf8.encode(@path.Path(path).basename().to_owned())
  let included = includes.is_empty() ||
    includes.any(pattern => glob_matches(@utf8.encode(pattern), name, 0, 0))
  included &&
  !excludes.any(pattern => glob_matches(@utf8.encode(pattern), name, 0, 0))
}

///|
async fn collect_files(
  root : String,
  includes : Array[String],
  excludes : Array[String],
) -> Array[String] {
  let result : Array[String] = []
  let stack : Array[String] = [root]
  while stack.pop() is Some(path) {
    let kind = @fs.kind(path, follow_symlink=false)
    if kind == Directory {
      let entries = @fs.readdir(path, include_hidden=true, sort=false)
      entries.sort_by((left, right) => left.lexical_compare(right))
      let mut index = entries.length()
      while index > 0 {
        index -= 1
        stack.push(join_path(path, entries[index]))
      }
    } else if kind == Regular && selected_by_globs(path, includes, excludes) {
      result.push(path)
    }
  }
  result
}

///|
fn parse_context(value : String) -> Int32 raise GrepError {
  let count = @string.parse_int(value) catch {
    _ => raise GrepError("grep: invalid context length argument: '\{value}'")
  }
  if count < 0 {
    raise GrepError("grep: invalid context length argument: '\{value}'")
  }
  count
}

///|
async fn write_record(
  record : Record,
  path : String,
  options : GrepOptions,
  prefix_filename : Bool,
  selected : Bool,
  output : &@io.Writer,
) -> Unit {
  if prefix_filename || options.line_number || options.byte_offset {
    let separator = if selected { ':' } else { '-' }
    let prefix = StringBuilder()
    if prefix_filename {
      prefix.write_string(path)
      prefix.write_char(separator)
    }
    if options.line_number {
      prefix.write_string(record.number.to_string())
      prefix.write_char(separator)
    }
    if options.byte_offset {
      prefix.write_string(record.offset.to_string())
      prefix.write_char(separator)
    }
    output.write(prefix.to_string())
  }
  if record.terminated {
    let start = record.data.start_offset()
    output.write(record.data.data()[start:start + record.data.length() + 1])
  } else {
    output.write(record.data)
    output.write(if options.zero_terminated { b"\x00" } else { b"\n" })
  }
}

///|
async fn process_source(
  path : String,
  matcher : Matcher,
  options : GrepOptions,
  prefix_filename : Bool,
) -> Bool {
  if path == "-" {
    process_reader(@stdio.stdin, path, matcher, options, prefix_filename)
  } else {
    let file = @fs.open(path, mode=ReadOnly)
    defer file.close()
    process_reader(file, path, matcher, options, prefix_filename)
  }
}

///|
async fn main {
  let args = @env.args()[1:]
  if args.length() == 1 && args[0] == "--version" {
    @stdio.stdout.write("grep 0.3.0\n")
    return
  }
  let parsed = @cli.parse(args, [
    @cli.flag("fixed-strings", short='F'),
    @cli.flag("extended-regexp", short='E'),
    @cli.flag("basic-regexp", short='G'),
    @cli.flag("only-matching", short='o'),
    @cli.flag("ignore-case", short='i'),
    @cli.flag("invert-match", short='v'),
    @cli.flag("line-number", short='n'),
    @cli.flag("byte-offset", short='b'),
    @cli.flag("count", short='c'),
    @cli.flag("files-with-matches", short='l'),
    @cli.flag("files-without-match", short='L'),
    @cli.flag("quiet", short='q'),
    @cli.flag("with-filename", short='H'),
    @cli.flag("no-filename", short='h'),
    @cli.flag("line-regexp", short='x'),
    @cli.flag("word-regexp", short='w'),
    @cli.flag("recursive", short='r'),
    @cli.flag("recursive", short='R'),
    @cli.flag("no-messages", short='s'),
    @cli.flag("null-data", short='z'),
    @cli.flag("text", short='a'),
    @cli.option("after-context", short='A'),
    @cli.option("before-context", short='B'),
    @cli.option("context", short='C'),
    @cli.option("include"),
    @cli.option("exclude"),
    @cli.option("binary-files"),
    @cli.option("regexp", short='e'),
    @cli.option("file", short='f'),
    @cli.flag("help"),
  ]) catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.write("grep: \{message}: '\{option}'\n")
      @sys.exit(2)
      return
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.write(
      "Usage: grep [-EFGivnclLqHhxwrbszo] [-A NUM] [-B NUM] [-C NUM] [--include=GLOB] [--exclude=GLOB] [--binary-files=TYPE] [-e PATTERN] [-f FILE] [PATTERN] [FILE...]\n      --help      display this help and exit\n      --version   display version and exit\n",
    )
    return
  }
  let (before_context, after_context) = try {
    let before = match parsed.last_occurrence(["before-context", "context"]) {
      Some("before-context") =>
        parse_context(parsed.last_value("before-context").unwrap())
      Some(_) => parse_context(parsed.last_value("context").unwrap())
      None => 0
    }
    let after = match parsed.last_occurrence(["after-context", "context"]) {
      Some("after-context") =>
        parse_context(parsed.last_value("after-context").unwrap())
      Some(_) => parse_context(parsed.last_value("context").unwrap())
      None => 0
    }
    (before, after)
  } catch {
    GrepError(message) => {
      @stdio.stderr.write(message + "\n")
      @sys.exit(2)
      return
    }
  }
  let binary_mode = if parsed.last_occurrence(["binary-files", "text"]) ==
    Some("text") {
    Text
  } else {
    match parsed.last_value("binary-files") {
      None | Some("binary") => Report
      Some("text") => Text
      Some("without-match") => WithoutMatch
      Some(value) => {
        @stdio.stderr.write("grep: unknown binary-files type '\{value}'\n")
        @sys.exit(2)
        return
      }
    }
  }
  let options : GrepOptions = {
    fixed: parsed.last_occurrence([
      "fixed-strings", "extended-regexp", "basic-regexp",
    ]) ==
    Some("fixed-strings"),
    extended: parsed.last_occurrence([
      "fixed-strings", "extended-regexp", "basic-regexp",
    ]) ==
    Some("extended-regexp"),
    only_matching: parsed.contains("only-matching"),
    ignore_case: parsed.contains("ignore-case"),
    invert: parsed.contains("invert-match"),
    line_number: parsed.contains("line-number"),
    byte_offset: parsed.contains("byte-offset"),
    count: parsed.contains("count"),
    files_with_matches: parsed.contains("files-with-matches"),
    files_without_match: parsed.contains("files-without-match"),
    quiet: parsed.contains("quiet"),
    force_filename: parsed.contains("with-filename"),
    no_filename: parsed.contains("no-filename"),
    whole_line: parsed.contains("line-regexp"),
    word: parsed.contains("word-regexp"),
    recursive: parsed.contains("recursive"),
    suppress_messages: parsed.contains("no-messages"),
    zero_terminated: parsed.contains("null-data"),
    before_context,
    after_context,
    context_enabled: parsed.contains("before-context") ||
    parsed.contains("after-context") ||
    parsed.contains("context"),
    binary_mode,
  }
  let patterns = parsed.values("regexp")
  let pattern_files = parsed.values("file")
  let files = parsed.operands
  if patterns.is_empty() && pattern_files.is_empty() {
    if files.is_empty() {
      @stdio.stderr.write("grep: missing pattern\n")
      @sys.exit(2)
      return
    }
    patterns.push(files.remove(0))
  }
  for pattern_file in pattern_files {
    let text = read_text(pattern_file) catch {
      err => {
        if !options.suppress_messages {
          @stdio.stderr.write("grep: '\{pattern_file}': \{err}\n")
        }
        @sys.exit(2)
        return
      }
    }
    patterns.append(split_lines(text))
  }
  let matcher = compile_matcher(patterns, options) catch {
    @bytere.PatternError(message) => {
      @stdio.stderr.write("grep: invalid regular expression: \{message}\n")
      @sys.exit(2)
      return
    }
    err => {
      @stdio.stderr.write("grep: invalid regular expression: \{err}\n")
      @sys.exit(2)
      return
    }
  }
  let operands = if files.is_empty() { ["-"] } else { files }
  let sources : Array[String] = []
  let mut failed = false
  for operand in operands {
    if options.recursive && operand != "-" {
      let found = collect_files(
        operand,
        parsed.values("include"),
        parsed.values("exclude"),
      ) catch {
        err => {
          if !options.suppress_messages {
            @stdio.stderr.write("grep: '\{operand}': \{err}\n")
          }
          failed = true
          continue
        }
      }
      sources.append(found)
    } else {
      sources.push(operand)
    }
  }
  let prefix = (
      sources.length() > 1 || options.force_filename || options.recursive
    ) &&
    !options.no_filename
  let mut matched_any = false
  for source in sources {
    let matched = process_source(source, matcher, options, prefix) catch {
      err => {
        if !options.suppress_messages {
          @stdio.stderr.write("grep: '\{source}': \{err}\n")
        }
        failed = true
        continue
      }
    }
    if matched {
      matched_any = true
      if options.quiet {
        return
      }
    }
  }
  if failed {
    @sys.exit(2)
  } else if !matched_any {
    @sys.exit(1)
  }
}
