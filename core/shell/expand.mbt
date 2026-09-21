///|
fn pattern_literal(value : String) -> String {
  let result = StringBuilder()
  for ch in value {
    if ch is ('*' | '?' | '[' | ']' | '\\') {
      result.write_char('\\')
    }
    result.write_char(ch)
  }
  result.to_string()
}

///|
fn unescape_pattern(value : String) -> String {
  let result = StringBuilder()
  let mut escaped = false
  for ch in value {
    if escaped {
      result.write_char(ch)
      escaped = false
    } else if ch == '\\' {
      escaped = true
    } else {
      result.write_char(ch)
    }
  }
  if escaped {
    result.write_char('\\')
  }
  result.to_string()
}

///|
fn has_pattern(value : String) -> Bool {
  let mut escaped = false
  for ch in value {
    if escaped {
      escaped = false
    } else if ch == '\\' {
      escaped = true
    } else if ch is ('*' | '?' | '[') {
      return true
    }
  }
  false
}

///|
fn resolve_path(context : Context, value : String) -> String {
  if @path.Path(value).is_absolute() {
    value
  } else {
    @path.Path(context.cwd).join(Path(value)).to_string()
  }
}

///|
async fn expand_glob(pattern : String, context : Context) -> Array[String] {
  if !has_pattern(pattern) {
    return [unescape_pattern(pattern)]
  }
  let absolute = pattern.has_prefix("/")
  let segments = pattern.split("/").map(s => s.to_owned()).collect()
  let mut candidates = [if absolute { "/" } else { "" }]
  for index, segment in segments {
    if index == 0 && absolute {
      continue
    }
    let next : Array[String] = []
    for prefix in candidates {
      let join = fn(value : String) {
        if prefix == "" {
          value
        } else if prefix == "/" {
          "/" + value
        } else {
          prefix + "/" + value
        }
      }
      if has_pattern(segment) {
        let directory = if prefix == "" {
          context.cwd
        } else {
          resolve_path(context, prefix)
        }
        let names = @fs.readdir(directory, include_hidden=true, sort=true) catch {
          _ => []
        }
        for name in names {
          if name.has_prefix(".") && !segment.has_prefix(".") {
            continue
          }
          if glob_match(segment, name) {
            next.push(join(name))
          }
        }
      } else {
        let candidate = join(unescape_pattern(segment))
        if @fs.exists(resolve_path(context, candidate)) {
          next.push(candidate)
        }
      }
    }
    candidates = next
  }
  if candidates.is_empty() {
    [unescape_pattern(pattern)]
  } else {
    candidates.sort()
    candidates
  }
}

///|
fn append_value(
  value : String,
  quoted : Bool,
  ifs : String,
  fields : Array[String],
  current : StringBuilder,
  started : Ref[Bool],
) -> Unit {
  if quoted {
    current.write_string(pattern_literal(value))
    started.val = true
    return
  }
  let delimiters = ifs.iter().collect()
  let mut whitespace_separator = false
  for char in value {
    if delimiters.contains(char) {
      let whitespace = char is (' ' | '\t' | '\n')
      if started.val || (!whitespace && !whitespace_separator) {
        fields.push(current.to_string())
        current.reset()
        started.val = false
      }
      if !whitespace {
        whitespace_separator = false
      } else if fields.length() > 0 {
        whitespace_separator = true
      }
    } else {
      current.write_char(char)
      started.val = true
      whitespace_separator = false
    }
  }
}

///|
fn trim_substitution(value : String) -> String {
  let mut end = value.length()
  while end > 0 && value[end - 1] == 10 {
    end -= 1
  }
  value[:end].to_owned()
}

///|
async fn expand_default(
  raw : String,
  context : Context,
) -> String raise ShellError {
  let tokens = lex(raw, fragment=true)
  let values : Array[String] = []
  for token in tokens {
    match token {
      WordToken(word) =>
        values.push(
          expand_word(word, context, split=false, pathname=false).join(""),
        )
      _ => raise ShellError("unsupported operator inside parameter word")
    }
  }
  values.join(" ")
}

///|
async fn expand_word(
  word : Word,
  context : Context,
  split? : Bool = true,
  pathname? : Bool = true,
  preserve_pattern? : Bool = false,
) -> Array[String] raise ShellError {
  let fields : Array[String] = []
  let current = StringBuilder()
  let started = Ref(false)
  let ifs = context.env.get("IFS").unwrap_or(" \t\n")
  let scalar = !split && !preserve_pattern
  for index, part in word.parts {
    match part {
      Text(value) => {
        if index == 0 && (value == "~" || value.has_prefix("~/")) {
          current.write_string(
            pattern_literal(context.env.get("HOME").unwrap_or("~")),
          )
          current.write_string(value[1:].to_owned())
        } else {
          current.write_string(value)
        }
        started.val = true
      }
      QuotedText(value) =>
        append_value(value, true, ifs, fields, current, started)
      Variable(name, quoted) => {
        let value = match context.env.get(name) {
          Some(value) => value
          None =>
            if context.nounset {
              raise ShellError("parameter '\{name}' is unset")
            } else {
              ""
            }
        }
        append_value(value, quoted || scalar, ifs, fields, current, started)
      }
      DefaultVariable(name, operator, raw, quoted) => {
        let original = context.env.get(name)
        let missing = original is None ||
          (operator.has_prefix(":") && original == Some(""))
        let operation = operator[operator.length() - 1:].to_owned()
        let value = if operation == "+" {
          if missing {
            ""
          } else {
            expand_default(raw, context)
          }
        } else if !missing {
          original.unwrap()
        } else if operation == "?" {
          let message = expand_default(raw, context)
          raise ShellError(
            if message == "" {
              "\{name}: parameter is unset"
            } else {
              "\{name}: \{message}"
            },
          )
        } else {
          let fallback = expand_default(raw, context)
          if operation == "=" {
            context.env[name] = fallback
          }
          fallback
        }
        append_value(value, quoted || scalar, ifs, fields, current, started)
      }
      Arithmetic(expression, quoted) =>
        append_value(
          evaluate_arithmetic(expression, context).to_string(),
          quoted || scalar,
          ifs,
          fields,
          current,
          started,
        )
      CommandSubstitution(script, quoted) => {
        let (status, output) = run_substitution(script, context)
        context.substitution_status = Some(status)
        append_value(
          trim_substitution(output),
          quoted || scalar,
          ifs,
          fields,
          current,
          started,
        )
      }
      LengthVariable(name, quoted) =>
        append_value(
          context.env.get(name).unwrap_or("").iter().count().to_string(),
          quoted || scalar,
          ifs,
          fields,
          current,
          started,
        )
      Positional(0, quoted) =>
        append_value(
          context.name,
          quoted || scalar,
          ifs,
          fields,
          current,
          started,
        )
      Positional(index, quoted) =>
        append_value(
          context.positional.get(index - 1).unwrap_or(""),
          quoted || scalar,
          ifs,
          fields,
          current,
          started,
        )
      LastStatus(quoted) =>
        append_value(
          context.last_status.to_string(),
          quoted || scalar,
          ifs,
          fields,
          current,
          started,
        )
      ArgCount(quoted) =>
        append_value(
          context.positional.length().to_string(),
          quoted || scalar,
          ifs,
          fields,
          current,
          started,
        )
      AllArgs(quoted, join) =>
        if join || !split {
          let separator = ifs
            .iter()
            .next()
            .map(ch => ch.to_string())
            .unwrap_or("")
          append_value(
            context.positional.join(separator),
            quoted || scalar,
            ifs,
            fields,
            current,
            started,
          )
        } else {
          for arg_index, argument in context.positional {
            if arg_index > 0 && started.val {
              fields.push(current.to_string())
              current.reset()
              started.val = false
            }
            append_value(argument, quoted, ifs, fields, current, started)
          }
        }
    }
  }
  let empty_at = word.parts is [AllArgs(true, false)] &&
    context.positional.is_empty()
  if started.val || (word.preserve_empty && fields.is_empty() && !empty_at) {
    fields.push(current.to_string())
  }
  let result : Array[String] = []
  for field in fields {
    if pathname {
      result.append(
        expand_glob(field, context) catch {
          err => raise ShellError("pathname expansion: \{err}")
        },
      )
    } else {
      result.push(
        if preserve_pattern {
          field
        } else {
          unescape_pattern(field)
        },
      )
    }
  }
  result
}

///|
async fn expand_path(word : Word, context : Context) -> String raise ShellError {
  match expand_word(word, context) {
    [path] => resolve_path(context, path)
    [] => raise ShellError("redirection path expands to no fields")
    _ => raise ShellError("redirection path expands to multiple fields")
  }
}

///|
fn valid_name(name : String) -> Bool {
  let chars = name.iter().collect()
  !chars.is_empty() && is_name_start(chars[0]) && chars.iter().all(is_name_char)
}

///|
fn split_assignment(value : String) -> (String, String)? {
  guard value.split_once("=") is Some((name, assigned)) &&
    valid_name(name.to_owned()) else {
    return None
  }
  Some((name.to_owned(), assigned.to_owned()))
}

///|
async fn prepare(
  command : Command,
  context : Context,
) -> Prepared raise ShellError {
  context.substitution_status = None
  let argv : Array[String] = []
  let assignments : Map[String, String] = Map([])
  let assignment_context = clone_context(context)
  for word in command.words {
    let assignment = argv.is_empty() &&
      (match word.parts.get(0) {
        Some(Text(value)) => split_assignment(value) is Some(_)
        _ => false
      })
    if assignment {
      let value = expand_word(
        word,
        assignment_context,
        split=false,
        pathname=false,
      ).join("")
      guard split_assignment(value) is Some((name, assigned)) else {
        raise ShellError("invalid assignment")
      }
      assignments[name] = assigned
      assignment_context.env[name] = assigned
      if assignment_context.substitution_status is Some(status) {
        context.substitution_status = Some(status)
      }
    } else {
      argv.append(expand_word(word, context))
    }
  }
  let env : Map[String, String] = Map([])
  for name in context.exported {
    if context.env.get(name) is Some(value) {
      env[name] = value
    }
  }
  env.merge_in_place(assignments)
  let stdin = match command.stdin {
    Some(word) => Some(expand_path(word, context))
    None => None
  }
  let stdout = match command.stdout {
    Some(redirect) =>
      Some((expand_path(redirect.target, context), redirect.append))
    None => None
  }
  let stderr = match command.stderr {
    Some(redirect) =>
      Some((expand_path(redirect.target, context), redirect.append))
    None => None
  }
  {
    argv,
    env,
    assignments,
    stdin,
    stdin_data: command.stdin_data,
    stdout,
    stderr,
  }
}
