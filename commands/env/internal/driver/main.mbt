///|
fn split_assignment(value : String) -> (String, String)? {
  let pieces : Array[String] = value.split("=").map(v => v.to_owned()).collect()
  if pieces.length() < 2 {
    return None
  }
  let key = pieces[0]
  if key == "" {
    return None
  }
  Some((key, pieces[1:].join("=")))
}

///|
fn directory_in(cwd : String, directory : String) -> String {
  if directory == "" || @path.Path(directory).is_absolute() {
    directory
  } else {
    // Path.join normalizes parent components before filesystem lookup.
    cwd + "/" + directory
  }
}

///|
#cfg(target="native")
const NATIVE_CHILD_ENVIRONMENT : Bool = true

///|
#cfg(target="wasm")
const NATIVE_CHILD_ENVIRONMENT : Bool = false

///|
fn empty_child_environment_unavailable() -> Bool {
  NATIVE_CHILD_ENVIRONMENT && @async.platform is Windows
}

///|
pub async fn run_main() -> Unit {
  let metadata_args = @core_env.args()[1:]
  if metadata_args.length() == 1 && metadata_args[0] == "--version" {
    @stdio.stdout.write("env \{MODULE_VERSION}\n")
    return
  }
  let mut args = @core_env.args()[1:].to_owned()
  let original_environment = @process.default_environment()
  let mut ignore_environment = false
  let mut null_output = false
  let base_cwd = @core_env.current_dir().unwrap_or(".")
  let mut cwd = base_cwd
  let mut chdir_requested = false
  let unset : Array[String] = []
  let assignments : Array[(String, String)] = []
  let command_args : Array[String] = []
  let mut command : String? = None
  let mut options = true
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    if options &&
      command is None &&
      arg.length() > 2 &&
      arg.has_prefix("-") &&
      !arg.has_prefix("--") &&
      arg[1] is ('i' | '0') {
      args = args[:i].to_owned() +
        ["-" + arg[1:2].to_owned(), "-" + arg[2:].to_owned()] +
        args[i + 1:].to_owned()
      continue
    }
    if command is Some(_) {
      command_args.push(arg)
    } else if options && arg == "--" {
      options = false
    } else if options && metadata_option_matches("help", arg) {
      @stdio.stdout.write(metadata_help())
      return
    } else if options && metadata_option_matches("version", arg) {
      @stdio.stdout.write("env \{MODULE_VERSION}\n")
      return
    } else if options && metadata_option_matches("ignore-environment", arg) {
      ignore_environment = true
    } else if options && arg == "-" {
      ignore_environment = true
    } else if options && metadata_option_matches("null", arg) {
      null_output = true
    } else if options &&
      (
        metadata_option_matches("split-string", arg) ||
        arg.has_prefix("--split-string=") ||
        (arg.has_prefix("-S") && arg.length() > 2)
      ) {
      let separate = metadata_option_matches("split-string", arg)
      let (value, consumed) = if separate {
        if i + 1 == args.length() {
          let description = if arg == "-S" {
            "option requires an argument -- 'S'"
          } else {
            "option '--split-string' requires an argument"
          }
          @stdio.stderr.write(
            "env: \{description}\nTry 'env --help' for more information.\n",
          )
          @core_env.exit(125)
          return
        }
        (args[i + 1], 2)
      } else if arg.has_prefix("--") {
        (arg[15:].to_owned(), 1)
      } else {
        (arg[2:].to_owned(), 1)
      }
      let words = split_string(value, original_environment) catch {
        SplitError(message) => {
          @stdio.stderr.write("env: \{message}\n")
          @core_env.exit(125)
          return
        }
      }
      args = args[:i].to_owned() + words + args[i + consumed:].to_owned()
      continue
    } else if options && metadata_option_matches("chdir", arg) {
      if i + 1 >= args.length() {
        @stdio.stderr.write("env: option requires an argument: \{arg}\n")
        @core_env.exit(125)
        return
      }
      i += 1
      chdir_requested = true
      cwd = directory_in(base_cwd, args[i])
    } else if options && arg.has_prefix("--chdir=") {
      chdir_requested = true
      cwd = directory_in(base_cwd, arg[8:].to_owned())
    } else if options && arg.has_prefix("-C") && arg.length() > 2 {
      chdir_requested = true
      cwd = directory_in(base_cwd, arg[2:].to_owned())
    } else if options && metadata_option_matches("unset", arg) {
      if i + 1 >= args.length() {
        @stdio.stderr.write("env: option requires an argument: \{arg}\n")
        @core_env.exit(125)
        return
      }
      i += 1
      unset.push(args[i])
    } else if options && arg.has_prefix("--unset=") {
      unset.push(arg[8:].to_owned())
    } else if options && arg.has_prefix("-u") && arg.length() > 2 {
      unset.push(arg[2:].to_owned())
    } else if options && split_assignment(arg) is Some((key, value)) {
      assignments.push((key, value))
      options = false
    } else if !options && split_assignment(arg) is Some((key, value)) {
      assignments.push((key, value))
    } else if arg.has_prefix("=") {
      @stdio.stderr.write(
        "env: invalid environment variable assignment: \{arg}\n",
      )
      @core_env.exit(125)
      return
    } else if arg.has_prefix("-") && options {
      @stdio.stderr.write("env: unsupported option: \{arg}\n")
      @core_env.exit(125)
      return
    } else {
      command = Some(arg)
    }
    i += 1
  }
  let variables : Map[String, String] = if ignore_environment {
    Map([])
  } else {
    original_environment
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
      for line in lines {
        @stdio.stdout.write(line)
        @stdio.stdout.write(if null_output { "\u0000" } else { "\n" })
      }
    }
    Some(program) => {
      if null_output {
        @stdio.stderr.write(
          "env: cannot specify --null (-0) with command\nTry 'env --help' for more information.\n",
        )
        @core_env.exit(125)
        return
      }
      if chdir_requested {
        let cwd_kind = @fs.kind(cwd) catch {
          err => {
            @stdio.stderr.write(
              "env: cannot change directory to '\{cwd}': \{err}\n",
            )
            @core_env.exit(125)
            return
          }
        }
        match cwd_kind {
          Directory => ()
          _ => {
            @stdio.stderr.write(
              "env: cannot change directory to '\{cwd}': not a directory\n",
            )
            @core_env.exit(125)
            return
          }
        }
      }
      if variables.is_empty() && empty_child_environment_unavailable() {
        @stdio.stderr.write(
          "env: unsupported capability: Windows Native empty child environment\n",
        )
        @core_env.exit(125)
        return
      }
      let context : @process.ExecutionContext = { cwd, env: variables, }
      let code = @process.run(@process.child(program, command_args, context~)) catch {
        err => {
          @stdio.stderr.write("env: cannot run '\{program}': \{err}\n")
          let missing = match err {
            @os_error.OSError(_) as os => os.is_ENOENT()
            _ => false
          }
          let explicit_path = @path.Path(program).is_absolute() ||
            program.contains("/") ||
            program.contains("\\")
          let existing_directory = if missing && explicit_path {
            let kind = @fs.kind(program) catch { _ => Regular }
            kind == Directory
          } else {
            false
          }
          @core_env.exit(
            @process.launch_failure_status(
              if missing && !existing_directory {
                CommandNotFound
              } else {
                CommandNotInvokable
              },
            ),
          )
          return
        }
      }
      if code != 0 {
        @core_env.exit(code)
      }
    }
  }
}
