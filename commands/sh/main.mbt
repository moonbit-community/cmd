///|
async fn read_script(path : String) -> String {
  if path == "-" {
    @stdio.stdin.read_all().text()
  } else {
    @fs.read_file(path).text()
  }
}

///|
async fn main {
  let raw_arguments = @env.args()
  let arguments = raw_arguments[1:]
  let invocation_name = {
    let name = @path.Path(raw_arguments.get(0).unwrap_or("sh"))
      .basename()
      .to_owned()
    if name.has_suffix(".exe") {
      name[:name.length() - 4].to_owned()
    } else {
      name
    }
  }
  let mut index = 0
  let mut command : String? = None
  let mut script_path : String? = None
  let mut stdin_script = false
  let mut options = true
  while index < arguments.length() && command is None && script_path is None {
    let argument = arguments[index]
    if options && argument == "--" {
      options = false
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
  let (script, name, positional) = match command {
    Some(value) => {
      let shell_name = arguments.get(index).unwrap_or("sh")
      let args = if index < arguments.length() {
        arguments[index + 1:].to_owned()
      } else {
        []
      }
      (value, shell_name, args)
    }
    None =>
      if stdin_script {
        (
          @stdio.stdin.read_all().text(),
          invocation_name,
          arguments[index:].to_owned(),
        )
      } else {
        match script_path {
          Some(path) => (read_script(path), path, arguments[index:].to_owned())
          None => (@stdio.stdin.read_all().text(), "sh", [])
        }
      }
  }
  let status = @shell.run(script, name~, args=positional) catch {
    err => {
      @stdio.stderr.write("sh: \{err}\n")
      2
    }
  }
  if status != 0 {
    @sys.exit(status)
  }
}
