///|
priv struct CpOptions {
  mut recursive : Bool
  mut no_clobber : Bool
  mut no_target_directory : Bool
  mut verbose : Bool
}

///|
fn apply_short_options(options : CpOptions, arg : String) -> Bool {
  for flag in arg[1:] {
    match flag {
      'R' | 'r' => options.recursive = true
      'f' => options.no_clobber = false
      'n' => options.no_clobber = true
      'T' => options.no_target_directory = true
      'v' => options.verbose = true
      _ => return false
    }
  }
  true
}

///|
async fn main {
  let args = @env.args()[1:]
  let options : CpOptions = {
    recursive: false,
    no_clobber: false,
    no_target_directory: false,
    verbose: false,
  }
  let operands : Array[String] = []
  let mut parsing_options = true
  for arg in args {
    if parsing_options && arg == "--" {
      parsing_options = false
    } else if parsing_options && arg == "--recursive" {
      options.recursive = true
    } else if parsing_options && arg == "--force" {
      options.no_clobber = false
    } else if parsing_options && arg == "--no-clobber" {
      options.no_clobber = true
    } else if parsing_options && arg == "--no-target-directory" {
      options.no_target_directory = true
    } else if parsing_options && arg == "--verbose" {
      options.verbose = true
    } else if parsing_options && arg == "--help" {
      @stdio.stdout.write("Usage: cp [-R] [-f|-n] [-T] [-v] SOURCE... DEST\n")
      return
    } else if parsing_options && arg.has_prefix("-") && arg != "-" {
      if !apply_short_options(options, arg) {
        @stdio.stderr.write("cp: invalid option: '\{arg}'\n")
        @sys.exit(1)
        return
      }
    } else {
      operands.push(arg)
    }
  }
  if operands.length() < 2 {
    @stdio.stderr.write("cp: missing source or destination operand\n")
    @sys.exit(1)
    return
  }
  let destination = operands[operands.length() - 1]
  let sources = operands[0:operands.length() - 1]
  if options.no_target_directory && sources.length() > 1 {
    @stdio.stderr.write("cp: -T cannot be used with multiple sources\n")
    @sys.exit(1)
    return
  }
  let destination_kind = @fsops.kind_if_exists(destination) catch {
    err => {
      @stdio.stderr.write("cp: cannot inspect '\{destination}': \{err}\n")
      @sys.exit(1)
      return
    }
  }
  if sources.length() > 1 && destination_kind != Some(Directory) {
    @stdio.stderr.write(
      "cp: destination is not a directory: '\{destination}'\n",
    )
    @sys.exit(1)
    return
  }
  let mut failed = false
  for source in sources {
    let target = if sources.length() > 1 ||
      (!options.no_target_directory && destination_kind == Some(Directory)) {
      @fsops.join(destination, @fsops.basename(source))
    } else {
      destination
    }
    let copied = @fsops.copy_path(
      source,
      target,
      options.recursive,
      !options.no_clobber,
    ) catch {
      @fsops.FsOpError(message) => {
        @stdio.stderr.write(
          "cp: cannot copy '\{source}' to '\{target}': \{message}\n",
        )
        failed = true
        false
      }
      err => {
        @stdio.stderr.write(
          "cp: cannot copy '\{source}' to '\{target}': \{err}\n",
        )
        failed = true
        false
      }
    }
    if copied && options.verbose {
      @stdio.stdout.write("'\{source}' -> '\{target}'\n")
    }
  }
  if failed {
    @sys.exit(1)
  }
}
