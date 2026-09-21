///|
fn normalize_status(status : Int) -> Int {
  if status < 0 {
    128 - status
  } else {
    status
  }
}

///|
fn clone_context(context : Context, capture? : StringBuilder) -> Context {
  {
    env: Map(context.env.to_array()),
    exported: Set(context.exported.to_array()),
    positional: context.positional.copy(),
    name: context.name,
    cwd: context.cwd,
    last_status: context.last_status,
    exited: false,
    exit_status: 0,
    capture: match capture {
      Some(value) => Some(value)
      None => context.capture
    },
    input: context.input,
    output: context.output,
    error: context.error,
    functions: Map(context.functions.to_array()),
    errexit: context.errexit,
    nounset: context.nounset,
    return_status: None,
    break_loop: false,
    continue_loop: false,
    loop_depth: 0,
    call_depth: context.call_depth,
    substitution_status: None,
    expansion_failed: false,
  }
}

///|
async fn write_output(
  context : Context,
  value : String,
  error? : Bool = false,
) -> Unit {
  if error {
    match context.error {
      Some(writer) => writer.write(value)
      None => @stdio.stderr.write(value)
    }
  } else {
    match context.output {
      Some(writer) => writer.write(value)
      None =>
        match context.capture {
          Some(buffer) => buffer.write_string(value)
          None => @stdio.stdout.write(value)
        }
    }
  }
}

///|
async fn builtin_error(context : Context, message : String) -> Int {
  write_output(context, "sh: \{message}\n", error=true)
  2
}

///|
async fn run_external(prepared : Prepared, context : Context) -> Int {
  @async.with_task_group() <| group => {
    let stdin : &@async_process.ProcessInput? = match context.input {
      None => None
      Some(reader) => {
        let (input, writer) = @async_process.write_to_process()
        group.spawn_bg(
          () => {
            defer writer.close()
            writer.write_reader(reader)
          },
          no_wait=true,
          allow_failure=true,
        )
        Some(input)
      }
    }
    let stdout : &@async_process.ProcessOutput? = if context.output
      is Some(writer) {
      let (reader, output) = @async_process.read_from_process()
      group.spawn_bg(() => {
        defer reader.close()
        writer.write_reader(reader)
      })
      Some(output)
    } else {
      None
    }
    let stderr : &@async_process.ProcessOutput? = if context.error
      is Some(writer) {
      let (reader, output) = @async_process.read_from_process()
      group.spawn_bg(() => {
        defer reader.close()
        writer.write_reader(reader)
      })
      Some(output)
    } else {
      None
    }
    if context.capture is Some(buffer) && context.output is None {
      let (status, output) = @async_process.collect_stdout(
        prepared.argv[0],
        prepared.argv[1:],
        extra_env=prepared.env,
        inherit_env=false,
        stdin?,
        stderr?,
        cwd=context.cwd,
        no_console_window=true,
      )
      buffer.write_string(output.text())
      normalize_status(status)
    } else {
      let execution : @child_process.ExecutionContext = {
        cwd: context.cwd,
        env: prepared.env,
      }
      normalize_status(
        @child_process.run(
          @child_process.child(
            prepared.argv[0],
            prepared.argv[1:].to_owned(),
            context=execution,
          ),
          stdin?,
          stdout?,
          stderr?,
        ),
      )
    }
  }
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
      return go(p, i + 1, v, j) || (j < v.length() && go(p, i, v, j + 1))
    }
    if p[i] == '\\' && i + 1 < p.length() {
      return j < v.length() && p[i + 1] == v[j] && go(p, i + 2, v, j + 1)
    }
    if p[i] == '[' && j < v.length() {
      let mut end = i + 1
      let negate = p.get(end) == Some('!') || p.get(end) == Some('^')
      if negate {
        end += 1
      }
      let mut matched = false
      let start = end
      while end < p.length() && (p[end] != ']' || end == start) {
        if end + 2 < p.length() && p[end + 1] == '-' && p[end + 2] != ']' {
          if v[j] >= p[end] && v[j] <= p[end + 2] {
            matched = true
          }
          end += 3
        } else {
          if p[end] == v[j] {
            matched = true
          }
          end += 1
        }
      }
      if end < p.length() {
        return matched != negate && go(p, end + 1, v, j + 1)
      }
    }
    j < v.length() && (p[i] == '?' || p[i] == v[j]) && go(p, i + 1, v, j + 1)
  }
  go(p, 0, v, 0)
}

///|
async fn run_jobs(
  jobs : Array[Job],
  context : Context,
  ignore_errexit? : Bool = false,
) -> Int {
  let mut status = context.last_status
  for index, job in jobs {
    if context.exited ||
      context.return_status is Some(_) ||
      context.break_loop ||
      context.continue_loop {
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
      let tested = jobs.get(index + 1)
        is Some({ connector: OnSuccess | OnFailure, .. })
      if context.errexit && !ignore_errexit && !tested && status != 0 {
        context.exited = true
        context.exit_status = status
        break
      }
    }
  }
  status
}

///|
async fn eval_statement(statement : Statement, context : Context) -> Int {
  match statement {
    Pipeline(pipeline) => run_pipeline(pipeline, context)
    IfStatement(condition, then_body, else_body) => {
      let condition_status = run_jobs(condition, context, ignore_errexit=true)
      if condition_status == 0 {
        run_jobs(then_body, context)
      } else if else_body.is_empty() {
        0
      } else {
        run_jobs(else_body, context)
      }
    }
    CaseStatement(subject, arms) => {
      let value = expand_word(subject, context, split=false, pathname=false).join(
        "",
      )
      for arm in arms {
        for pattern in arm.patterns {
          let patterns = expand_word(
            pattern,
            context,
            split=false,
            pathname=false,
            preserve_pattern=true,
          )
          for pattern in patterns {
            if glob_match(pattern, value) {
              return run_jobs(arm.body, context)
            }
          }
        }
      }
      0
    }
    ForStatement(name, words, body) => {
      let values : Array[String] = []
      for word in words {
        values.append(expand_word(word, context))
      }
      let mut status = 0
      context.loop_depth += 1
      defer {
        context.loop_depth -= 1
      }
      for value in values {
        context.env[name] = value
        status = run_jobs(body, context)
        context.continue_loop = false
        if context.break_loop {
          context.break_loop = false
          break
        }
        if context.exited || context.return_status is Some(_) {
          break
        }
      }
      status
    }
    LoopStatement(condition, body, until) => {
      let mut status = 0
      context.loop_depth += 1
      defer {
        context.loop_depth -= 1
      }
      for ;; {
        let condition_status = run_jobs(condition, context, ignore_errexit=true)
        if context.exited ||
          context.return_status is Some(_) ||
          (condition_status == 0) == until {
          break
        }
        status = run_jobs(body, context)
        context.continue_loop = false
        if context.break_loop {
          context.break_loop = false
          break
        }
        if context.exited || context.return_status is Some(_) {
          break
        }
      }
      status
    }
    FunctionStatement(name, body) => {
      context.functions[name] = body
      0
    }
    GroupStatement(body, subshell) =>
      if subshell {
        run_jobs(body, clone_context(context))
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
  let nested = clone_context(parent, capture=buffer)
  nested.output = None
  let status = run_jobs(parse(script), nested) catch {
    err => raise ShellError("command substitution: \{err}")
  }
  (if nested.exited { nested.exit_status } else { status }, buffer.to_string())
}

///|
async fn execute_prepared(prepared : Prepared, context : Context) -> Int {
  if prepared.argv.is_empty() {
    context.env.merge_in_place(prepared.assignments)
    return context.substitution_status.unwrap_or(0)
  }
  let previous : Map[String, String?] = Map([])
  let previous_exported = Set(context.exported.to_array())
  for name, value in prepared.assignments {
    previous[name] = context.env.get(name)
    context.env[name] = value
  }
  let special = [
    ":", "export", "unset", "set", "shift", "return", "break", "continue", "exit",
    ".",
  ].contains(prepared.argv[0])
  if !special {
    for name in prepared.assignments.keys() {
      context.exported.add(name)
    }
  }
  defer (if !special {
    for name, value in previous {
      match value {
        Some(value) => context.env[name] = value
        None => context.env.remove(name)
      }
    }
    for name in prepared.assignments.keys() {
      if !previous_exported.contains(name) {
        context.exported.remove(name)
      }
    }
  })
  match run_builtin(prepared.argv, context) {
    Some(status) => status
    None =>
      match context.functions.get(prepared.argv[0]) {
        Some(body) => {
          let previous_args = context.positional
          let previous_return = context.return_status
          context.return_status = None
          context.positional = prepared.argv[1:].to_owned()
          context.call_depth += 1
          defer {
            context.positional = previous_args
            context.return_status = previous_return
            context.call_depth -= 1
          }
          let status = run_jobs(body, context)
          context.return_status.unwrap_or(status)
        }
        None =>
          run_external(prepared, context) catch {
            err => {
              write_output(context, "sh: \{err}\n", error=true)
              127
            }
          }
      }
  }
}

///|
async fn run_command(command : Command, context : Context) -> Int {
  let prepared = prepare(command, context) catch {
    ShellError(message) => {
      context.exited = true
      context.expansion_failed = true
      context.exit_status = 2
      return builtin_error(context, message)
    }
  }
  let previous_input = context.input
  let previous_output = context.output
  let previous_error = context.error
  let files : Array[@fs.File] = []
  let memories : Array[@io.MemoryReader] = []
  defer {
    for file in files {
      file.close()
    }
    for reader in memories {
      reader.close()
    }
    context.input = previous_input
    context.output = previous_output
    context.error = previous_error
  }
  try {
    if prepared.stdin is Some(path) {
      let file = @fs.open(path, mode=ReadOnly)
      files.push(file)
      context.input = Some(file)
    } else if prepared.stdin_data is Some(data) {
      let reader = @io.MemoryReader(writer => writer.write(data))
      memories.push(reader)
      context.input = Some(reader)
    }
    if prepared.stdout is Some((path, append)) {
      let file = @fs.open(
        path,
        mode=WriteOnly,
        create_mode=if append { OpenOrCreate } else { CreateOrTruncate },
        append~,
      )
      files.push(file)
      context.output = Some(file)
    }
    if prepared.stderr is Some((path, append)) {
      let file = @fs.open(
        path,
        mode=WriteOnly,
        create_mode=if append { OpenOrCreate } else { CreateOrTruncate },
        append~,
      )
      files.push(file)
      context.error = Some(file)
    }
    execute_prepared(prepared, context)
  } catch {
    @io.PipeClosed => 141
    err => {
      write_output(context, "sh: \{err}\n", error=true)
      1
    }
  }
}

///|
async fn run_pipeline(pipeline : Pipeline, context : Context) -> Int {
  if pipeline.commands.length() == 1 {
    return run_command(pipeline.commands[0], context)
  }
  @async.with_task_group() <| group => {
    let pipes : Array[(@io.PipeRead, @io.PipeWrite)] = []
    for _ in 1..<pipeline.commands.length() {
      pipes.push(@io.pipe())
    }
    let tasks : Array[@async.Task[Int]] = []
    for index, command in pipeline.commands {
      let child = clone_context(context)
      if index > 0 {
        child.input = Some(pipes[index - 1].0)
      }
      if index + 1 < pipeline.commands.length() {
        child.output = Some(pipes[index].1)
      }
      tasks.push(
        group.spawn(() => {
          defer {
            if index > 0 {
              pipes[index - 1].0.close()
            }
            if index + 1 < pipeline.commands.length() {
              pipes[index].1.close()
            }
          }
          run_command(command, child)
        }),
      )
    }
    let mut status = 0
    for task in tasks {
      status = task.wait()
    }
    status
  }
}
