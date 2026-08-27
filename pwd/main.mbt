///|
fn valid_logical_path(path : String) -> Bool {
  if !path.has_prefix("/") {
    return false
  }
  for part in path.split("/") {
    if part == "." || part == ".." {
      return false
    }
  }
  true
}

///|
async fn main {
  let args = @env.args()[1:]
  let mut logical = true
  let mut options = true
  for arg in args {
    if options && arg == "--" {
      options = false
      continue
    }
    if !options {
      @stdio.stderr.write("pwd: unexpected operand: '\{arg}'\n")
      @sys.exit(2)
      return
    }
    match arg {
      "-L" | "--logical" => logical = true
      "-P" | "--physical" => logical = false
      "--help" => {
        @stdio.stdout.write("Usage: pwd [-L|-P]\n")
        return
      }
      "--" => ()
      _ => {
        @stdio.stderr.write("pwd: invalid option: '\{arg}'\n")
        @sys.exit(2)
        return
      }
    }
  }
  guard @env.current_dir() is Some(current) else {
    @stdio.stderr.write("pwd: cannot determine current directory\n")
    @sys.exit(1)
    return
  }
  let selected = if logical {
    match @env.get_env_var("PWD") {
      Some(path) if valid_logical_path(path) => path
      _ => current
    }
  } else {
    @fs.realpath(current) catch {
      err => {
        @stdio.stderr.write("pwd: \{err}\n")
        @sys.exit(1)
        return
      }
    }
  }
  @stdio.stdout.write(selected + "\n")
}
