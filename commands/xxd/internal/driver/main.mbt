///|
fn help_message() -> String {
  let message = metadata_help().strip_suffix("\n").unwrap().to_owned()
  message
}

///|
async fn execute(parsed : @cli.ParsedArgs, opts : Options) -> Unit {
  let path = parsed.operands.get(0).unwrap_or("-")
  let destination = parsed.operands.get(1).unwrap_or("-")
  let input = if path == "-" {
    None
  } else {
    Some(@fs.open(path, mode=ReadOnly))
  }
  defer (if input is Some(file) { file.close() })
  let target = if destination == "-" {
    None
  } else {
    if @fs.exists(destination) {
      raise CliError(
        3, "xxd: existing output requires a public file-identity API",
      )
    }
    Some(@fs.create(destination, allow_existing=false, permission=438)) catch {
      error => raise CliError(3, "xxd: \{destination}: \{error}")
    }
  }
  defer (if target is Some(file) { file.close() })
  let output : Output = { file: target, position: 0L, }
  if opts.reverse {
    match input {
      Some(file) => reverse_stream(file, output, opts)
      None => reverse_stream(@stdio.stdin, output, opts)
    }
  } else {
    let start = input_offset(input, opts.seek)
    match input {
      Some(file) =>
        if file.kind() == @fs.Regular || file.kind() == @fs.BlockDevice {
          dump_stream(
            file,
            output,
            opts,
            start,
            path,
            positioned_file=Some(file),
          )
        } else {
          if opts.seek is Some(seek) && seek.negative {
            raise CliError(4, "xxd: Sorry, cannot seek.")
          }
          skip_bytes(file, start)
          dump_stream(file, output, opts, start, path)
        }
      None => {
        skip_bytes(@stdio.stdin, start)
        dump_stream(@stdio.stdin, output, opts, start, path)
      }
    }
  }
}

///|
fn parse_args(args : ArrayView[String]) -> @cli.ParsedArgs raise @cli.CliError {
  let args = normalized_args(args)
  @cli.parse(args[:], option_specs())
}

///|
pub async fn run_main() -> Unit {
  let args = @env.args()[1:]
  if args is ["--version"] {
    @stdio.stdout.write("xxd \{MODULE_VERSION}\n")
    return
  }
  let parsed = parse_args(args) catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.write("xxd: \{message}: '\{option}'\n")
      @env.exit(1)
      return
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.write(help_message() + "\n")
    return
  }
  if parsed.operands.length() > 2 {
    @stdio.stderr.write("xxd: extra operand: '\{parsed.operands[2]}'\n")
    @env.exit(1)
    return
  }
  execute(parsed, options(parsed)) catch {
    CliError(status, message) => {
      @stdio.stderr.write(message + "\n")
      @env.exit(status)
    }
    error => {
      @stdio.stderr.write("xxd: \{error}\n")
      @env.exit(2)
    }
  }
}
