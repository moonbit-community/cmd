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
  context : Context,
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
        match context.capture {
          Some(buffer) => buffer.write_string(value)
          None => @stdio.stdout.write(value)
        }
      }
  }
}

///|
async fn builtin_error(_prepared : Prepared, message : String) -> Int {
  @stdio.stderr.write("sh: \{message}\n")
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
  name == "set" ||
  name == "shift" ||
  name == "return" ||
  name == "break" ||
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
      write_output(context, output, prepared.stdout, false)
      Some(0)
    }
    "pwd" => {
      if !args.is_empty() {
        return Some(builtin_error(prepared, "pwd: unexpected operand"))
      }
      write_output(context, context.cwd + "\n", prepared.stdout, false)
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
        write_output(context, lines.join("\n") + "\n", prepared.stdout, false)
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
    "set" => {
      if args.length() == 1 && args[0] == "-e" {
        context.errexit = true
        return Some(0)
      }
      if args.length() == 1 && args[0] == "+e" {
        context.errexit = false
        return Some(0)
      }
      if args.length() == 1 && args[0] == "-u" {
        context.nounset = true
        return Some(0)
      }
      if args.length() == 1 && args[0] == "+u" {
        context.nounset = false
        return Some(0)
      }
      if args.length() > 0 && args[0] == "--" {
        context.positional = args[1:].to_owned()
        return Some(0)
      }
      Some(builtin_error(prepared, "set: unsupported option"))
    }
    "shift" => {
      let amount = match args {
        [] => 1
        [value] =>
          @string.parse_int(value) catch {
            _ =>
              return Some(
                builtin_error(prepared, "shift: numeric argument required"),
              )
          }
        _ => return Some(builtin_error(prepared, "shift: too many arguments"))
      }
      if amount < 0 || amount > context.positional.length() {
        return Some(builtin_error(prepared, "shift: shift count out of range"))
      }
      context.positional = context.positional[amount:].to_owned()
      Some(0)
    }
    "return" => {
      let status = match args {
        [] => context.last_status
        [value] =>
          @string.parse_int(value) catch {
            _ =>
              return Some(
                builtin_error(prepared, "return: numeric argument required"),
              )
          }
        _ => return Some(builtin_error(prepared, "return: too many arguments"))
      }
      context.return_status = Some((status % 256 + 256) % 256)
      Some(context.return_status.unwrap())
    }
    "break" => {
      if args.length() > 1 {
        return Some(builtin_error(prepared, "break: too many arguments"))
      }
      context.break_loop = true
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
  if context.capture is Some(_) && prepared.stdout is None {
    let (status, output) = @async_process.collect_stdout(
      prepared.argv[0],
      prepared.argv[1:],
      extra_env=prepared.env,
      inherit_env=false,
      cwd=context.cwd,
      no_console_window=true,
    )
    match context.capture {
      Some(buffer) => buffer.write_string(output.text())
      None => ()
    }
    return normalize_status(status)
  }
  let stdin = match prepared.stdin {
    Some(path) => Some(@child_process.redirect_from_file(path))
    None =>
      match prepared.stdin_data {
        Some(data) => {
          let (input, writer) = @async_process.write_to_process()
          @async.with_task_group() <| group => {
            group.spawn_bg(() => {
              defer writer.close()
              writer.write(data)
            })
          }
          Some(input)
        }
        None => None
      }
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
fn glob_match(pattern : String, value : String) -> Bool {
  let p = pattern.iter().collect()
  let v = value.iter().collect()
  fn go(p : Array[Char], i : Int, v : Array[Char], j : Int) -> Bool {
    if i == p.length() {
      return j == v.length()
    }
    if p[i] == '*' {
      go(p, i + 1, v, j) || (j < v.length() && go(p, i, v, j + 1))
    } else if j < v.length() && (p[i] == '?' || p[i] == v[j]) {
      go(p, i + 1, v, j + 1)
    } else {
      false
    }
  }
  go(p, 0, v, 0)
}

///|
async fn run_jobs(
  jobs : Array[Job],
  context : Context,
  ignore_errexit? : Bool = false,
) -> Int noraise {
  let mut status = context.last_status
  for job in jobs {
    if context.exited || context.return_status is Some(_) || context.break_loop {
      break
    }
    let should_run = match job.connector {
      Always => true
      OnSuccess => status == 0
      OnFailure => status != 0
    }
    if should_run {
      status = eval_statement(job.statement, context)
      context.last_status = status
      if context.errexit && !ignore_errexit && status != 0 {
        context.exited = true
        context.exit_status = status
        break
      }
    }
  } nobreak {
    ()
  }
  status
}

///|
async fn eval_statement(
  statement : Statement,
  context : Context,
) -> Int noraise {
  match statement {
    Pipeline(pipeline) => run_pipeline(pipeline, context) catch { _ => 1 }
    IfStatement(condition, then_body, else_body) => {
      let condition_status = run_jobs(condition, context, ignore_errexit=true)
      if condition_status == 0 {
        run_jobs(then_body, context)
      } else {
        run_jobs(else_body, context)
      }
    }
    CaseStatement(subject, arms) => {
      let values = expand_word(subject, context) catch { _ => [] }
      let value = values.get(0).unwrap_or("")
      let mut status = 0
      for arm in arms {
        let mut matched = false
        for pattern in arm.patterns {
          let patterns = expand_word(pattern, context) catch { _ => [] }
          for pattern in patterns {
            if glob_match(pattern, value) {
              matched = true
            }
          }
        }
        if matched {
          status = run_jobs(arm.body, context)
          break
        }
      } nobreak {
        ()
      }
      status
    }
    ForStatement(name, words, body) => {
      let mut values : Array[String] = []
      for word in words {
        values.append(expand_word(word, context) catch { _ => [] })
      }
      if values.is_empty() {
        values = context.positional.copy()
      }
      let mut status = 0
      for value in values {
        context.env[name] = value
        status = run_jobs(body, context)
        if context.break_loop {
          context.break_loop = false
          break
        }
      } nobreak {
        ()
      }
      status
    }
    LoopStatement(condition, body, until) => {
      let mut status = 0
      for ;; {
        let condition_status = run_jobs(condition, context, ignore_errexit=true)
        if (condition_status == 0) == until {
          break
        }
        status = run_jobs(body, context)
        if context.break_loop {
          context.break_loop = false
          break
        }
      } nobreak {
        ()
      }
      status
    }
    FunctionStatement(name, body) => {
      context.functions[name] = body
      0
    }
    GroupStatement(body, subshell) =>
      if subshell {
        let child : Context = {
          env: Map(context.env.to_array()),
          positional: context.positional.copy(),
          name: context.name,
          cwd: context.cwd,
          last_status: context.last_status,
          exited: false,
          exit_status: 0,
          capture: context.capture,
          functions: Map(context.functions.to_array()),
          return_status: None,
          break_loop: false,
          errexit: context.errexit,
          nounset: context.nounset,
        }
        run_jobs(body, child)
      } else {
        run_jobs(body, context)
      }
  }
}

///|
async fn run_substitution(
  script : String,
  parent : Context,
) -> (Int, String) raise ShellError {
  let buffer = StringBuilder()
  let nested : Context = {
    env: Map(parent.env.to_array()),
    positional: parent.positional.copy(),
    name: parent.name,
    cwd: parent.cwd,
    last_status: 0,
    exited: false,
    exit_status: 0,
    capture: Some(buffer),
    functions: Map([]),
    return_status: None,
    break_loop: false,
    errexit: parent.errexit,
    nounset: parent.nounset,
  }
  let jobs = parse(script)
  let mut status = 0
  for job in jobs {
    let should_run = match job.connector {
      Always => true
      OnSuccess => status == 0
      OnFailure => status != 0
    }
    if should_run {
      status = eval_statement(job.statement, nested)
      if nested.errexit && status != 0 {
        nested.exited = true
        nested.exit_status = status
        break
      }
    }
  } nobreak {
    ()
  }
  let output = match nested.capture {
    Some(value) => value.to_string()
    None => ""
  }
  (status, output)
}

///|
async fn run_command(command : Command, context : Context) -> Int {
  let prepared = prepare(command, context) catch {
    ShellError(message) => {
      @stdio.stderr.write("sh: \{message}\n")
      return 2
    }
  }
  if prepared.argv.is_empty() {
    context.env.merge_in_place(prepared.env)
    return 0
  }
  match run_builtin(prepared, context) {
    Some(status) => status
    None =>
      match context.functions.get(prepared.argv[0]) {
        Some(body) => {
          let previous_args = context.positional
          let previous_return = context.return_status
          context.return_status = None
          context.positional = prepared.argv[1:].to_owned()
          let status = run_jobs(body, context)
          context.positional = previous_args
          let result = context.return_status.unwrap_or(status)
          context.return_status = previous_return
          result
        }
        None =>
          run_external(prepared, context) catch {
            err => {
              @stdio.stderr.write("sh: \{err}\n")
              127
            }
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
    capture: None,
    functions: Map([]),
    return_status: None,
    break_loop: false,
    errexit: false,
    nounset: false,
  }
  let jobs = parse(script)
  ignore(run_jobs(jobs, context))
  if context.return_status is Some(status) {
    status
  } else if context.exited {
    context.exit_status
  } else {
    context.last_status
  }
}
