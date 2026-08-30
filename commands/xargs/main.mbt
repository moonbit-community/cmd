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
    raise XargsError("input contains an unmatched \'\{delimiter}\' quote")
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
async fn main {
  let args = @env.args()[1:]
  let mut null_mode = false
  let mut run_empty = false
  let mut verbose = false
  let mut max_args = 0
  let mut max_args_set = false
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
    } else if options && arg == "-n" {
      if i + 1 >= args.length() {
        @stdio.stderr.write("xargs: option requires an argument: -n\n")
        @sys.exit(1)
        return
      }
      i += 1
      max_args_set = true
      max_args = @strconv.from_str(args[i]) catch {
        _ => {
          @stdio.stderr.write("xargs: invalid max-args value\n")
          @sys.exit(1)
          return
        }
      }
    } else if options && arg.has_prefix("--max-args=") {
      max_args_set = true
      max_args = @strconv.from_str(arg[11:]) catch {
        _ => {
          @stdio.stderr.write("xargs: invalid max-args value\n")
          @sys.exit(1)
          return
        }
      }
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
  if max_args_set && max_args <= 0 {
    @stdio.stderr.write("xargs: max-args must be positive\n")
    @sys.exit(1)
    return
  }
  let values = try {
    let input = read_input()
    parse_words(input, null_mode)
  } catch {
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
  let program = if command.is_empty() { "echo" } else { command[0] }
  let prefix : Array[String] = if command.is_empty() {
    []
  } else {
    command[1:].to_owned()
  }
  if values.is_empty() && run_empty {
    return
  }
  let max_batch_bytes = 64 * 1024
  let mut prefix_bytes = 0
  for argument in prefix {
    prefix_bytes += argument.length() + 1
  }
  if prefix_bytes >= max_batch_bytes {
    @stdio.stderr.write("xargs: command arguments exceed 64 KiB safety limit\n")
    @sys.exit(1)
    return
  }
  let mut offset = 0
  let context = @process.ExecutionContext::current()
  if values.is_empty() {
    let code = @process.run(@process.child(program, prefix, context~)) catch {
      @os_error.OSError(_) as err => {
        @stdio.stderr.write("xargs: cannot run '\{program}': \{err}\n")
        @sys.exit(if err.is_ENOENT() { 127 } else { 126 })
        return
      }
      err => {
        @stdio.stderr.write("xargs: cannot run '\{program}': \{err}\n")
        @sys.exit(126)
        return
      }
    }
    if code != 0 {
      @sys.exit(code)
    }
    return
  }
  while offset < values.length() {
    let mut end = offset
    let mut batch_bytes = prefix_bytes
    while end < values.length() && (max_args <= 0 || end - offset < max_args) {
      let argument_bytes = values[end].length() + 1
      if batch_bytes + argument_bytes > max_batch_bytes {
        break
      }
      batch_bytes += argument_bytes
      end += 1
    }
    if end == offset {
      @stdio.stderr.write("xargs: one argument exceeds 64 KiB safety limit\n")
      @sys.exit(1)
      return
    }
    let batch = prefix + values[offset:end].to_owned()
    if verbose {
      @stdio.stderr.write("\{program} \{batch.join(" ")}\n")
    }
    let code = @process.run(@process.child(program, batch, context~)) catch {
      @os_error.OSError(_) as err => {
        @stdio.stderr.write("xargs: cannot run '\{program}': \{err}\n")
        @sys.exit(if err.is_ENOENT() { 127 } else { 126 })
        return
      }
      err => {
        @stdio.stderr.write("xargs: cannot run '\{program}': \{err}\n")
        @sys.exit(126)
        return
      }
    }
    if code != 0 {
      @sys.exit(code)
      return
    }
    offset = end
  }
}
