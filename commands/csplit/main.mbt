///|
struct Output {
  prefix : String
  width : Int
  quiet : Bool
  elide : Bool
  paths : Array[String]
}

///|
async fn Output::write(self : Output, content : BytesView) -> Unit {
  if self.elide && content.is_empty() {
    return
  }
  let number = self.paths.length().to_string()
  let suffix = String::make(@cmp.maximum(0, self.width - number.length()), '0') +
    number
  let path = self.prefix + suffix
  if @fs.exists(path) {
    fail("existing output is unsupported: \{path}")
  }
  let file = @fs.create(path, allow_existing=false)
  self.paths.push(path)
  defer file.close()
  file.write(content)
  if !self.quiet {
    @stdio.stdout.write("\{content.length()}\n")
  }
}

///|
async fn partition(
  data : Bytes,
  controls : Array[Control],
  output : Output,
) -> Unit {
  let starts = line_starts(data)
  let count = starts.length() - 1
  let mut first = 0
  let mut searched = -1
  for control in controls {
    let mut repetition = 0
    while control.repeats is None ||
          (control.repeats is Some(n) && repetition <= n) {
      let (cut, ignored) = match control.pattern {
        Line(number) => {
          let target = number.to_int64() * (repetition.to_int64() + 1L) - 1L
          if target >= count.to_int64() {
            output.write(data[starts[first]:])
            fail("line number out of range")
          }
          let target = @cmp.maximum(first, target.to_int())
          searched = @cmp.maximum(searched, target - 1)
          (target, false)
        }
        Expression(regex, offset, ignored) => {
          let mut found = None
          let begin = @cmp.maximum(first, searched + 1)
          for line in begin..<count {
            if regex.execute(line_text(data, starts[line], starts[line + 1]))
              is Some(_) {
              found = Some(line)
              break
            }
          }
          match found {
            None => {
              if !ignored {
                output.write(data[starts[first]:])
              }
              if control.repeats is None {
                return
              }
              fail("match not found")
            }
            Some(line) => {
              let target = line.to_int64() + offset.to_int64()
              if target < first.to_int64() || target > count.to_int64() {
                if !ignored && target > count.to_int64() {
                  output.write(data[starts[first]:])
                }
                fail("line number out of range")
              }
              searched = @cmp.maximum(line, target.to_int())
              (target.to_int(), ignored)
            }
          }
        }
      }
      if !ignored {
        output.write(data[starts[first]:starts[cut]])
      }
      first = cut
      repetition += 1
    }
  }
  output.write(data[starts[first]:])
}

///|
fn help_message() -> String {
  let message =
    #|Usage: csplit [OPTION]... FILE PATTERN...
    #|Split FILE (- for stdin) at line numbers or basic regular expressions.
    #|Patterns: NUMBER, /REGEXP/[OFFSET], %REGEXP%[OFFSET], {N}, {*}
    #|
    #|  -f, --prefix=PREFIX      Use PREFIX instead of xx.
    #|  -n, --digits=NUMBER      Use at least NUMBER suffix digits (default 2).
    #|  -s, --silent             Suppress output byte counts.
    #|  -q, --quiet              Same as --silent.
    #|  -k, --keep-files         Keep created fragments after a split error.
    #|  -z, --elide-empty-files  Omit empty output fragments.
    #|      --help               display this help and exit
    #|      --version            display version and exit
    #|
    #|Existing output paths, custom suffix formats, backreferences, non-ASCII
    #|regex patterns, and locale-specific matching are unsupported.
  message
}

///|
async fn main {
  let metadata_args = @env.args()[1:]
  if metadata_args.length() == 1 && metadata_args[0] == "--version" {
    @stdio.stdout.write("csplit 0.1.0\n")
    return
  }
  let parsed = @cli.parse(@env.args()[1:], [
    @cli.option("prefix", short='f'),
    @cli.option("digits", short='n'),
    @cli.flag("silent", short='s'),
    @cli.flag("quiet", short='q'),
    @cli.flag("keep-files", short='k'),
    @cli.flag("elide-empty-files", short='z'),
    @cli.flag("help"),
    @cli.flag("version"),
  ]) catch {
    @cli.CliError(message~, option~, ..) => {
      @stdio.stderr.write("csplit: \{message}: '\{option}'\n")
      @sys.exit(2)
      return
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.write(help_message() + "\n")
    return
  }
  if parsed.contains("version") {
    @stdio.stdout.write("csplit 0.1.0\n")
    return
  }
  let (controls, width) = try {
    guard parsed.operands.length() >= 2 else {
      fail("FILE and PATTERN are required")
    }
    let width = @string.parse_int(parsed.last_value("digits").unwrap_or("2"))
    guard width >= 0 && width <= 1024 else {
      fail("suffix digit count must be between 0 and 1024")
    }
    (parse_controls(parsed.operands[1:]), width)
  } catch {
    err => {
      @stdio.stderr.write("csplit: \{err}\n")
      @sys.exit(2)
      return
    }
  }
  let output : Output = {
    prefix: parsed.last_value("prefix").unwrap_or("xx"),
    width,
    quiet: parsed.contains("silent") || parsed.contains("quiet"),
    elide: parsed.contains("elide-empty-files"),
    paths: [],
  }
  try {
    let path = parsed.operands[0]
    let data = if path == "-" {
      @stdio.stdin.read_all().binary()
    } else {
      @fs.read_file(path).binary()
    }
    partition(data, controls, output)
  } catch {
    err => {
      @stdio.stderr.write("csplit: \{err}\n")
      if !parsed.contains("keep-files") {
        for path in output.paths {
          @fs.remove(path) catch {
            cleanup => @stdio.stderr.write("csplit: cleanup: \{cleanup}\n")
          }
        }
      }
      @sys.exit(1)
    }
  }
}
