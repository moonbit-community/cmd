///|
fn normalize_status(status : Int) -> Int {
  if status < 0 {
    128 - status
  } else {
    status
  }
}

///|
async fn write_output(
  value : String,
  redirect : (String, Bool)?,
  error : Bool,
) -> Unit {
  match redirect {
    Some((path, append)) => {
      let file = @fsops.open_output(
        path,
        if append {
          AppendOrCreate
        } else {
          CreateOrTruncate
        },
      )
      defer file.close()
      file.write(value)
    }
    None =>
      if error {
        @stdio.stderr.write(value)
      } else {
        @stdio.stdout.write(value)
      }
  }
}

///|
async fn builtin_error(prepared : Prepared, message : String) -> Int {
  write_output("sh: \{message}\n", prepared.stderr, true)
  2
}

///|
fn is_builtin(name : String) -> Bool {
  name == ":" ||
  name == "true" ||
  name == "false" ||
  name == "echo" ||
  name == "pwd" ||
  name == "cd" ||
  name == "export" ||
  name == "unset" ||
  name == "exit"
}

///|
async fn run_builtin(prepared : Prepared, context : Context) -> Int? {
  guard prepared.argv.get(0) is Some(name) && is_builtin(name) else {
    return None
  }
  let args = prepared.argv[1:].to_owned()
  match name {
    ":" | "true" => Some(0)
    "false" => Some(1)
    "echo" => {
      let mut newline = true
      let mut start = 0
      while args.get(start) == Some("-n") {
        newline = false
        start += 1
      }
      let suffix = if newline { "\n" } else { "" }
      let output = args[start:].join(" ") + suffix
      write_output(output, prepared.stdout, false)
      Some(0)
    }
    "pwd" => {
      if !args.is_empty() {
        return Some(builtin_error(prepared, "pwd: unexpected operand"))
      }
      write_output(context.cwd + "\n", prepared.stdout, false)
      Some(0)
    }
    "cd" => {
      if args.length() > 1 {
        return Some(builtin_error(prepared, "cd: too many arguments"))
      }
      let destination = match args {
        [] => prepared.env.get("HOME").unwrap_or("")
        [path] => path
        _ => ""
      }
      if destination == "" {
        return Some(builtin_error(prepared, "cd: HOME is not set"))
      }
      let candidate = if @path.Path(destination).is_absolute() {
        destination
      } else {
        @path.Path(context.cwd).join(Path(destination)).to_string()
      }
      let resolved = @fs.realpath(candidate) catch {
        err => return Some(builtin_error(prepared, "cd: \{err}"))
      }
      let kind = @fs.kind(resolved) catch {
        err => return Some(builtin_error(prepared, "cd: \{err}"))
      }
      if kind != Directory {
        return Some(builtin_error(prepared, "cd: not a directory"))
      }
      context.cwd = resolved
      Some(0)
    }
    "export" => {
      if args.is_empty() {
        let lines : Array[String] = []
        for key, value in context.env {
          lines.push("export \{key}=\{value}")
        }
        lines.sort()
        write_output(lines.join("\n") + "\n", prepared.stdout, false)
        return Some(0)
      }
      for argument in args {
        match split_assignment(argument) {
          Some((key, value)) => context.env[key] = value
          None => {
            if argument == "" || !is_name_start(argument.iter().next().unwrap()) {
              return Some(
                builtin_error(prepared, "export: invalid name '\{argument}'"),
              )
            }
            for char in argument {
              if !is_name_char(char) {
                return Some(
                  builtin_error(prepared, "export: invalid name '\{argument}'"),
                )
              }
            }
            if !context.env.contains(argument) {
              context.env[argument] = ""
            }
          }
        }
      }
      Some(0)
    }
    "unset" => {
      for argument in args {
        if argument == "" || !is_name_start(argument.iter().next().unwrap()) {
          return Some(builtin_error(prepared, "unset: invalid name"))
        }
        for char in argument {
          if !is_name_char(char) {
            return Some(builtin_error(prepared, "unset: invalid name"))
          }
        }
        context.env.remove(argument)
      }
      Some(0)
    }
    "exit" => {
      if args.length() > 1 {
        return Some(builtin_error(prepared, "exit: too many arguments"))
      }
      let status = match args {
        [] => context.last_status
        [value] =>
          @string.parse_int(value) catch {
            _ =>
              return Some(
                builtin_error(prepared, "exit: numeric argument required"),
              )
          }
        _ => 2
      }
      context.exited = true
      context.exit_status = (status % 256 + 256) % 256
      Some(context.exit_status)
    }
    _ => None
  }
}

///|
async fn run_process(
  prepared : Prepared,
  stdin : &@async_process.ProcessInput?,
  stdout : &@async_process.ProcessOutput?,
  stderr : &@async_process.ProcessOutput?,
  cwd : String,
) -> Int {
  let program = prepared.argv[0]
  let context : @child_process.ExecutionContext = { cwd, env: prepared.env, }
  @child_process.run(
    @child_process.child(program, prepared.argv[1:].to_owned(), context~),
    stdin?,
    stdout?,
    stderr?,
  )
}

///|
async fn run_external(prepared : Prepared, context : Context) -> Int {
  let stdin = match prepared.stdin {
    Some(path) => Some(@child_process.redirect_from_file(path))
    None => None
  }
  let stdout = match prepared.stdout {
    Some((path, append)) => Some(@child_process.redirect_to_file(path, append~))
    None => None
  }
  let stderr = match prepared.stderr {
    Some((path, append)) => Some(@child_process.redirect_to_file(path, append~))
    None => None
  }
  normalize_status(run_process(prepared, stdin, stdout, stderr, context.cwd))
}

///|
async fn run_command(command : Command, context : Context) -> Int {
  let prepared = prepare(command, context)
  if prepared.argv.is_empty() {
    context.env.merge_in_place(prepared.env)
    return 0
  }
  match run_builtin(prepared, context) {
    Some(status) => status
    None =>
      run_external(prepared, context) catch {
        err => {
          write_output("sh: \{err}\n", prepared.stderr, true)
          127
        }
      }
  }
}

///|
async fn run_pipeline(pipeline : Pipeline, context : Context) -> Int {
  if pipeline.commands.length() == 1 {
    return run_command(pipeline.commands[0], context)
  }
  let prepared : Array[Prepared] = []
  for command in pipeline.commands {
    let value = prepare(command, context)
    if value.argv.is_empty() || is_builtin(value.argv[0]) {
      raise ShellError(
        "stateful or built-in commands in pipelines are not supported",
      )
    }
    prepared.push(value)
  }
  for index, command in prepared {
    if index > 0 && command.stdin is Some(_) {
      raise ShellError(
        "input redirection is only allowed on the first pipeline stage",
      )
    }
    if index + 1 < prepared.length() && command.stdout is Some(_) {
      raise ShellError(
        "output redirection is only allowed on the last pipeline stage",
      )
    }
  }
  @async.with_task_group(group => {
    let pipes : Array[
      (&@async_process.ProcessInput, &@async_process.ProcessOutput),
    ] = []
    for _ in 1..<prepared.length() {
      pipes.push(@child_process.pipe())
    }
    let tasks : Array[@async.Task[Int]] = []
    for index, command in prepared {
      let pipe_input = if index == 0 { None } else { Some(pipes[index - 1].0) }
      let pipe_output = if index + 1 == prepared.length() {
        None
      } else {
        Some(pipes[index].1)
      }
      tasks.push(
        group.spawn(() => {
          let stdin = match command.stdin {
            Some(path) => Some(@child_process.redirect_from_file(path))
            None => pipe_input
          }
          let stdout = match command.stdout {
            Some((path, append)) =>
              Some(@child_process.redirect_to_file(path, append~))
            None => pipe_output
          }
          let stderr = match command.stderr {
            Some((path, append)) =>
              Some(@child_process.redirect_to_file(path, append~))
            None => None
          }
          normalize_status(
            run_process(command, stdin, stdout, stderr, context.cwd),
          )
        }),
      )
    }
    let mut result = 0
    for index, task in tasks {
      let status = task.wait()
      if index + 1 == tasks.length() {
        result = status
      }
    }
    result
  })
}

///|
pub async fn run(
  script : String,
  name? : String = "sh",
  args? : Array[String] = [],
  env? : Map[String, String] = @child_process.default_environment(),
  cwd? : String,
) -> Int {
  let initial_cwd = match cwd {
    Some(value) => value
    None => @env.current_dir().unwrap_or(".")
  }
  let context : Context = {
    env: Map(env.to_array()),
    positional: args,
    name,
    cwd: initial_cwd,
    last_status: 0,
    exited: false,
    exit_status: 0,
  }
  let jobs = parse(script)
  for job in jobs {
    if context.exited {
      break
    }
    let should_run = match job.connector {
      Always => true
      OnSuccess => context.last_status == 0
      OnFailure => context.last_status != 0
    }
    if should_run {
      context.last_status = run_pipeline(job.pipeline, context) catch {
        ShellError(message) => {
          @stdio.stderr.write("sh: \{message}\n")
          2
        }
        err => {
          @stdio.stderr.write("sh: \{err}\n")
          1
        }
      }
    }
  }
  if context.exited {
    context.exit_status
  } else {
    context.last_status
  }
}
