///|
fn parse_gzip_args(
  args : ArrayView[String],
) -> @args.ParsedArgs raise @args.CliError {
  // The shared specs name every flag; numeric levels 2..8 are short-only.
  for arg in args {
    if arg == "--" {
      break
    }
    for digit in ["2", "3", "4", "5", "6", "7", "8"] {
      if arg == "--" + digit || arg.has_prefix("--" + digit + "=") {
        raise @args.CliError(
          kind=UnknownOption,
          option=arg[2:].to_owned(),
          message="unknown option",
        )
      }
    }
  }
  @args.parse(args, compression_options())
}

///|
fn gzip_level(parsed : @args.ParsedArgs) -> Int32 {
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
    @args.CliError(message~, option~, ..) => {
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
          @gzipops.decode_reader(@stdio.stdin, @stdio.stdout, test_only)
        } else {
          let file = @fs.open(path, mode=ReadOnly)
          defer file.close()
          @gzipops.decode_reader(file, @stdio.stdout, test_only)
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
        @gzipops.encode(@stdio.stdin, @stdio.stdout, level~)
      } else {
        let file = @fs.open(path, mode=ReadOnly)
        defer file.close()
        @gzipops.encode(file, @stdio.stdout, level~)
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
