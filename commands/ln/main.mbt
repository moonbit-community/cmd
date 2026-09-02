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
  let parsed = @cli.parse(args, [
    @cli.flag("symbolic", short='s'),
    @cli.flag("force", short='f'),
    @cli.flag("no-target-directory", short='T'),
    @cli.flag("no-target-directory", short='n'),
    @cli.flag("verbose", short='v'),
    @cli.flag("help"),
  ]) catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.write("ln: \{message}: '\{option}'\n")
      @sys.exit(2)
      return
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.write(
      "Usage: ln -s [-f] [-T] [-v] TARGET LINK_NAME\nNote: hard links are unavailable in the portable filesystem API.\n",
    )
    return
  }
  let operands = parsed.operands
  let symbolic = parsed.contains("symbolic")
  let force = parsed.contains("force")
  let no_target_directory = parsed.contains("no-target-directory")
  let verbose = parsed.contains("verbose")
  if operands.length() < 2 {
    @stdio.stderr.write("ln: missing operand\n")
    @sys.exit(1)
    return
  }
  if !symbolic {
    @stdio.stderr.write(
      "ln: hard links are unavailable in the portable filesystem API; use -s\n",
    )
    @sys.exit(1)
    return
  }
  if !@platform.symbolic_links_supported() {
    @stdio.stderr.write("ln: unsupported capability: symbolic links\n")
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
        @fsops.FsOpError(message) => {
          @stdio.stderr.write(
            "ln: failed to create '\{link_path}': \{message}\n",
          )
          failed = true
          false
        }
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
