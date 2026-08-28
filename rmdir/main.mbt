///|
async fn remove_directory(
  path : String,
  ignore_non_empty : Bool,
  verbose : Bool,
) -> Bool {
  if ignore_non_empty {
    let entries = @fs.readdir(
      path,
      include_hidden=true,
      include_special=false,
      sort=false,
    )
    if !entries.is_empty() {
      return true
    }
  }
  @fs.rmdir(path)
  if verbose {
    @stdio.stdout.write("rmdir: removed directory '\{path}'\n")
  }
  true
}

///|
async fn main {
  let args = @env.args()[1:]
  let parsed = @cli.parse(args, [
    @cli.flag("parents", short='p'),
    @cli.flag("ignore-fail-on-non-empty", short='I'),
    @cli.flag("verbose", short='v'),
    @cli.flag("help"),
  ]) catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.write("rmdir: \{message}: '\{option}'\n")
      @sys.exit(2)
      return
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.write("Usage: rmdir [-p] [-I] [-v] DIRECTORY...\n")
    return
  }
  let directories = parsed.operands
  let parents = parsed.contains("parents")
  let ignore_non_empty = parsed.contains("ignore-fail-on-non-empty")
  let verbose = parsed.contains("verbose")
  if directories.is_empty() {
    @stdio.stderr.write("rmdir: missing operand\n")
    @sys.exit(1)
    return
  }
  let mut failed = false
  for directory in directories {
    let mut current = directory
    let mut keep_going = true
    while keep_going {
      ignore(
        remove_directory(current, ignore_non_empty, verbose) catch {
          err => {
            @stdio.stderr.write(
              "rmdir: failed to remove '\{current}': \{err}\n",
            )
            failed = true
            break
          }
        },
      )
      if !parents {
        break
      }
      let parent = @fsops.dirname(current)
      keep_going = parent != current &&
        parent != "." &&
        !@fsops.protects_working_directory(parent)
      current = parent
    }
  }
  if failed {
    @sys.exit(1)
  }
}
