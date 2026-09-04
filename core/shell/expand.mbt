///|
fn split_unquoted(
  value : String,
  fields : Array[String],
  current : StringBuilder,
  started : Ref[Bool],
) -> Unit {
  for char in value {
    if is_shell_space(char) || char == '\n' {
      if started.val {
        fields.push(current.to_string())
        current.reset()
        started.val = false
      }
    } else {
      current.write_char(char)
      started.val = true
    }
  }
}

///|
fn append_value(
  value : String,
  quoted : Bool,
  fields : Array[String],
  current : StringBuilder,
  started : Ref[Bool],
) -> Unit {
  if quoted {
    current.write_string(value)
    started.val = true
  } else {
    split_unquoted(value, fields, current, started)
  }
}

///|
async fn expand_word(
  word : Word,
  context : Context,
) -> Array[String] raise ShellError {
  let fields : Array[String] = []
  let current = StringBuilder()
  let started = Ref(false)
  for part in word.parts {
    match part {
      Text(value) => {
        current.write_string(value)
        started.val = true
      }
      Variable(name, quoted) => {
        let value = match context.env.get(name) {
          Some(value) => value
          None =>
            if context.nounset {
              raise ShellError("parameter '\\{name}' is unset")
            } else {
              ""
            }
        }
        append_value(value, quoted, fields, current, started)
      }
      CommandSubstitution(script, quoted) => {
        let (status, output) = run_substitution(script, context)
        context.last_status = status
        append_value(
          output.trim_end().to_owned(),
          quoted,
          fields,
          current,
          started,
        )
      }
      LengthVariable(name, quoted) => {
        let value = context.env.get(name).unwrap_or("")
        append_value(
          value.iter().count().to_string(),
          quoted,
          fields,
          current,
          started,
        )
      }
      Positional(0, quoted) =>
        append_value(context.name, quoted, fields, current, started)
      Positional(index, quoted) =>
        append_value(
          context.positional.get(index - 1).unwrap_or(""),
          quoted,
          fields,
          current,
          started,
        )
      LastStatus(quoted) =>
        append_value(
          context.last_status.to_string(),
          quoted,
          fields,
          current,
          started,
        )
      ArgCount(quoted) =>
        append_value(
          context.positional.length().to_string(),
          quoted,
          fields,
          current,
          started,
        )
      AllArgs(quoted, join) =>
        if join {
          append_value(
            context.positional.join(" "),
            quoted,
            fields,
            current,
            started,
          )
        } else {
          for index, argument in context.positional {
            if index > 0 && started.val {
              fields.push(current.to_string())
              current.reset()
              started.val = false
            }
            append_value(argument, quoted, fields, current, started)
          }
        }
    }
  }
  if started.val || (word.preserve_empty && fields.is_empty()) {
    fields.push(current.to_string())
  }
  fields
}

///|
async fn expand_path(word : Word, context : Context) -> String raise ShellError {
  match expand_word(word, context) {
    [path] => path
    [] => raise ShellError("redirection path expands to no fields")
    _ => raise ShellError("redirection path expands to multiple fields")
  }
}

///|
fn split_assignment(value : String) -> (String, String)? {
  guard value.split_once("=") is Some((name, assigned)) else { return None }
  let name = name.to_owned()
  if name == "" || !is_name_start(name.iter().next().unwrap()) {
    return None
  }
  for char in name {
    if !is_name_char(char) {
      return None
    }
  }
  Some((name, assigned.to_owned()))
}

///|
async fn prepare(
  command : Command,
  context : Context,
) -> Prepared raise ShellError {
  let argv : Array[String] = []
  for word in command.words {
    argv.append(expand_word(word, context))
  }
  let env = Map(context.env.to_array())
  let mut first_command = 0
  while first_command < argv.length() {
    match split_assignment(argv[first_command]) {
      Some((name, value)) => {
        env[name] = value
        first_command += 1
      }
      None => break
    }
  }
  let executable = argv[first_command:].to_owned()
  let stdin = match command.stdin {
    Some(word) => Some(expand_path(word, context))
    None => None
  }
  let stdout = match command.stdout {
    Some({ target, append, }) => Some((expand_path(target, context), append))
    None => None
  }
  let stderr = match command.stderr {
    Some({ target, append, }) => Some((expand_path(target, context), append))
    None => None
  }
  {
    argv: executable,
    env,
    stdin,
    stdin_data: command.stdin_data,
    stdout,
    stderr,
  }
}
