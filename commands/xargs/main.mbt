///|
fn is_space(value : Char) -> Bool {
  value == ' ' || value == '\t' || value == '\n' || value == '\r'
}

///|
priv suberror XargsError {
  XargsError(String)
}

///|
fn push_word(result : Array[String], word : String) -> Unit {
  result.push(word)
}

///|
fn parse_words(
  text : String,
  null_mode : Bool,
) -> Array[String] raise XargsError {
  let result : Array[String] = []
  let current = StringBuilder()
  if null_mode {
    for char in text {
      if char == '\u{0}' {
        push_word(result, current.to_string())
        current.reset()
      } else {
        current.write_char(char)
      }
    }
    if !current.is_empty() {
      push_word(result, current.to_string())
    }
    return result
  }
  let mut quote : Char? = None
  let mut escaped = false
  let mut word_started = false
  for char in text {
    if escaped {
      current.write_char(char)
      escaped = false
      word_started = true
    } else if char == '\\' && quote != Some('\'') {
      escaped = true
      word_started = true
    } else {
      match quote {
        Some(delimiter) =>
          if char == delimiter {
            quote = None
          } else {
            current.write_char(char)
          }
        None =>
          if char == '\'' || char == '"' {
            quote = Some(char)
            word_started = true
          } else if is_space(char) {
            if word_started {
              push_word(result, current.to_string())
              current.reset()
              word_started = false
            }
          } else {
            current.write_char(char)
            word_started = true
          }
      }
    }
  }
  if escaped {
    raise XargsError("input ends with an unmatched backslash")
  }
  if quote is Some(delimiter) {
    raise XargsError("input contains an unmatched '\'\{delimiter}\' quote")
  }
  if word_started {
    push_word(result, current.to_string())
  }
  result
}

///|
async fn read_input() -> String {
  let bytes : Array[Byte] = []
  while @stdio.stdin.read_some(max_len=65536) is Some(chunk) {
    bytes.append(chunk.to_array())
  }
  let encoded = Bytes::from_array(bytes)
  @utf8.decode(encoded[:]) catch {
    _ => raise XargsError("input is not valid UTF-8")
  }
}

///|
fn replacement_lines(text : String, eof? : String? = None) -> Array[String] {
  let result : Array[String] = []
  for line in text.split("\n") {
    let value = line.trim().to_owned()
    let is_eof = match eof {
      Some(marker) => value == marker
      None => false
    }
    if value != "" && !is_eof {
      result.push(value)
    } else if is_eof {
      break
    }
  }
  result
}

///|
fn replace_arguments(
  arguments : Array[String],
  marker : String,
  value : String,
) -> Array[String] {
  arguments.map(argument => argument.replace_all(old=marker, new=value))
}

///|
fn xargs_child_status(status : Int) -> Int {
  if status == 0 {
    0
  } else if status == 255 {
    124
  } else if status < 0 {
    125
  } else {
    123
  }
}

///|
fn parse_positive(value : String, option : String) -> Int raise XargsError {
  let parsed = @strconv.from_str(value) catch {
    _ => raise XargsError("invalid value for \{option}: '\{value}'")
  }
  if parsed <= 0 {
    raise XargsError("\{option} must be positive")
  }
  parsed
}

///|
async fn parse_positive_or_exit(value : String, option : String) -> Int? {
  try parse_positive(value, option) catch {
    XargsError(message) => {
      @stdio.stderr.write("xargs: \{message}\n")
      @sys.exit(1)
      None
    }
  } noraise {
    parsed => Some(parsed)
  }
}

///|
fn command_size(prefix : Array[String], values : Array[String]) -> Int {
  let mut size = 0
  for argument in prefix {
    size += argument.length() + 1
  }
  for argument in values {
    size += argument.length() + 1
  }
  size
}

///|
async fn run_xargs_child(
  program : String,
  arguments : Array[String],
  context : @process.ExecutionContext,
  verbose : Bool,
) -> Int {
  if verbose {
    let command_line = program + " " + arguments.join(" ") + "\n"
    @stdio.stderr.write(command_line)
  }
  let code = @process.run(@process.child(program, arguments, context~)) catch {
    @os_error.OSError(_) as err => {
      @stdio.stderr.write("xargs: cannot run '\{program}': \{err}\n")
      let status = @process.launch_failure_status(
        if err.is_ENOENT() {
          CommandNotFound
        } else {
          CommandNotInvokable
        },
      )
      @sys.exit(status)
      status
    }
    err => {
      @stdio.stderr.write("xargs: cannot run '\{program}': \{err}\n")
      let status = @process.launch_failure_status(CommandNotInvokable)
      @sys.exit(status)
      status
    }
  }
  if code == 126 || code == 127 {
    @stdio.stderr.write(
      "xargs: child launch denied or unavailable (status \{code})\n",
    )
  }
  code
}

///|
fn aggregate_xargs_status(current : Int, child : Int) -> Int {
  let mapped = if child == 126 || child == 127 {
    child
  } else {
    xargs_child_status(child)
  }
  if mapped == 125 || current == 125 {
    125
  } else if mapped == 124 || current == 124 {
    124
  } else if mapped == 127 || current == 127 {
    127
  } else if mapped == 123 || current == 123 {
    123
  } else {
    0
  }
}

///|
async fn run_xargs_batches(
  program : String,
  batches : Array[Array[String]],
  max_procs : Int,
  context : @process.ExecutionContext,
  verbose : Bool,
) -> Int {
  if max_procs <= 1 {
    let mut result = 0
    for arguments in batches {
      result = aggregate_xargs_status(
        result,
        run_xargs_child(program, arguments, context, verbose),
      )
      if result == 124 || result == 125 || result == 126 || result == 127 {
        break
      }
    }
    result
  } else {
    @async.with_task_group <| group => {
      let mut result = 0
      let mut offset = 0
      while offset < batches.length() {
        let end = (offset + max_procs).min(batches.length())
        let tasks : Array[@async.Task[Int]] = []
        for arguments in batches[offset:end] {
          tasks.push(
            group.spawn(() => {
              run_xargs_child(program, arguments, context, verbose)
            }),
          )
        }
        for task in tasks {
          result = aggregate_xargs_status(result, task.wait())
        }
        offset = end
        if result == 124 || result == 125 || result == 126 || result == 127 {
          break
        }
      }
      result
    }
  }
}

///|
async fn main {
  let args = @env.args()[1:]
  let mut null_mode = false
  let mut run_empty = false
  let mut verbose = false
  let mut max_args = 0
  let mut max_lines = 0
  let mut max_bytes = 64 * 1024
  let mut max_procs = 1
  let mut replace : String? = None
  let mut eof_string : String? = None
  let mut show_limits = false
  let command : Array[String] = []
  let mut options = true
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    if options && arg == "--" {
      options = false
    } else if options && (arg == "-0" || arg == "--null") {
      null_mode = true
    } else if options && (arg == "-r" || arg == "--no-run-if-empty") {
      run_empty = true
    } else if options && (arg == "-t" || arg == "--verbose") {
      verbose = true
    } else if options && arg == "--show-limits" {
      show_limits = true
    } else if options && (arg == "-n" || arg == "--max-args") {
      if i + 1 >= args.length() {
        @stdio.stderr.write("xargs: option requires an argument: -n\n")
        @sys.exit(1)
        return
      }
      i += 1
      guard parse_positive_or_exit(args[i], "-n") is Some(value) else { return }
      max_args = value
    } else if options && (arg == "-L" || arg == "--max-lines") {
      if i + 1 >= args.length() {
        @stdio.stderr.write("xargs: option requires an argument: -L\n")
        @sys.exit(1)
        return
      }
      i += 1
      guard parse_positive_or_exit(args[i], "-L") is Some(value) else { return }
      max_lines = value
    } else if options && (arg == "-s" || arg == "--max-chars") {
      if i + 1 >= args.length() {
        @stdio.stderr.write("xargs: option requires an argument: -s\n")
        @sys.exit(1)
        return
      }
      i += 1
      guard parse_positive_or_exit(args[i], "-s") is Some(value) else { return }
      max_bytes = value
    } else if options && (arg == "-P" || arg == "--max-procs") {
      if i + 1 >= args.length() {
        @stdio.stderr.write("xargs: option requires an argument: -P\n")
        @sys.exit(1)
        return
      }
      i += 1
      guard parse_positive_or_exit(args[i], "-P") is Some(value) else { return }
      max_procs = value
    } else if options && (arg == "-E" || arg == "--eof") {
      if i + 1 >= args.length() {
        @stdio.stderr.write("xargs: option requires an argument: -E\n")
        @sys.exit(1)
        return
      }
      i += 1
      eof_string = Some(args[i])
    } else if options && arg.has_prefix("-E") && arg.length() > 2 {
      eof_string = Some(arg[2:].to_owned())
    } else if options && arg.has_prefix("--eof=") {
      eof_string = Some(arg[6:].to_owned())
    } else if options && (arg == "-I" || arg == "--replace") {
      if i + 1 >= args.length() {
        @stdio.stderr.write("xargs: option requires an argument: \{arg}\n")
        @sys.exit(1)
        return
      }
      i += 1
      replace = Some(args[i])
    } else if options && arg.has_prefix("--replace=") {
      replace = Some(arg[10:].to_owned())
    } else if options && arg.has_prefix("-I") && arg.length() > 2 {
      replace = Some(arg[2:].to_owned())
    } else if options && arg.has_prefix("--max-args=") {
      guard parse_positive_or_exit(arg[11:].to_owned(), "-n") is Some(value) else {
        return
      }
      max_args = value
    } else if options && arg.has_prefix("--max-lines=") {
      guard parse_positive_or_exit(arg[12:].to_owned(), "-L") is Some(value) else {
        return
      }
      max_lines = value
    } else if options && arg.has_prefix("--max-chars=") {
      guard parse_positive_or_exit(arg[12:].to_owned(), "-s") is Some(value) else {
        return
      }
      max_bytes = value
    } else if options && arg.has_prefix("--max-procs=") {
      guard parse_positive_or_exit(arg[12:].to_owned(), "-P") is Some(value) else {
        return
      }
      max_procs = value
    } else if options && arg == "--help" {
      @stdio.stdout.write(
        "Usage: xargs [-0rt] [-n N] [-L N] [-s BYTES] [-P N] [-E EOF] [-I REPLACE] [COMMAND [ARG...]]\n",
      )
      return
    } else if options && arg.has_prefix("-") && arg != "-" {
      let mut valid = true
      for flag in arg[1:] {
        match flag {
          '0' => null_mode = true
          'r' => run_empty = true
          't' => verbose = true
          _ => valid = false
        }
      }
      if !valid {
        @stdio.stderr.write("xargs: unsupported option: \{arg}\n")
        @sys.exit(1)
        return
      }
    } else {
      command.push(arg)
    }
    i += 1
  }
  let input = read_input() catch {
    XargsError(message) => {
      @stdio.stderr.write("xargs: \{message}\n")
      @sys.exit(1)
      return
    }
    err => {
      @stdio.stderr.write("xargs: cannot read input: \{err}\n")
      @sys.exit(1)
      return
    }
  }
  if show_limits {
    @stdio.stdout.write("max-args-bytes: \{max_bytes}\n")
    return
  }
  let program = if command.is_empty() { "echo" } else { command[0] }
  let prefix : Array[String] = if command.is_empty() {
    []
  } else {
    command[1:].to_owned()
  }
  let batches : Array[Array[String]] = []
  if replace is Some(marker) {
    for value in replacement_lines(input, eof=eof_string) {
      batches.push(replace_arguments(prefix, marker, value))
    }
  } else if max_lines > 0 {
    let lines : Array[Array[String]] = []
    if null_mode {
      for value in parse_words(input, true) {
        lines.push([value])
      }
    } else {
      for line in input.split("\n") {
        let words = parse_words(line.to_owned(), false)
        if !words.is_empty() {
          lines.push(words)
        }
      }
    }
    let mut offset = 0
    let mut eof_reached = false
    while offset < lines.length() {
      let mut end = offset
      let values : Array[String] = []
      while end < lines.length() && end - offset < max_lines {
        if eof_string is Some(marker) &&
          lines[end].any(value => value == marker) {
          eof_reached = true
          break
        }
        let candidate = values + lines[end]
        if max_args > 0 && candidate.length() > max_args {
          break
        }
        if command_size(prefix, candidate) > max_bytes {
          break
        }
        values.append(lines[end])
        end += 1
      }
      if end == offset {
        if eof_reached {
          break
        }
        @stdio.stderr.write(
          "xargs: input line exceeds \{max_bytes} byte limit\n",
        )
        @sys.exit(1)
        return
      }
      batches.push(prefix + values)
      offset = end
      if eof_reached {
        break
      }
    }
  } else {
    let mut values = parse_words(input, null_mode)
    if eof_string is Some(marker) {
      let mut end = values.length()
      for index, value in values {
        if value == marker {
          end = index
          break
        }
      }
      values = values[:end].to_owned()
    }
    if !values.is_empty() {
      let mut offset = 0
      while offset < values.length() {
        let mut end = offset
        while end < values.length() &&
              (max_args == 0 || end - offset < max_args) {
          let candidate = values[offset:end + 1].to_owned()
          if command_size(prefix, candidate) > max_bytes {
            break
          }
          end += 1
        }
        if end == offset {
          @stdio.stderr.write(
            "xargs: one argument exceeds \{max_bytes} byte limit\n",
          )
          @sys.exit(1)
          return
        }
        batches.push(prefix + values[offset:end].to_owned())
        offset = end
      }
    }
  }
  if batches.is_empty() && run_empty {
    return
  }
  if batches.is_empty() {
    batches.push(prefix)
  }
  let status = run_xargs_batches(
    program,
    batches,
    max_procs,
    @process.ExecutionContext::current(),
    verbose,
  )
  if status != 0 {
    @sys.exit(status)
    return
  }
}
