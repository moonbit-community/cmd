///|
pub fn help(command : String) -> String {
  "Usage: \{command} [OPTION]... [FILE]...\n" +
  "Compress or decompress gzip streams; no FILE or - reads stdin.\n\n" +
  "  -c, --stdout       Write to stdout and keep input files.\n" +
  "  -d, --decompress   Decompress (default for gunzip and zcat).\n" +
  "  -t, --test         Validate compressed input without output.\n" +
  "  -n, --no-name      Omit name/time metadata when compressing.\n" +
  "  -q, --quiet        Suppress trailing-garbage warnings.\n" +
  "      --help         display this help and exit\n" +
  "      --version      display version and exit\n\n" +
  "Named-file compression requires -cn; decompression requires -c.\n" +
  "In-place replacement, saved-name metadata, levels, and recursion are unsupported.\n"
}

///|
pub async fn run(
  command : String,
  args : ArrayView[String],
  version : String,
) -> Int {
  let parsed = @cli.parse(args, [
    @cli.flag("stdout", short='c'),
    @cli.flag("decompress", short='d'),
    @cli.flag("test", short='t'),
    @cli.flag("no-name", short='n'),
    @cli.flag("quiet", short='q'),
    @cli.flag("help"),
    @cli.flag("version"),
  ]) catch {
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
        let data = if path == "-" {
          @stdio.stdin.read_all().binary()
        } else {
          @fs.read_file(path).binary()
        }
        if decode(data, @stdio.stdout, test_only) {
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
        encode(@stdio.stdin, @stdio.stdout)
      } else {
        let file = @fs.open(path, mode=ReadOnly)
        defer file.close()
        encode(file, @stdio.stdout)
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
