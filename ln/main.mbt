///|
async fn create_link(
  target : String,
  link_path : String,
  force : Bool,
  verbose : Bool,
) -> Bool {
  match @fsops.kind_if_exists(link_path) {
    Some(Directory) =>
      raise @fsops.FsOpError("refusing to replace directory: '\{link_path}'")
    Some(_) if force => @fsops.remove_path(link_path, false)
    Some(_) => raise @fsops.FsOpError("destination exists: '\{link_path}'")
    None => ()
  }
  @fs.symlink(link_path, target~)
  if verbose {
    @stdio.stdout.write("'\{link_path}' -> '\{target}'\n")
  }
  true
}

///|
async fn main {
  let args = @env.args()[1:]
  let operands : Array[String] = []
  let mut symbolic = false
  let mut force = false
  let mut no_target_directory = false
  let mut verbose = false
  let mut options = true
  for arg in args {
    if options && arg == "--" {
      options = false
    } else if options && arg == "--symbolic" {
      symbolic = true
    } else if options && arg == "--force" {
      force = true
    } else if options && arg == "--no-target-directory" {
      no_target_directory = true
    } else if options && arg == "--verbose" {
      verbose = true
    } else if options && arg == "--help" {
      @stdio.stdout.write("Usage: ln -s [-f] [-T] [-v] TARGET LINK_NAME\n")
      return
    } else if options && arg.has_prefix("-") && arg != "-" {
      let mut valid = true
      for flag in arg[1:] {
        match flag {
          's' => symbolic = true
          'f' => force = true
          'n' | 'T' => no_target_directory = true
          'v' => verbose = true
          _ => valid = false
        }
      }
      if !valid {
        @stdio.stderr.write("ln: invalid option: '\{arg}'\n")
        @sys.exit(2)
        return
      }
    } else {
      operands.push(arg)
    }
  }
  if !symbolic {
    @stdio.stderr.write(
      "ln: hard links are unavailable in the portable Moonrun filesystem API; use -s\n",
    )
    @sys.exit(2)
    return
  }
  if operands.length() < 2 {
    @stdio.stderr.write("ln: missing operand\n")
    @sys.exit(1)
    return
  }
  let destination = operands[operands.length() - 1]
  let targets = operands[0:operands.length() - 1]
  if no_target_directory && targets.length() > 1 {
    @stdio.stderr.write("ln: -T cannot be used with multiple targets\n")
    @sys.exit(1)
    return
  }
  let destination_kind = @fsops.kind_if_exists(destination) catch {
    err => {
      @stdio.stderr.write("ln: cannot inspect '\{destination}': \{err}\n")
      @sys.exit(1)
      return
    }
  }
  if targets.length() > 1 && destination_kind != Some(Directory) {
    @stdio.stderr.write("ln: target is not a directory: '\{destination}'\n")
    @sys.exit(1)
    return
  }
  let mut failed = false
  for target in targets {
    let link_path = if targets.length() > 1 ||
      (!no_target_directory && destination_kind == Some(Directory)) {
      @fsops.join(destination, @fsops.basename(target))
    } else {
      destination
    }
    ignore(
      create_link(target, link_path, force, verbose) catch {
        err => {
          @stdio.stderr.write("ln: failed to create '\{link_path}': \{err}\n")
          failed = true
          false
        }
      },
    )
  }
  if failed {
    @sys.exit(1)
  }
}
