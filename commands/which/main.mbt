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
  name.contains("/") ||
  (@platform.is_windows() && (name.contains("\\") || name.contains(":")))
}

///|
async fn executable(path : String) -> Bool {
  (@fs.kind(path) catch { _ => Unknown }) == Regular &&
  (@fs.can_execute(path) catch { _ => false })
}

///|
fn executable_names(name : String) -> Array[String] {
  if !@platform.is_windows() {
    return [name]
  }
  let extensions = @env.get_env_var("PATHEXT")
    .unwrap_or(".COM;.EXE;.BAT;.CMD")
    .split(";")
    .filter(value => value.has_prefix(".") && value.length() > 1)
    .map(value => value.to_owned())
    .collect()
  if extensions.any(extension => {
      name.to_lower().has_suffix(extension.to_lower())
    }) {
    [name]
  } else {
    extensions.map(extension => name + extension)
  }
}

///|
async fn candidates(name : String) -> Array[String] {
  if has_separator(name) {
    let found : Array[String] = []
    for candidate in executable_names(name) {
      if executable(candidate) {
        found.push(candidate)
      }
    }
    return found
  }
  let path = @env.get_env_var("PATH").unwrap_or("")
  let result : Array[String] = []
  for directory in path.split(path_separator()) {
    let root = directory.to_owned()
    let base = if root == "" { "." } else { root }
    for filename in executable_names(name) {
      let candidate = if base == "." {
        "." + @path.sep.to_string() + filename
      } else {
        @path.Path(base).join(Path(filename)).to_string()
      }
      if executable(candidate) {
        result.push(candidate)
      }
    }
  }
  result
}

///|
async fn main {
  let metadata_args = @env.args()[1:]
  if metadata_args.length() == 1 && metadata_args[0] == "--version" {
    @stdio.stdout.write("which 0.1.2\n")
    return
  }
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
      "Usage: which [-as] NAME...\nFind executable regular files in PATH. Windows uses PATHEXT.\n  -a, --all     print all matches\n  -s, --silent  return status without output\n      --help    display this help and exit\n      --version display version and exit\n",
    )
    return
  }
  if parsed.contains("version") {
    @stdio.stdout.write("which \{command_version}\n")
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
