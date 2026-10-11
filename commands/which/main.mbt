///|
fn path_separator() -> String {
  if @platform.is_windows() {
    ";"
  } else {
    ":"
  }
}

///|
fn has_separator(name : String) -> Bool {
  name.contains("/") || name.contains("\\")
}

///|
async fn regular(path : String) -> Bool {
  (@fs.kind(path) catch { _ => Unknown }) == Regular
}

///|
async fn candidates(name : String) -> Array[String] {
  if has_separator(name) {
    return if regular(name) { [name] } else { [] }
  }
  let path = @env.get_env_var("PATH").unwrap_or("")
  let result : Array[String] = []
  for directory in path.split(path_separator()) {
    let root = directory.to_owned()
    let base = if root == "" { "." } else { root }
    let candidate = @path.Path(base).join(Path(name)).to_string()
    if regular(candidate) {
      result.push(candidate)
    }
  }
  result
}

///|
async fn main {
  let parsed = @cli.parse(@env.args()[1:], [
    @cli.flag("all", short='a'),
    @cli.flag("silent", short='s'),
    @cli.flag("help"),
    @cli.flag("version"),
  ]) catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.write("which: \{message}: '\{option}'\n")
      @sys.exit(2)
      return
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.write(
      "Usage: which [-as] NAME...\nResolve command names against PATH using regular-file presence.\n",
    )
    return
  }
  if parsed.contains("version") {
    @stdio.stdout.write("which (cli) \{command_version}\n")
    return
  }
  if parsed.operands.is_empty() {
    @stdio.stderr.write("which: missing command name\n")
    @sys.exit(2)
    return
  }
  let mut missing = false
  for name in parsed.operands {
    let matches = candidates(name)
    if matches.is_empty() {
      missing = true
      if !parsed.contains("silent") {
        @stdio.stderr.write("\{name} not found\n")
      }
      continue
    }
    if !parsed.contains("silent") {
      if parsed.contains("all") {
        for match_path in matches {
          @stdio.stdout.write(match_path + "\n")
        }
      } else {
        @stdio.stdout.write(matches[0] + "\n")
      }
    }
  }
  if missing {
    @sys.exit(1)
  }
}
