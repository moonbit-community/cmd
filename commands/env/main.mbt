///|
fn split_assignment(value : String) -> (String, String)? {
  let pieces : Array[String] = value.split("=").map(v => v.to_owned()).collect()
  if pieces.length() < 2 {
    return None
  }
  let key = pieces[0]
  if key == "" || !is_valid_name(key) {
    return None
  }
  Some((key, pieces[1:].join("=")))
}

///|
fn is_valid_name(value : String) -> Bool {
  let chars : Array[Char] = value.iter().collect()
  if chars.is_empty() {
    return false
  }
  if !(chars[0] == '_' || chars[0] is ('a'..='z' | 'A'..='Z')) {
    return false
  }
  for char in chars[1:] {
    if !(char == '_' || char is ('a'..='z' | 'A'..='Z' | '0'..='9')) {
      return false
    }
  }
  true
}

///|
async fn main {
  let args = @core_env.args()[1:]
  let mut ignore_environment = false
  let unset : Array[String] = []
  let assignments : Array[(String, String)] = []
  let command_args : Array[String] = []
  let mut command : String? = None
  let mut options = true
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    if command is Some(_) {
      command_args.push(arg)
    } else if options && arg == "--" {
      options = false
    } else if options && (arg == "-i" || arg == "--ignore-environment") {
      ignore_environment = true
    } else if options && (arg == "-u" || arg == "--unset") {
      if i + 1 >= args.length() {
        @stdio.stderr.write("env: option requires an argument: \{arg}\n")
        @sys.exit(125)
        return
      }
      i += 1
      unset.push(args[i])
    } else if options && arg.has_prefix("--unset=") {
      unset.push(arg[8:].to_owned())
    } else if options && split_assignment(arg) is Some((key, value)) {
      assignments.push((key, value))
    } else if arg.has_prefix("-") && options {
      @stdio.stderr.write("env: unsupported option: \{arg}\n")
      @sys.exit(125)
      return
    } else {
      command = Some(arg)
    }
    i += 1
  }
  let variables : Map[String, String] = if ignore_environment {
    Map([])
  } else {
    @process.default_environment()
  }
  for name in unset {
    variables.remove(name)
  }
  for index in 0..<assignments.length() {
    let (key, value) = assignments[index]
    variables[key] = value
  }
  match command {
    None => {
      let lines : Array[String] = []
      for key, value in variables {
        lines.push("\{key}=\{value}")
      }
      lines.sort()
      for line in lines {
        @stdio.stdout.write("\{line}\n")
      }
    }
    Some(program) => {
      let context : @process.ExecutionContext = {
        cwd: @core_env.current_dir().unwrap_or("."),
        env: variables,
      }
      let code = @process.run(@process.child(program, command_args, context~)) catch {
        @os_error.OSError(_) as err => {
          @stdio.stderr.write("env: cannot run '\{program}': \{err}\n")
          @sys.exit(
            @process.launch_failure_status(
              if err.is_ENOENT() {
                CommandNotFound
              } else {
                CommandNotInvokable
              },
            ),
          )
          return
        }
        err => {
          @stdio.stderr.write("env: cannot run '\{program}': \{err}\n")
          @sys.exit(@process.launch_failure_status(CommandNotInvokable))
          return
        }
      }
      if code != 0 {
        @sys.exit(code)
      }
    }
  }
}
