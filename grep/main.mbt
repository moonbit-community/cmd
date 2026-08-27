///|
priv struct GrepOptions {
  mut fixed : Bool
  mut ignore_case : Bool
  mut invert : Bool
  mut line_number : Bool
  mut count : Bool
  mut files_with_matches : Bool
  mut files_without_match : Bool
  mut quiet : Bool
  mut force_filename : Bool
  mut no_filename : Bool
  mut whole_line : Bool
  mut word : Bool
  mut recursive : Bool
}

///|
priv enum Matcher {
  Fixed(Array[String], Bool, Bool)
  Regular(Regex?)
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
fn is_word_char(c : Char) -> Bool {
  c == '_' || c is ('a'..='z' | 'A'..='Z' | '0'..='9')
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
  let line = if ignore_case { original.to_lower() } else { original }
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
  let normalized = if options.ignore_case {
    patterns.map(value => value.to_lower())
  } else {
    patterns
  }
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
fn join_path(parent : String, name : String) -> String {
  if parent == "/" {
    "/" + name
  } else {
    parent + "/" + name
  }
}

///|
async fn collect_files(root : String) -> Array[String] {
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
    } else if kind == Regular {
      result.push(path)
    }
  }
  result
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
async fn process_reader(
  reader : &@io.Reader,
  path : String,
  matcher : Matcher,
  options : GrepOptions,
  prefix_filename : Bool,
) -> Bool {
  let mut selected_count = 0
  let mut line_number = 0
  while reader.read_until("\n") is Some(line) {
    line_number += 1
    let matched = matcher.matches(line, options.ignore_case)
    let selected = if options.invert { !matched } else { matched }
    if selected {
      selected_count += 1
      if options.quiet {
        return true
      }
      if !options.count &&
        !options.files_with_matches &&
        !options.files_without_match {
        let out = StringBuilder()
        if prefix_filename {
          out.write_string(path)
          out.write_char(':')
        }
        if options.line_number {
          out.write_string(line_number.to_string())
          out.write_char(':')
        }
        out.write_string(line)
        out.write_char('\n')
        @stdio.stdout.write(out.to_string())
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
  }
  selected_count > 0
}

///|
fn set_short_flags(options : GrepOptions, arg : String) -> Bool {
  for flag in arg[1:] {
    match flag {
      'F' => options.fixed = true
      'E' => options.fixed = false
      'i' => options.ignore_case = true
      'v' => options.invert = true
      'n' => options.line_number = true
      'c' => options.count = true
      'l' => options.files_with_matches = true
      'L' => options.files_without_match = true
      'q' => options.quiet = true
      'H' => options.force_filename = true
      'h' => options.no_filename = true
      'x' => options.whole_line = true
      'w' => options.word = true
      'r' | 'R' => options.recursive = true
      _ => return false
    }
  }
  true
}

///|
async fn main {
  let args = @env.args()[1:]
  let options : GrepOptions = {
    fixed: false,
    ignore_case: false,
    invert: false,
    line_number: false,
    count: false,
    files_with_matches: false,
    files_without_match: false,
    quiet: false,
    force_filename: false,
    no_filename: false,
    whole_line: false,
    word: false,
    recursive: false,
  }
  let patterns : Array[String] = []
  let pattern_files : Array[String] = []
  let files : Array[String] = []
  let mut options_enabled = true
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    if options_enabled && arg == "--" {
      options_enabled = false
    } else if options_enabled && (arg == "-e" || arg == "--regexp") {
      if i + 1 >= args.length() {
        @stdio.stderr.write("grep: missing pattern\n")
        @sys.exit(2)
        return
      }
      i += 1
      patterns.push(args[i])
    } else if options_enabled && arg.has_prefix("--regexp=") {
      patterns.push(arg[9:].to_owned())
    } else if options_enabled && (arg == "-f" || arg == "--file") {
      if i + 1 >= args.length() {
        @stdio.stderr.write("grep: missing pattern file\n")
        @sys.exit(2)
        return
      }
      i += 1
      pattern_files.push(args[i])
    } else if options_enabled && arg.has_prefix("--file=") {
      pattern_files.push(arg[7:].to_owned())
    } else if options_enabled && arg == "--help" {
      @stdio.stdout.write(
        "Usage: grep [-EFivnclLqHhxwr] [-e PATTERN] [-f FILE] [PATTERN] [FILE...]\n",
      )
      return
    } else if options_enabled && arg.has_prefix("-") && arg != "-" {
      if !set_short_flags(options, arg) {
        @stdio.stderr.write("grep: invalid option: '\{arg}'\n")
        @sys.exit(2)
        return
      }
    } else {
      files.push(arg)
    }
    i += 1
  }
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
        @stdio.stderr.write("grep: '\{pattern_file}': \{err}\n")
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
      let found = collect_files(operand) catch {
        err => {
          @stdio.stderr.write("grep: '\{operand}': \{err}\n")
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
        @stdio.stderr.write("grep: '\{source}': \{err}\n")
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
