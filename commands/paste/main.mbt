///|
fn parse_delimiters(spec : String) -> Array[String] {
  let delims : Array[String] = []
  let chars : Array[Char] = spec.iter().collect()
  let mut i = 0
  while i < chars.length() {
    if chars[i] == '\\' && i + 1 < chars.length() {
      let out = match chars[i + 1] {
        'n' => "\n"
        't' => "\t"
        '0' => ""
        '\\' => "\\"
        c => c.to_string()
      }
      delims.push(out)
      i += 2
    } else {
      delims.push(chars[i].to_string())
      i += 1
    }
  }
  if delims.is_empty() {
    delims.push("\t")
  }
  delims
}

///|
async fn paste_serial(
  scanner : @stream.LineScanner,
  delimiters : Array[String],
) -> Unit {
  let mut index = 0
  while scanner.next() is Some(line) {
    if index > 0 {
      @stdio.stdout.write(delimiters[(index - 1) % delimiters.length()])
    }
    @stdio.stdout.write(line.data)
    index += 1
  }
  @stdio.stdout.write("\n")
}

///|
async fn paste_parallel(
  scanners : Array[@stream.LineScanner],
  delimiters : Array[String],
) -> Unit {
  for ;; {
    let row : Array[Bytes?] = []
    let mut any = false
    for scanner in scanners {
      match scanner.next() {
        Some(line) => {
          row.push(Some(line.data))
          any = true
        }
        None => row.push(None)
      }
    }
    if !any {
      break
    }
    for index, value in row {
      if index > 0 {
        @stdio.stdout.write(delimiters[(index - 1) % delimiters.length()])
      }
      if value is Some(data) {
        @stdio.stdout.write(data)
      }
    }
    @stdio.stdout.write("\n")
  }
}

///|
async fn main {
  let args = @env.args()[1:]
  let parsed = @cli.parse(args, [
    @cli.flag("serial", short='s'),
    @cli.option("delimiters", short='d'),
    @cli.flag("help"),
  ]) catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.write("paste: \{message}: '\{option}'\n")
      @sys.exit(2)
      return
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.write("Usage: paste [-s] [-d LIST] [FILE...]\n")
    return
  }
  let serial = parsed.contains("serial")
  let delims = match parsed.last_value("delimiters") {
    Some(spec) => parse_delimiters(spec)
    None => ["\t"]
  }
  let files = parsed.operands
  let sources = if files.is_empty() { ["-"] } else { files }
  if files.is_empty() {
    @cli.warn_stdin_wait("paste")
  }
  let mut stdin_count = 0
  for path in sources {
    if path == "-" {
      stdin_count += 1
    }
  }
  if stdin_count > 1 {
    @stdio.stderr.write("paste: standard input may be specified only once\n")
    @sys.exit(2)
    return
  }
  let open_files : Array[@fs.File] = []
  defer (for file in open_files {
    file.close()
  })
  try {
    if serial {
      for path in sources {
        if path == "-" {
          paste_serial(@stream.LineScanner::new(@stdio.stdin), delims)
        } else {
          let file = @fs.open(path, mode=ReadOnly)
          open_files.push(file)
          paste_serial(@stream.LineScanner::new(file), delims)
        }
      }
    } else {
      let scanners : Array[@stream.LineScanner] = []
      for path in sources {
        if path == "-" {
          scanners.push(@stream.LineScanner::new(@stdio.stdin))
        } else {
          let file = @fs.open(path, mode=ReadOnly)
          open_files.push(file)
          scanners.push(@stream.LineScanner::new(file))
        }
      }
      paste_parallel(scanners, delims)
    }
  } catch {
    err => {
      @stdio.stderr.write("paste: \{err}\n")
      @sys.exit(1)
      return
    }
  }
}
