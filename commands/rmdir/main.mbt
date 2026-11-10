///|
let command : @argparse.Command = @argparse.Command(
  "rmdir",
  flags=[
    @argparse.FlagArg("parents", short='p'),
    @argparse.FlagArg("ignore-fail-on-non-empty", short='I'),
    @argparse.FlagArg("verbose", short='v'),
    @argparse.FlagArg("help"),
  ],
  positionals=[
    @argparse.PositionArg("operands", num_args=@argparse.ValueRange()),
  ],
  disable_help_flag=true,
  disable_version_flag=true,
  disable_help_subcommand=true,
)

///|
fn directory_not_empty(error : @os_error.OSError) -> Bool {
  let @os_error.OSError(code, ..) = error
  // Public OSError carries the host error number: ENOTEMPTY on POSIX,
  // ERROR_DIR_NOT_EMPTY on Windows. EEXIST is the other POSIX spelling.
  error.is_EEXIST() ||
  code ==
  (match @async.platform {
    Linux => 39
    MacOS => 66
    Windows => 145
  })
}

///|
async fn ignored_removal_failure(
  path : String,
  error : @os_error.OSError,
) -> Bool {
  if directory_not_empty(error) {
    return true
  }
  let @os_error.OSError(code, ..) = error
  // GNU also checks nonemptiness after permission, read-only and busy errors.
  // Never let that check turn a non-directory or symbolic link into success.
  let may_mask_nonempty = error.is_EACCES() ||
    (!(@async.platform is Windows) && (code == 1 || code == 16 || code == 30))
  if !may_mask_nonempty {
    return false
  }
  try
    @fs.kind(path, follow_symlink=false) == Directory &&
    !@fs.readdir(path, include_hidden=true, include_special=false, sort=false).is_empty()
  catch {
    _ => false
  }
}

///|
async fn remove_directory(
  path : String,
  ignore_non_empty : Bool,
  verbose : Bool,
) -> Bool {
  if verbose {
    @stdio.stdout.write("rmdir: removing directory, '\{path}'\n")
  }
  @fs.rmdir(path) catch {
    @os_error.OSError(_) as error => {
      if ignore_non_empty && ignored_removal_failure(path, error) {
        return false
      }
      raise error
    }
    error => raise error
  }
  true
}

///|
async fn main {
  let metadata_args = @env.args()[1:]
  if metadata_args.length() == 1 && metadata_args[0] == "--version" {
    @stdio.stdout.write("rmdir \{MODULE_VERSION}\n")
    return
  }
  let args = @env.args()[1:]
  let parsed = command.parse(argv=args, env=Map([])) catch {
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
            ["parents", "ignore-fail-on-non-empty", "verbose", "help"].contains(
              name,
            ) {
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
      @stdio.stderr.write("rmdir: \{message}: '\{option}'\n")
      @sys.exit(1)
      return
    }
  }
  let operands = parsed.values.get("operands").unwrap_or([])
  if parsed.flags.contains("help") {
    @stdio.stdout.write(
      "Usage: rmdir [-p] [-I] [-v] DIRECTORY...\n      --help      display this help and exit\n      --version   display version and exit\n  -p, --parents                  remove empty parents, stopping at the first failure\n  -v, --verbose                  report each removal attempt before it runs\n      --ignore-fail-on-non-empty  suppress only failures attributable to nonemptiness\n  -I is a project short alias of --ignore-fail-on-non-empty, not a GNU option.\nOrdinary option/operand errors exit 1; documented capability refusals retain their own status.\n",
    )
    return
  }
  let directories = operands
  let parents = parsed.flags.contains("parents")
  let ignore_non_empty = parsed.flags.contains("ignore-fail-on-non-empty")
  let verbose = parsed.flags.contains("verbose")
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
      let removed = remove_directory(current, ignore_non_empty, verbose) catch {
        err => {
          @stdio.stderr.write("rmdir: failed to remove '\{current}': \{err}\n")
          failed = true
          break
        }
      }
      if !removed || !parents {
        break
      }
      let parent = @fsops.dirname(current)
      keep_going = parent != current &&
        parent != "." &&
        !protects_working_directory(parent)
      current = parent
    }
  }
  if failed {
    @sys.exit(1)
  }
}
