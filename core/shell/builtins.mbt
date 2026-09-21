///|
async fn read_builtin(args : Array[String], context : Context) -> Int {
  let raw = args.get(0) == Some("-r")
  let names = if raw { args[1:].to_owned() } else { args }
  if names.is_empty() {
    return builtin_error(context, "read: a variable name is required")
  }
  for name in names {
    if !valid_name(name) {
      return builtin_error(context, "read: invalid name '\{name}'")
    }
  }
  let input = context.input.unwrap_or(@stdio.stdin)
  let result = StringBuilder()
  let escaped_chars : Array[Bool] = []
  let mut terminated = false
  for ;; {
    let line = read_line(input)
    guard line is Some(line) else { break }
    let chars = line.iter().collect()
    let mut index = 0
    let mut continuation = false
    while index < chars.length() {
      if !raw && chars[index] == '\\' && index + 1 < chars.length() {
        if chars[index + 1] == '\n' {
          continuation = true
        } else {
          result.write_char(chars[index + 1])
          escaped_chars.push(true)
        }
        index += 2
      } else if chars[index] == '\n' {
        terminated = true
        index += 1
      } else {
        result.write_char(chars[index])
        escaped_chars.push(false)
        index += 1
      }
    }
    if !continuation {
      break
    }
  }
  let ifs = context.env.get("IFS").unwrap_or(" \t\n").iter().collect()
  let chars = result.to_string().iter().collect()
  let mut cursor = 0
  let mut end = chars.length()
  while end > 0 &&
        !escaped_chars[end - 1] &&
        ifs.contains(chars[end - 1]) &&
        chars[end - 1] is (' ' | '\t' | '\n') {
    end -= 1
  }
  for index, name in names {
    while cursor < end &&
          !escaped_chars[cursor] &&
          ifs.contains(chars[cursor]) &&
          chars[cursor] is (' ' | '\t' | '\n') {
      cursor += 1
    }
    let start = cursor
    if index + 1 == names.length() {
      cursor = end
    } else {
      while cursor < end &&
            (escaped_chars[cursor] || !ifs.contains(chars[cursor])) {
        cursor += 1
      }
    }
    context.env[name] = String::from_array(chars[start:cursor])
    if cursor < end {
      cursor += 1
    }
  }
  if terminated {
    0
  } else {
    1
  }
}

///|
async fn test_expression(args : Array[String], context : Context) -> Bool {
  match args {
    [] => false
    [value] => value != ""
    ["!", .. rest] => !test_expression(rest.to_owned(), context)
    ["(", .. inner, ")"] => test_expression(inner.to_owned(), context)
    [operator, value] => {
      let path = resolve_path(context, value)
      match operator {
        "-n" => value != ""
        "-z" => value == ""
        "-e" => @fs.exists(path)
        "-f" => (@fs.kind(path) catch { _ => Unknown }) == Regular
        "-d" => (@fs.kind(path) catch { _ => Unknown }) == Directory
        "-L" | "-h" =>
          (@fs.kind(path, follow_symlink=false) catch { _ => Unknown }) ==
          SymLink
        "-r" => @fs.can_read(path)
        "-w" => @fs.can_write(path)
        "-x" => @fs.can_execute(path)
        "-s" => (@fs.file_size(path) catch { _ => 0L }) > 0L
        _ => raise ShellError("test: unsupported unary operator '\{operator}'")
      }
    }
    [left, operator, right] =>
      match operator {
        "=" | "==" => left == right
        "!=" => left != right
        "<" => left < right
        ">" => left > right
        "-eq" | "-ne" | "-lt" | "-le" | "-gt" | "-ge" => {
          let a = @string.parse_int64(left) catch {
            _ => raise ShellError("test: integer expected")
          }
          let b = @string.parse_int64(right) catch {
            _ => raise ShellError("test: integer expected")
          }
          match operator {
            "-eq" => a == b
            "-ne" => a != b
            "-lt" => a < b
            "-le" => a <= b
            "-gt" => a > b
            _ => a >= b
          }
        }
        _ => raise ShellError("test: unsupported binary operator '\{operator}'")
      }
    _ => raise ShellError("test: unsupported expression; use shell && or ||")
  }
}

///|
async fn run_builtin(argv : Array[String], context : Context) -> Int? {
  guard argv.get(0) is Some(name) else { return None }
  let args = argv[1:].to_owned()
  match name {
    ":" | "true" => Some(0)
    "false" => Some(1)
    "echo" => {
      let mut start = 0
      while args.get(start) == Some("-n") {
        start += 1
      }
      write_output(
        context,
        args[start:].join(" ") + (if start == 0 { "\n" } else { "" }),
      )
      Some(0)
    }
    "printf" => Some(printf_builtin(args, context))
    "read" => Some(read_builtin(args, context))
    "test" | "[" => {
      let operands = if name == "[" {
        if args.last() != Some("]") {
          return Some(builtin_error(context, "[: missing ']'"))
        }
        args[:args.length() - 1].to_owned()
      } else {
        args
      }
      let result = test_expression(operands, context) catch {
        err => return Some(builtin_error(context, "\{err}"))
      }
      Some(if result { 0 } else { 1 })
    }
    "pwd" => {
      if !args.is_empty() && args != ["-L"] && args != ["-P"] {
        return Some(builtin_error(context, "pwd: unsupported option"))
      }
      let cwd = if args == ["-P"] {
        @fs.realpath(context.cwd)
      } else {
        context.cwd
      }
      write_output(context, cwd + "\n")
      Some(0)
    }
    "cd" => {
      let physical = args.get(0) == Some("-P")
      let args = if physical ||
        args.get(0) == Some("-L") ||
        args.get(0) == Some("--") {
        args[1:].to_owned()
      } else {
        args
      }
      if args.length() > 1 {
        return Some(builtin_error(context, "cd: too many arguments"))
      }
      let destination = match args {
        [] => context.env.get("HOME").unwrap_or("")
        ["-"] => context.env.get("OLDPWD").unwrap_or("")
        [path] => path
        _ => ""
      }
      if destination == "" {
        return Some(builtin_error(context, "cd: destination is not set"))
      }
      let logical = @path.Path(resolve_path(context, destination))
        .normalize()
        .to_string()
      let resolved = @fs.realpath(
        if physical {
          resolve_path(context, destination)
        } else {
          logical
        },
      ) catch {
        err => return Some(builtin_error(context, "cd: \{err}"))
      }
      if @fs.kind(resolved) != Directory {
        return Some(builtin_error(context, "cd: not a directory"))
      }
      let resolved = if physical { resolved } else { logical }
      context.env["OLDPWD"] = context.cwd
      context.cwd = resolved
      context.env["PWD"] = resolved
      context.exported.add("OLDPWD")
      context.exported.add("PWD")
      if args == ["-"] {
        write_output(context, resolved + "\n")
      }
      Some(0)
    }
    "export" => {
      if args.is_empty() || args == ["-p"] {
        let lines : Array[String] = []
        for key in context.exported {
          let value = context.env.get(key).unwrap_or("")
          lines.push(
            "export \{key}='\{value.replace_all(old="'", new="'\\''")}'",
          )
        }
        lines.sort()
        if !lines.is_empty() {
          write_output(context, lines.join("\n") + "\n")
        }
      } else {
        for argument in args {
          match split_assignment(argument) {
            Some((key, value)) => {
              context.env[key] = value
              context.exported.add(key)
            }
            None => {
              if !valid_name(argument) {
                return Some(
                  builtin_error(context, "export: invalid name '\{argument}'"),
                )
              }
              context.exported.add(argument)
            }
          }
        }
      }
      Some(0)
    }
    "unset" => {
      for argument in args {
        if !valid_name(argument) {
          return Some(builtin_error(context, "unset: invalid name"))
        }
        context.env.remove(argument)
        context.exported.remove(argument)
      }
      Some(0)
    }
    "set" => {
      match args {
        ["-e"] => context.errexit = true
        ["+e"] => context.errexit = false
        ["-u"] => context.nounset = true
        ["+u"] => context.nounset = false
        ["--", .. rest] => context.positional = rest.to_owned()
        [] => {
          let lines = context.env.to_array().map(pair => "\{pair.0}=\{pair.1}")
          lines.sort()
          write_output(context, lines.join("\n") + "\n")
        }
        _ => return Some(builtin_error(context, "set: unsupported option"))
      }
      Some(0)
    }
    "shift" => {
      let amount = match args {
        [] => 1
        [value] => @string.parse_int(value) catch { _ => -1 }
        _ => -1
      }
      if amount < 0 || amount > context.positional.length() {
        return Some(builtin_error(context, "shift: count out of range"))
      }
      context.positional = context.positional[amount:].to_owned()
      Some(0)
    }
    "return" | "exit" => {
      if args.length() > 1 {
        return Some(builtin_error(context, "\{name}: too many arguments"))
      }
      if name == "return" && context.call_depth == 0 {
        return Some(
          builtin_error(context, "return: outside function or sourced script"),
        )
      }
      let value = args.get(0).unwrap_or(context.last_status.to_string())
      let status = @string.parse_int(value) catch {
        _ =>
          return Some(
            builtin_error(context, "\{name}: numeric argument required"),
          )
      }
      let status = (status % 256 + 256) % 256
      if name == "exit" {
        context.exited = true
        context.exit_status = status
      } else {
        context.return_status = Some(status)
      }
      Some(status)
    }
    "break" | "continue" => {
      if !args.is_empty() && args != ["1"] {
        return Some(
          builtin_error(context, "\{name}: only one loop level is supported"),
        )
      }
      if context.loop_depth == 0 {
        return Some(builtin_error(context, "\{name}: outside a loop"))
      }
      if name == "break" {
        context.break_loop = true
      } else {
        context.continue_loop = true
      }
      Some(0)
    }
    "." => {
      guard args.get(0) is Some(filename) else {
        return Some(builtin_error(context, ".: filename required"))
      }
      let mut path = resolve_path(context, filename)
      if !filename.contains("/") {
        for directory in context.env.get("PATH").unwrap_or("").split(":") {
          let candidate = resolve_path(
            context,
            if directory == "" {
              filename
            } else {
              directory.to_owned() + "/" + filename
            },
          )
          if @fs.exists(candidate) {
            path = candidate
            break
          }
        }
      }
      let source = @fs.read_file(path).text() catch {
        err => return Some(builtin_error(context, ".: \{err}"))
      }
      let jobs = parse(source)
      let previous_args = context.positional
      let previous_return = context.return_status
      if args.length() > 1 {
        context.positional = args[1:].to_owned()
      }
      context.return_status = None
      context.call_depth += 1
      defer {
        context.positional = previous_args
        context.return_status = previous_return
        context.call_depth -= 1
      }
      let status = run_jobs(jobs, context)
      Some(context.return_status.unwrap_or(status))
    }
    "exec" =>
      Some(
        builtin_error(
          context, "exec: process replacement requires an upstream public API",
        ),
      )
    "fg" | "bg" | "jobs" | "wait" =>
      Some(builtin_error(context, "\{name}: job control is not supported"))
    _ => None
  }
}
