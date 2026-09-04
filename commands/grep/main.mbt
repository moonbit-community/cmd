///|
priv enum BinaryMode {
  Report
  Text
  WithoutMatch
} derive(Eq)

///|
priv struct GrepOptions {
  fixed : Bool
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
  before_context : Int
  after_context : Int
  binary_mode : BinaryMode
}

///|
priv enum Matcher {
  Fixed(Array[String], Bool, Bool)
  Regular(Regex?)
}

///|
priv suberror GrepError {
  GrepError(String)
}

///|
priv struct Record {
  data : Bytes
  number : Int
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
fn split_records(data : Bytes, delimiter : Byte) -> Array[Record] {
  let records : Array[Record] = []
  let mut start = 0
  let mut number = 1
  for index, byte in data {
    if byte == delimiter {
      records.push({
        data: data[start:index].to_owned(),
        number,
        offset: start.to_int64(),
      })
      number += 1
      start = index + 1
    }
  }
  if start < data.length() {
    records.push({
      data: data[start:].to_owned(),
      number,
      offset: start.to_int64(),
    })
  }
  records
}

///|
fn is_word_char(c : Char) -> Bool {
  c == '_' || c is ('a'..='z' | 'A'..='Z' | '0'..='9')
}

///|
fn bytes_as_string(bytes : Bytes) -> String {
  let output = StringBuilder()
  for byte in bytes {
    output.write_char(byte.to_int().to_char().unwrap())
  }
  output.to_string()
}

///|
fn ascii_lower(text : String) -> String {
  let output = StringBuilder()
  for char in text {
    output.write_char(char.to_ascii_lowercase())
  }
  output.to_string()
}

///|
fn fixed_word_match(line : String, needle : String) -> Bool {
  if needle == "" {
    return false
  }
  let haystack : Array[Char] = line.iter().collect()
  let wanted : Array[Char] = needle.iter().collect()
  if wanted.length() > haystack.length() {
    return false
  }
  for start in 0..<=(haystack.length() - wanted.length()) {
    let mut equal = true
    for offset in 0..<wanted.length() {
      if haystack[start + offset] != wanted[offset] {
        equal = false
        break
      }
    }
    if equal {
      let left_ok = start == 0 || !is_word_char(haystack[start - 1])
      let end = start + wanted.length()
      let right_ok = end == haystack.length() || !is_word_char(haystack[end])
      if left_ok && right_ok {
        return true
      }
    }
  }
  false
}

///|
fn Matcher::matches(
  self : Matcher,
  original : String,
  ignore_case : Bool,
) -> Bool {
  let line = if ignore_case { ascii_lower(original) } else { original }
  match self {
    Fixed(patterns, whole_line, word) => {
      for pattern in patterns {
        if whole_line {
          if line == pattern {
            return true
          }
        } else if word {
          if fixed_word_match(line, pattern) {
            return true
          }
        } else if line.contains(pattern) {
          return true
        }
      }
      false
    }
    Regular(Some(regex)) => regex.execute(line) is Some(_)
    Regular(None) => false
  }
}

///|
fn compile_matcher(
  patterns : Array[String],
  options : GrepOptions,
) -> Matcher raise {
  let normalized = patterns.map(value => {
    let byte_pattern = bytes_as_string(@utf8.encode(value))
    if options.ignore_case {
      ascii_lower(byte_pattern)
    } else {
      byte_pattern
    }
  })
  if options.fixed {
    return Fixed(normalized, options.whole_line, options.word)
  }
  if normalized.is_empty() {
    return Regular(None)
  }
  let wrapped : Array[String] = []
  for pattern in normalized {
    let value = if options.whole_line {
      "^(?:\{pattern})$"
    } else if options.word {
      "(?:^|[^A-Za-z0-9_])(?:\{pattern})(?:$|[^A-Za-z0-9_])"
    } else {
      "(?:\{pattern})"
    }
    wrapped.push(value)
  }
  Regular(Some(Regex(wrapped.join("|"))))
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
async fn read_bytes(path : String) -> Bytes {
  if path == "-" {
    @stdio.stdin.read_all().binary()
  } else {
    @fs.read_file(path).binary()
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
fn glob_matches(pattern : Bytes, name : Bytes, pi : Int, ni : Int) -> Bool {
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
fn parse_context(value : String) -> Int raise GrepError {
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
) -> Unit {
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
  @stdio.stdout.write(prefix.to_string())
  @stdio.stdout.write(record.data)
  @stdio.stdout.write(if options.zero_terminated { b"\x00" } else { b"\n" })
}

///|
async fn process_source(
  path : String,
  matcher : Matcher,
  options : GrepOptions,
  prefix_filename : Bool,
) -> Bool {
  let data = read_bytes(path)
  let binary = !options.zero_terminated &&
    data.iter().any(byte => byte is b'\x00')
  if binary && options.binary_mode == WithoutMatch {
    if options.count {
      let prefix = if prefix_filename { path + ":" } else { "" }
      @stdio.stdout.write("\{prefix}0\n")
    } else if options.files_without_match {
      @stdio.stdout.write(path + "\n")
    }
    return options.files_without_match
  }
  let delimiter : Byte = if options.zero_terminated { b'\x00' } else { b'\n' }
  let records = split_records(data, delimiter)
  let selected : Array[Bool] = []
  let mut selected_count = 0
  for record in records {
    let matched = matcher.matches(
      bytes_as_string(record.data),
      options.ignore_case,
    )
    let keep = if options.invert { !matched } else { matched }
    selected.push(keep)
    if keep {
      selected_count += 1
      if options.quiet {
        return true
      }
    }
  }
  if options.count {
    let prefix = if prefix_filename { path + ":" } else { "" }
    @stdio.stdout.write("\{prefix}\{selected_count}\n")
  } else if options.files_with_matches && selected_count > 0 {
    @stdio.stdout.write(path + "\n")
  } else if options.files_without_match && selected_count == 0 {
    @stdio.stdout.write(path + "\n")
  } else if !options.files_with_matches &&
    !options.files_without_match &&
    selected_count > 0 {
    if binary && options.binary_mode == Report {
      let name = if path == "-" { "(standard input)" } else { path }
      @stdio.stdout.write("Binary file \{name} matches\n")
    } else {
      let mut emitted_through = -1
      for index in 0..<records.length() {
        if selected[index] {
          let start = Int::max(0, index - options.before_context)
          let end = Int::min(
            records.length() - 1,
            index + options.after_context,
          )
          if emitted_through >= 0 && start > emitted_through + 1 {
            @stdio.stdout.write("--\n")
          }
          for output_index in Int::max(start, emitted_through + 1)..<=end {
            write_record(
              records[output_index],
              path,
              options,
              prefix_filename,
              selected[output_index],
            )
          }
          emitted_through = Int::max(emitted_through, end)
        }
      }
    }
  }
  if options.files_without_match {
    selected_count == 0
  } else {
    selected_count > 0
  }
}

///|
async fn main {
  let args = @env.args()[1:]
  let parsed = @cli.parse(args, [
    @cli.flag("fixed-strings", short='F'),
    @cli.flag("extended-regexp", short='E'),
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
      "Usage: grep [-EFivnclLqHhxwrbsz] [-A NUM] [-B NUM] [-C NUM] [--include=GLOB] [--exclude=GLOB] [--binary-files=TYPE] [-e PATTERN] [-f FILE] [PATTERN] [FILE...]\n",
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
    fixed: parsed.last_occurrence(["fixed-strings", "extended-regexp"]) ==
    Some("fixed-strings"),
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
