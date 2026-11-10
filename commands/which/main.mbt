///|
let command : @argparse.Command = @argparse.Command(
  "which",
  flags=[
    @argparse.FlagArg("all", short='a'),
    @argparse.FlagArg("silent", short='s'),
    @argparse.FlagArg("help"),
    @argparse.FlagArg("version"),
  ],
  positionals=[
    @argparse.PositionArg("operands", num_args=@argparse.ValueRange()),
  ],
  disable_help_flag=true,
  disable_version_flag=true,
  disable_help_subcommand=true,
)

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
    @stdio.stdout.write("which \{MODULE_VERSION}\n")
    return
  }
  let parsed = command.parse(argv=@env.args()[1:], env=Map([])) catch {
    error => {
      let text = error.to_string()
      let line = match text.rev_find("' found") {
        Some(end) => text[:end + 7]
        None => text.split("\n").next().unwrap_or(text[:])
      }
      let (message, option) = match line {
        [.. "error: unexpected argument '--", .. rest] => {
          let spelling = rest.strip_suffix("' found").unwrap_or(rest)
          let name = spelling.split("=").next().unwrap_or(spelling).to_owned()
          let message = if spelling.contains("=") &&
            ["all", "silent", "help", "version"].contains(name) {
            "flag does not accept a value"
          } else {
            "unknown option"
          }
          (message, name)
        }
        [.. "error: unexpected argument '-", .. rest] =>
          (
            "unknown short option",
            rest.strip_suffix("' found").unwrap_or(rest).to_owned(),
          )
        _ => (text, "")
      }
      @stdio.stderr.write("which: \{message}: '\{option}'\n")
      @sys.exit(2)
      return
    }
  }
  let operands = parsed.values.get("operands").unwrap_or([])
  if parsed.flags.contains("help") {
    @stdio.stdout.write(
      "Usage: which [-as] NAME...\nFind executable regular files in PATH. Windows uses PATHEXT.\n  -a, --all     print all matches\n  -s, --silent  return status without output\n      --help    display this help and exit\n      --version display version and exit\n-s/--silent follows this project's explicit quiet-status profile; it does not\nclaim the option surface of every GNU/BSD which implementation.\n",
    )
    return
  }
  if parsed.flags.contains("version") {
    @stdio.stdout.write("which \{MODULE_VERSION}\n")
    return
  }
  if operands.is_empty() {
    @stdio.stderr.write("which: missing command name\n")
    @sys.exit(2)
    return
  }
  let mut missing = false
  for name in operands {
    let matches = candidates(name)
    if matches.is_empty() {
      missing = true
      if !parsed.flags.contains("silent") {
        @stdio.stderr.write("\{name} not found\n")
      }
      continue
    }
    if !parsed.flags.contains("silent") {
      if parsed.flags.contains("all") {
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
