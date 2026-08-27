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
  let directories : Array[String] = []
  let mut parents = false
  let mut ignore_non_empty = false
  let mut verbose = false
  let mut options = true
  for arg in args {
    if options && arg == "--" {
      options = false
    } else if options && arg == "--parents" {
      parents = true
    } else if options && arg == "--ignore-fail-on-non-empty" {
      ignore_non_empty = true
    } else if options && arg == "--verbose" {
      verbose = true
    } else if options && arg == "--help" {
      @stdio.stdout.write("Usage: rmdir [-p] [-I] [-v] DIRECTORY...\n")
      return
    } else if options && arg.has_prefix("-") && arg != "-" {
      let mut valid = true
      for flag in arg[1:] {
        match flag {
          'p' => parents = true
          'I' => ignore_non_empty = true
          'v' => verbose = true
          _ => valid = false
        }
      }
      if !valid {
        @stdio.stderr.write("rmdir: invalid option: '\{arg}'\n")
        @sys.exit(1)
        return
      }
    } else {
      directories.push(arg)
    }
  }
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
