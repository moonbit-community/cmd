///|
pub fn help(command : String) -> String {
  "Usage: \{command} [OPTION]... [FILE]...\n" +
  "Compress or decompress gzip streams; no FILE or - reads stdin.\n" +
  "Input and output use bounded buffers.\n\n" +
  "  -c, --stdout       Write to stdout and keep input files.\n" +
  "  -d, --decompress   Decompress (default for gunzip and zcat).\n" +
  "  -t, --test         Validate compressed input without output.\n" +
  "  -n, --no-name      Omit name/time metadata when compressing.\n" +
  "  -q, --quiet        Suppress trailing-garbage warnings.\n" +
  "  -1 .. -9           Compression level (default: -6; last option wins).\n" +
  "      --fast         Same as -1.\n" +
  "      --best         Same as -9.\n" +
  "      --help         display this help and exit\n" +
  "      --version      display version and exit\n\n" +
  "Named-file compression requires -cn; decompression requires -c.\n" +
  "In-place replacement, saved-name metadata and recursion are unsupported.\n"
}

///|
fn parse_gzip_args(
  args : ArrayView[String],
) -> @cli.ParsedArgs raise @cli.CliError {
  // The shared specs name every flag; numeric levels 2..8 are short-only.
  for arg in args {
    if arg == "--" {
      break
    }
    for digit in ["2", "3", "4", "5", "6", "7", "8"] {
      if arg == "--" + digit || arg.has_prefix("--" + digit + "=") {
        raise @cli.CliError(
          kind=UnknownOption,
          option=arg[2:].to_owned(),
          message="unknown option",
        )
      }
    }
  }
  @cli.parse(args, [
    @cli.flag("stdout", short='c'),
    @cli.flag("decompress", short='d'),
    @cli.flag("test", short='t'),
    @cli.flag("no-name", short='n'),
    @cli.flag("quiet", short='q'),
    @cli.flag("fast", short='1'),
    @cli.flag("2", short='2'),
    @cli.flag("3", short='3'),
    @cli.flag("4", short='4'),
    @cli.flag("5", short='5'),
    @cli.flag("6", short='6'),
    @cli.flag("7", short='7'),
    @cli.flag("8", short='8'),
    @cli.flag("best", short='9'),
    @cli.flag("help"),
    @cli.flag("version"),
  ])
}

///|
fn gzip_level(parsed : @cli.ParsedArgs) -> Int32 {
  match
    parsed.last_occurrence(["fast", "2", "3", "4", "5", "6", "7", "8", "best"]) {
    Some("fast") => 1
    Some("2") => 2
    Some("3") => 3
    Some("4") => 4
    Some("5") => 5
    Some("7") => 7
    Some("8") => 8
    Some("best") => 9
    _ => 6
  }
}

///|
pub async fn run(
  command : String,
  args : ArrayView[String],
  version : String,
) -> Int32 {
  let parsed = parse_gzip_args(args) catch {
    @cli.CliError(message~, option~, ..) => {
      @stdio.stderr.write("\{command}: \{message}: '\{option}'\n")
      return 2
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.write(help(command))
    return 0
  }
  if parsed.contains("version") {
    @stdio.stdout.write("\{command} \{version}\n")
    return 0
  }
  let level = gzip_level(parsed)
  let test_only = parsed.contains("test")
  let decompress = command != "gzip" ||
    parsed.contains("decompress") ||
    test_only
  let named = parsed.operands.any(path => path != "-")
  if named && !test_only && command != "zcat" && !parsed.contains("stdout") {
    @stdio.stderr.write(
      "\{command}: in-place replacement is unsupported; use -c\n",
    )
    return 2
  }
  if named && !decompress && !parsed.contains("no-name") {
    @stdio.stderr.write(
      "\{command}: saved filename metadata is unsupported; use -n\n",
    )
    return 2
  }
  let paths = if parsed.operands.is_empty() { ["-"] } else { parsed.operands }
  let mut status = 0
  for path in paths {
    try {
      if decompress {
        let trailing = if path == "-" {
          decode_reader(@stdio.stdin, @stdio.stdout, test_only)
        } else {
          let file = @fs.open(path, mode=ReadOnly)
          defer file.close()
          decode_reader(file, @stdio.stdout, test_only)
        }
        if trailing {
          if !parsed.contains("quiet") {
            @stdio.stderr.write(
              "\{command}: \{path}: decompression OK, trailing garbage ignored\n",
            )
          }
          if status == 0 {
            status = 2
          }
        }
      } else if path == "-" {
        encode(@stdio.stdin, @stdio.stdout, level~)
      } else {
        let file = @fs.open(path, mode=ReadOnly)
        defer file.close()
        encode(file, @stdio.stdout, level~)
      }
    } catch {
      err => {
        @stdio.stderr.write("\{command}: \{path}: \{err}\n")
        status = 1
      }
    }
  }
  status
}
