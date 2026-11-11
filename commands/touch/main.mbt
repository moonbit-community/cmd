///|
let command : @argparse.Command = @argparse.Command(
  "touch",
  flags=[
    @argparse.FlagArg("no-create", short='c'),
    @argparse.FlagArg("access-time", short='a'),
    @argparse.FlagArg("modification-time", short='m'),
    @argparse.FlagArg("help"),
  ],
  options=[
    @argparse.OptionArg(
      "date",
      short='d',
      action=Append,
      allow_hyphen_values=true,
    ),
    @argparse.OptionArg(
      "reference",
      short='r',
      action=Append,
      allow_hyphen_values=true,
    ),
    @argparse.OptionArg(
      "stamp",
      short='t',
      action=Append,
      allow_hyphen_values=true,
    ),
    @argparse.OptionArg("time", action=Append, allow_hyphen_values=true),
  ],
  positionals=[
    @argparse.PositionArg("operands", num_args=@argparse.ValueRange()),
  ],
  disable_help_flag=true,
  disable_version_flag=true,
  disable_help_subcommand=true,
)

///|
async fn main {
  let metadata_args = @env.args()[1:]
  if metadata_args.length() == 1 && metadata_args[0] == "--version" {
    @stdio.stdout.write("touch \{MODULE_VERSION}\n")
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
            ["no-create", "access-time", "modification-time", "help"].contains(
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
        [.. "error: a value is required for '", .. rest] => {
          let spelling = rest
            .strip_suffix("' but none was supplied")
            .unwrap_or(rest)
          let name = match spelling {
            "-d" => "date"
            "-r" => "reference"
            "-t" => "stamp"
            _ => spelling.strip_prefix("--").unwrap_or(spelling).to_owned()
          }
          ("option requires a value", name)
        }
        _ => (text, "")
      }
      @stdio.stderr.write("touch: \{message}: '\{option}'\n")
      @sys.exit(1)
      return
    }
  }
  let operands = parsed.values.get("operands").unwrap_or([])
  if parsed.flags.contains("help") {
    @stdio.stdout.write(
      "Usage: touch [-c] [-a|-m] [-d STRING|-r FILE|-t STAMP] FILE...\n      --help      display this help and exit\n      --version   display version and exit\nExisting files are unsupported, including with -c. This command creates missing files only; it cannot update timestamps.\nNote: -a/-m/-d/-r/-t are recognized but unavailable without a portable timestamp setter.\nRejection aliases --access-time (-a), --modification-time (-m) and --stamp (-t)\nrequest unavailable timestamp-setting capabilities and fail before mutation.\nOrdinary option/operand errors exit 1; documented capability refusals retain their own status.\n",
    )
    return
  }
  let files = operands
  let no_create = parsed.flags.contains("no-create")
  if files.is_empty() {
    @stdio.stderr.write("touch: missing file operand\n")
    @sys.exit(1)
    return
  }
  if parsed.flags.contains("access-time") ||
    parsed.flags.contains("modification-time") ||
    parsed.values.contains("date") ||
    parsed.values.contains("reference") ||
    parsed.values.contains("stamp") ||
    parsed.values.contains("time") {
    @stdio.stderr.write(
      "touch: selecting or setting timestamps is unavailable in the portable filesystem API\n",
    )
    @sys.exit(1)
    return
  }
  let mut failed = false
  for path in files {
    let exists = @fs.exists(path) catch {
      err => {
        @stdio.stderr.write("touch: cannot inspect '\{path}': \{err}\n")
        failed = true
        continue
      }
    }
    if !exists && no_create {
      continue
    }
    if !exists {
      let file = @fs.open(
        path,
        mode=WriteOnly,
        create_mode=CreateNew,
        permission=0o666,
      ) catch {
        err => {
          @stdio.stderr.write("touch: cannot create '\{path}': \{err}\n")
          failed = true
          continue
        }
      }
      file.close()
    } else {
      @stdio.stderr.write(
        "touch: cannot update '\{path}': timestamp setters are unavailable in moonbitlang/async 0.22.9\n",
      )
      failed = true
    }
  }
  if failed {
    @sys.exit(1)
  }
}
