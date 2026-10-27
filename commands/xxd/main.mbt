///|
fn help_message() -> String {
  let message =
    #|Usage: xxd [OPTION]... [INFILE [OUTFILE]]
    #|Display bytes or reverse an addressed, plain, or binary dump.
    #|  -a, --autoskip       toggle suppression of zero lines
    #|  -b, --bits           binary digit display
    #|  -e, --little         little-endian groups
    #|  -E, --ebcdic         EBCDIC character display
    #|  -g, --group=N        bytes per group
    #|  -u, --upper          uppercase hexadecimal digits
    #|  -o, --offset=N       add N to displayed offsets
    #|  -p, -ps, --plain     plain hexadecimal display
    #|  -i, --include        C include display
    #|  -r, --reverse        reverse a dump
    #|  -c, --cols=N         bytes per line
    #|  -l, --len=N          maximum input bytes
    #|  -s, --seek=[+][-]N   input seek or reverse address adjustment
    #|  -n, --name=NAME      C include symbol
    #|      --help           display this help and exit
    #|      --version        display version and exit
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
  @cli.parse(args[:], [
    @cli.flag("autoskip", short='a', repeatable=true),
    @cli.flag("bits", short='b', repeatable=true),
    @cli.flag("little", short='e', repeatable=true),
    @cli.flag("ebcdic", short='E', repeatable=true),
    @cli.flag("upper", short='u', repeatable=true),
    @cli.flag("plain", short='p', repeatable=true),
    @cli.flag("include", short='i', repeatable=true),
    @cli.flag("reverse", short='r', repeatable=true),
    @cli.option("group", short='g', repeatable=true),
    @cli.option("offset", short='o', repeatable=true),
    @cli.option("cols", short='c', repeatable=true),
    @cli.option("len", short='l', repeatable=true),
    @cli.option("seek", short='s', repeatable=true),
    @cli.option("name", short='n', repeatable=true),
    @cli.flag("help", short='h'),
  ])
}

///|
async fn main {
  let args = @env.args()[1:]
  if args is ["--version"] {
    @stdio.stdout.write("xxd 0.2.3\n")
    return
  }
  let parsed = parse_args(args) catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.write("xxd: \{message}: '\{option}'\n")
      @sys.exit(2)
      return
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.write(help_message() + "\n")
    return
  }
  if parsed.operands.length() > 2 {
    @stdio.stderr.write("xxd: extra operand: '\{parsed.operands[2]}'\n")
    @sys.exit(2)
    return
  }
  execute(parsed, options(parsed)) catch {
    CliError(status, message) => {
      @stdio.stderr.write(message + "\n")
      @sys.exit(status)
    }
    error => {
      @stdio.stderr.write("xxd: \{error}\n")
      @sys.exit(2)
    }
  }
}
