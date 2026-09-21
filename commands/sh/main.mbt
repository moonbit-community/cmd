///|
async fn drive_input(session : @shell.Session, interactive : Bool) -> Int {
  let mut continuation = false
  for ;; {
    if interactive {
      @stdio.stderr.write(session.prompt(continuation~))
    }
    let line = @shell.read_line(@stdio.stdin)
    guard line is Some(line) else {
      return match session.finish() {
        @shell.Exit(status) | @shell.Completed(status) => status
        @shell.NeedMoreInput => 2
      }
    }
    let result = session.feed(line) catch {
      @shell.ShellError(message) => {
        @stdio.stderr.write("sh: \{message}\n")
        if !interactive {
          return 2
        }
        @shell.Completed(2)
      }
      err => raise err
    }
    match result {
      @shell.NeedMoreInput => continuation = true
      @shell.Completed(_) => continuation = false
      @shell.Exit(status) => return status
    }
  }
}

///|
async fn main {
  let raw = @env.args()
  let arguments = raw[1:]
  let invocation = @path.Path(raw.get(0).unwrap_or("sh")).basename().to_owned()
  let invocation = if invocation.has_suffix(".exe") {
    invocation[:invocation.length() - 4].to_owned()
  } else if invocation.has_suffix(".wasm") {
    invocation[:invocation.length() - 5].to_owned()
  } else {
    invocation
  }
  let mut index = 0
  let mut command : String? = None
  let mut script_path : String? = None
  let mut interactive = false
  let mut stdin_script = false
  let mut options = true
  while index < arguments.length() && command is None && script_path is None {
    let argument = arguments[index]
    if options && argument == "--" {
      options = false
      index += 1
    } else if options && argument == "-i" {
      interactive = true
      index += 1
    } else if options && argument == "-c" {
      if index + 1 >= arguments.length() {
        @stdio.stderr.write("sh: -c requires a command string\n")
        @sys.exit(2)
      }
      command = Some(arguments[index + 1])
      index += 2
    } else if options && argument == "-s" {
      stdin_script = true
      index += 1
      break
    } else if options && argument.has_prefix("-") && argument != "-" {
      @stdio.stderr.write("sh: unsupported option '\{argument}'\n")
      @sys.exit(2)
    } else {
      script_path = Some(argument)
      index += 1
    }
  }
  let name = if command is Some(_) {
    arguments.get(index).unwrap_or("sh")
  } else {
    script_path.unwrap_or(invocation)
  }
  let positional = if command is Some(_) && index < arguments.length() {
    arguments[index + 1:].to_owned()
  } else {
    arguments[index:].to_owned()
  }
  let session = @shell.Session::new(name~, args=positional, interactive~)
  if interactive {
    session.load_startup() catch {
      err => @stdio.stderr.write("sh: startup: \{err}\n")
    }
  }
  let status = try {
    let source = match command {
      Some(source) => Some(source)
      None =>
        match script_path {
          Some(path) if path != "-" => Some(@fs.read_file(path).text())
          _ => None
        }
    }
    match source {
      Some(source) =>
        match session.feed(source) {
          @shell.Completed(status) | @shell.Exit(status) => status
          @shell.NeedMoreInput => {
            ignore(session.finish())
            2
          }
        }
      None => {
        ignore(stdin_script)
        drive_input(session, interactive)
      }
    }
  } catch {
    @shell.ShellError(message) => {
      @stdio.stderr.write("sh: \{message}\n")
      2
    }
    err => {
      @stdio.stderr.write("sh: \{err}\n")
      2
    }
  }
  if status != 0 {
    @sys.exit(status)
  }
}
