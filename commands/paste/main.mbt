///|
priv suberror DelimiterError {
  DelimiterError(String)
}

///|
fn parse_delimiters(spec : String) -> Array[Bytes] raise DelimiterError {
  let delims : Array[Bytes] = []
  let raw = @utf8.encode(spec)
  let mut i = 0
  while i < raw.length() {
    if raw[i] == b'\\' && i + 1 < raw.length() {
      let octal = raw[i + 1] == b'0'
      let out = match raw[i + 1] {
        b'b' => b"\b"
        b'f' => b"\f"
        b'n' => b"\n"
        b'r' => b"\r"
        b't' => b"\t"
        b'v' => b"\x0b"
        b'0' => {
          let mut j = i + 2
          let mut value = 0
          let mut count = 0
          while j < raw.length() &&
                count < 3 &&
                raw[j] >= b'0' &&
                raw[j] <= b'7' {
            value = value * 8 + raw[j].to_int() - b'0'.to_int()
            count += 1
            j += 1
          }
          if count == 0 {
            i += 2
            delims.push(b"")
            continue
          }
          i = j
          Bytes::from_array([value.to_byte()])
        }
        b'\\' => b"\\"
        byte => Bytes::from_array([byte])
      }
      delims.push(out)
      if !octal {
        i += 2
      }
    } else if raw[i] == b'\\' {
      raise DelimiterError(
        "paste: delimiter list ends with an unescaped backslash",
      )
    } else {
      delims.push(Bytes::from_array([raw[i]]))
      i += 1
    }
  }
  if delims.is_empty() {
    delims.push(b"")
  }
  delims
}

///|
async fn paste_serial(
  scanner : @stream.LineScanner,
  delimiters : Array[Bytes],
  record_delimiter : Byte,
) -> Unit {
  let mut index = 0
  while scanner.next() is Some(line) {
    if index > 0 {
      @stdio.stdout.write(delimiters[(index - 1) % delimiters.length()])
    }
    @stdio.stdout.write(line.data)
    index += 1
  }
  if index > 0 {
    @stdio.stdout.write(Bytes::from_array([record_delimiter]))
  }
}

///|
async fn paste_parallel(
  scanners : Array[@stream.LineScanner],
  delimiters : Array[Bytes],
  record_delimiter : Byte,
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
    @stdio.stdout.write(Bytes::from_array([record_delimiter]))
  }
}

///|
async fn main {
  let args = @env.args()[1:]
  let parsed = @cli.parse(args, [
    @cli.flag("serial", short='s'),
    @cli.option("delimiters", short='d'),
    @cli.flag("zero-terminated", short='z'),
    @cli.flag("help"),
  ]) catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.write("paste: \{message}: '\{option}'\n")
      @sys.exit(2)
      return
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.write("Usage: paste [-s] [-d LIST] [-z] [FILE...]\n")
    return
  }
  let serial = parsed.contains("serial")
  let record_delimiter = if parsed.contains("zero-terminated") {
    b'\x00'
  } else {
    b'\n'
  }
  let delims = match parsed.last_value("delimiters") {
    Some(spec) =>
      parse_delimiters(spec) catch {
        DelimiterError(message) => {
          @stdio.stderr.write(message + "\n")
          @sys.exit(1)
          return
        }
      }
    None => [b"\t"]
  }
  let files = parsed.operands
  let sources = if files.is_empty() { ["-"] } else { files }
  let open_files : Array[@fs.File] = []
  defer (for file in open_files {
    file.close()
  })
  let stdin_scanner = @stream.LineScanner::new(
    @stdio.stdin,
    delimiter=record_delimiter,
  )
  try {
    if serial {
      for path in sources {
        if path == "-" {
          paste_serial(stdin_scanner, delims, record_delimiter)
        } else {
          let file = @fs.open(path, mode=ReadOnly)
          open_files.push(file)
          paste_serial(
            @stream.LineScanner::new(file, delimiter=record_delimiter),
            delims,
            record_delimiter,
          )
        }
      }
    } else {
      let scanners : Array[@stream.LineScanner] = []
      for path in sources {
        if path == "-" {
          scanners.push(stdin_scanner)
        } else {
          let file = @fs.open(path, mode=ReadOnly)
          open_files.push(file)
          scanners.push(
            @stream.LineScanner::new(file, delimiter=record_delimiter),
          )
        }
      }
      paste_parallel(scanners, delims, record_delimiter)
    }
  } catch {
    err => {
      @stdio.stderr.write("paste: \{err}\n")
      @sys.exit(1)
      return
    }
  }
}
