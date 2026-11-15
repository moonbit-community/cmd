///|
fn help_message() -> String {
  let message = metadata_help().strip_suffix("\n").unwrap().to_owned()
  message
}

///|
pub async fn run_main() -> Unit {
  let metadata_args = @env.args()[1:]
  if metadata_args.length() == 1 && metadata_args[0] == "--version" {
    @stdio.stdout.write("hexdump \{MODULE_VERSION}\n")
    return
  }
  let args = normalized_args(@env.args()[1:])
  let parsed = @cli.parse(args[:], option_specs()) catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.write("hexdump: \{message}: '\{option}'\n")
      @sys.exit(1)
      return
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.write(help_message() + "\n")
    return
  }
  if parsed.contains("version") {
    @stdio.stdout.write("hexdump \{MODULE_VERSION}\n")
    return
  }
  let (skip, remaining) = try {
    let skip = parse_count(parsed.last_value("skip").unwrap_or(DEFAULT_SKIP))
    let remaining = match parsed.last_value("length") {
      Some(n) => Some(parse_count(n))
      None => None
    }
    (skip, remaining)
  } catch {
    HexdumpError(message) => {
      @stdio.stderr.write("hexdump: \{message}\n")
      @sys.exit(1)
      return
    }
  }
  let program = program(parsed) catch {
    HexdumpError(message) | @format.FormatError(message) => {
      @stdio.stderr.write("hexdump: \{message}\n")
      @sys.exit(1)
      return
    }
    err => {
      @stdio.stderr.write("hexdump: \{err}\n")
      @sys.exit(1)
      return
    }
  }
  if remaining == Some(0L) || program.block_size == 0 {
    return
  }
  let state : DumpState = {
    program,
    verbose: parsed.contains("no-squeezing"),
    pending: [],
    skip,
    remaining,
    offset: 0L,
    previous: None,
    squeezed: false,
  }
  let sources = if parsed.operands.is_empty() { ["-"] } else { parsed.operands }
  let mut failed = false
  for path in sources {
    if state.skip == 0L && state.remaining == Some(0L) {
      break
    }
    try {
      if path == "-" {
        state.read(@stdio.stdin)
      } else {
        let file = @fs.open(path, mode=ReadOnly)
        defer file.close()
        state.read(file)
      }
    } catch {
      err => {
        @stdio.stderr.write("hexdump: \{path}: \{err}\n")
        failed = true
      }
    }
  }
  if !state.pending.is_empty() {
    @stdio.stdout.write(state.row())
  }
  if state.offset > 0L && program.final_unit is Some(unit) {
    @stdio.stdout.write(@format.render_final(unit, state.offset))
  }
  if failed {
    @sys.exit(1)
  }
}
