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
fn parse_words(text : String) -> Array[String] raise XargsError {
  let result : Array[String] = []
  let current = StringBuilder()
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
fn replace_arguments(
  arguments : Array[String],
  marker : String,
  value : String,
) -> Array[String] {
  arguments.map(argument => argument.replace_all(old=marker, new=value))
}

///|
fn xargs_child_status(status : Int32) -> Int32 {
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
fn parse_positive(value : String, option : String) -> Int32 raise XargsError {
  let parsed = @string.parse_int(value) catch {
    _ => raise XargsError("invalid value for \{option}: '\{value}'")
  }
  if parsed <= 0 {
    raise XargsError("\{option} must be positive")
  }
  parsed
}

///|
async fn parse_positive_or_exit(value : String, option : String) -> Int32? {
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
fn command_size(prefix : Array[String], values : Array[String]) -> Int64 {
  @process.arguments_bytes(prefix) + @process.arguments_bytes(values)
}

///|
async fn run_xargs_child(
  program : String,
  arguments : Array[String],
  context : @process.ExecutionContext,
  verbose : Bool,
) -> Int32 {
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
fn aggregate_xargs_status(current : Int32, child : Int32) -> Int32 {
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
  } else if mapped == 126 || current == 126 {
    126
  } else if mapped == 123 || current == 123 {
    123
  } else {
    0
  }
}

///|
async fn main {
  let metadata_args = @env.args()[1:]
  if metadata_args.length() == 1 && metadata_args[0] == "--version" {
    @stdio.stdout.write("xargs 0.2.4\n")
    return
  }
  let mut args = @env.args()[1:].to_owned()
  let mut delimiter : Int32? = None
  let mut interactive = false
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
    if options &&
      arg.length() > 2 &&
      arg.has_prefix("-") &&
      !arg.has_prefix("--") &&
      arg[1] is ('0' | 'r' | 't' | 'p') {
      args = args[:i].to_owned() +
        ["-" + arg[1:2].to_owned(), "-" + arg[2:].to_owned()] +
        args[i + 1:].to_owned()
      continue
    }
    if options && arg == "--" {
      options = false
    } else if options && (arg == "-0" || arg == "--null") {
      delimiter = Some(0)
    } else if options && (arg == "-p" || arg == "--interactive") {
      interactive = true
    } else if options && (arg == "-d" || arg == "--delimiter") {
      if i + 1 >= args.length() {
        @stdio.stderr.write(
          "xargs: option requires an argument -- 'd'\nTry 'xargs --help' for more information.\n",
        )
        @sys.exit(1)
        return
      }
      i += 1
      guard delimiter_or_exit(args[i]) is Some(value) else { return }
      delimiter = Some(value)
    } else if options &&
      (
        arg.has_prefix("--delimiter=") ||
        (arg.has_prefix("-d") && arg.length() > 2)
      ) {
      let value = if arg.has_prefix("--") {
        arg[12:].to_owned()
      } else {
        arg[2:].to_owned()
      }
      guard delimiter_or_exit(value) is Some(value) else { return }
      delimiter = Some(value)
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
    } else if options &&
      arg.length() > 2 &&
      arg.has_prefix("-") &&
      !arg.has_prefix("--") &&
      arg[1] is ('n' | 'L' | 's' | 'P') {
      let option = arg[:2].to_owned()
      guard parse_positive_or_exit(arg[2:].to_owned(), option) is Some(value) else {
        return
      }
      match arg[1] {
        'n' => max_args = value
        'L' => max_lines = value
        's' => max_bytes = value
        _ => max_procs = value
      }
    } else if options && arg == "--help" {
      @stdio.stdout.write(
        "Usage: xargs [-0prt] [-d BYTE] [-n N] [-L N] [-s BYTES] [-P N] [-E EOF] [-I REPLACE] [COMMAND [ARG...]]\n  -d, --delimiter=BYTE  separate literal input items with BYTE or an escape\n  -p, --interactive     confirm each invocation through an independent console\nComplete -n/-L batches can execute before EOF; later input errors preserve completed child effects.\n-P N replenishes individual free slots; --show-limits leaves stdin untouched.\n      --help      display this help and exit\n      --version   display version and exit\n",
      )
      return
    } else if options && arg.has_prefix("-") && arg != "-" {
      let mut valid = true
      for flag in arg[1:] {
        match flag {
          '0' => delimiter = Some(0)
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
      options = false
    }
    i += 1
  }
  if delimiter is Some(_) && eof_string is Some(_) {
    @stdio.stderr.write(
      "xargs: warning: the -E option has no effect if -0 or -d is used.\n\n",
    )
    eof_string = None
  }
  let program = if command.is_empty() { "echo" } else { command[0] }
  let prefix : Array[String] = if command.is_empty() {
    []
  } else {
    command[1:].to_owned()
  }
  if command_size([program], prefix) > max_bytes.to_int64() {
    @stdio.stderr.write(
      "xargs: cannot fit single argument within argument list size limit\n",
    )
    @sys.exit(1)
    return
  }
  let confirmation : @fs.File? = if interactive {
    let device = if @async.platform is Windows { "CONIN$" } else { "/dev/tty" }
    Some(
      @fs.open(device, mode=ReadOnly) catch {
        _ => {
          @stdio.stderr.write(
            "xargs: unsupported capability: independent confirmation channel unavailable\n",
          )
          @sys.exit(2)
          return
        }
      },
    )
  } else {
    None
  }
  defer (if confirmation is Some(file) { file.close() })
  if show_limits {
    @stdio.stdout.write("max-args-bytes: \{max_bytes}\n")
    return
  }
  let mode : InputMode = match delimiter {
    Some(byte) => Delimited(if byte >= 128 { byte - 256 } else { byte })
    None => if replace is Some(_) || max_lines > 0 { Lines } else { Words }
  }
  let batches : BatchReader = {
    input: ItemReader::new(@stdio.stdin, mode, max_bytes),
    program,
    prefix,
    prefix_bytes: @process.argument_bytes(program) +
    @process.arguments_bytes(prefix),
    max_args,
    max_lines,
    max_bytes: max_bytes.to_int64(),
    replace,
    eof: eof_string,
    no_empty: run_empty,
    pending: None,
    emitted: false,
  }
  let context = @process.ExecutionContext::current()
  let status = run_xargs_stream(
    batches,
    max_procs,
    arguments => {
      run_xargs_child(
        program,
        arguments,
        context,
        verbose && confirmation is None,
      )
    },
    approve=arguments => {
      match confirmation {
        Some(channel) => confirm_batch(channel, program, arguments)
        None => true
      }
    },
  ) catch {
    ArgvBytesBoundary => {
      @stdio.stderr.write(
        "xargs: unsupported capability: non-UTF-8 argument transport\n",
      )
      @sys.exit(2)
      return
    }
    XargsError(message) => {
      @stdio.stderr.write("xargs: \{message}\n")
      @sys.exit(1)
      return
    }
    error => {
      @stdio.stderr.write("xargs: input or execution failed: \{error}\n")
      @sys.exit(1)
      return
    }
  }
  if status != 0 {
    @sys.exit(status)
    return
  }
}
