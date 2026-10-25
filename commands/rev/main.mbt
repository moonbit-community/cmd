///|
priv suberror InvalidCRecord {
  InvalidCRecord
}

///|
fn reverse_line(data : Bytes) -> Bytes {
  let output : Array[Byte] = []
  let mut index = data.length()
  while index > 0 {
    index -= 1
    output.push(data[index])
  }
  Bytes::from_array(output)
}

///|
fn reverse_lines(data : Bytes) -> Bytes {
  let output : Array[Byte] = []
  let mut start = 0
  for index, byte in data {
    if byte == b'\n' {
      output.append(reverse_line(data[start:index].to_owned()).to_array())
      output.push(b'\n')
      start = index + 1
    }
  }
  if start < data.length() {
    output.append(reverse_line(data[start:].to_owned()).to_array())
  }
  Bytes::from_array(output)
}

///|
fn help_message() -> String {
  let message =
    #|Usage: rev [OPTION]... [FILE]...
    #|      --help      display this help and exit
    #|      --version   display version and exit
    #|
    #|Reverse each line from ordered FILE operands, or standard input if absent.
    #|The fixed Linux C-locale profile reverses bytes and rejects non-ASCII records.
    #|An explicit - is a filename, as in the frozen util-linux profile.
  message
}

///|
async fn main {
  let metadata_args = @env.args()[1:]
  if metadata_args.length() == 1 && metadata_args[0] == "--version" {
    @stdio.stdout.write("rev 0.1.3\n")
    return
  }
  let parsed = @cli.parse(@env.args()[1:], [@cli.flag("help")]) catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.write("rev: \{message}: '\{option}'\n")
      @sys.exit(2)
      return
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.write(help_message() + "\n")
    return
  }
  if parsed.operands.is_empty() {
    let lines = Ref(0L)
    reverse_reader(@stdio.stdin, lines) catch {
      error => {
        @stdio.stderr.write(
          "rev: stdin: " +
          lines.val.to_string() +
          ": " +
          error_message(error) +
          "\n",
        )
        @sys.exit(1)
      }
    }
    return
  }
  let mut status = 0
  for path in parsed.operands {
    let mut opened = false
    let lines = Ref(0L)
    try {
      let file = @fs.open(path, mode=ReadOnly)
      opened = true
      defer file.close()
      if file.kind() == @fs.FileKind::Directory {
        @stdio.stderr.write("rev: " + path + ": 0: Is a directory\n")
        status = 1
      } else {
        reverse_reader(file, lines)
      }
    } catch {
      error => {
        let prefix = if opened {
          "rev: " + path + ": " + lines.val.to_string() + ": "
        } else {
          "rev: cannot open " + path + ": "
        }
        @stdio.stderr.write(prefix + error_message(error) + "\n")
        status = 1
      }
    }
  }
  if status != 0 {
    @sys.exit(status)
  }
}

///|
async fn reverse_reader(
  reader : &@io.Reader,
  count : Ref[Int64],
  writer~ : &@io.Writer = @stdio.stdout,
) -> Unit {
  let lines = @stream.LineScanner::new(reader)
  while lines.next() is Some(line) {
    if line.data.iter().any(byte => byte.to_int() >= 128) {
      raise InvalidCRecord
    }
    writer.write(reverse_lines(line.data))
    if line.terminated {
      writer.write(b"\n")
    }
    count.val += 1
  }
}

///|
fn error_message(error : Error) -> String {
  match error {
    InvalidCRecord => "Invalid or incomplete multibyte or wide character"
    @os_error.OSError(code, ..) as error =>
      if error.is_ENOENT() {
        "No such file or directory"
      } else if error.is_EACCES() {
        "Permission denied"
      } else if error.is_ENOTDIR() {
        "Not a directory"
      } else if !@platform.is_windows() && code == 21 {
        "Is a directory"
      } else if !@platform.is_windows() && code == 9 {
        "Bad file descriptor"
      } else {
        error.to_string()
      }
    _ => error.to_string()
  }
}
