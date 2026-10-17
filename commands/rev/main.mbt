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
    #|Reverse the characters of every line from standard input or one file.
    #|This implementation uses C-locale byte order and preserves line feeds.
  message
}

///|
async fn main {
  let metadata_args = @env.args()[1:]
  if metadata_args.length() == 1 && metadata_args[0] == "--version" {
    @stdio.stdout.write("rev 0.1.2\n")
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
  if parsed.operands.length() > 1 {
    @stdio.stderr.write("rev: multiple input files are not supported\n")
    @sys.exit(2)
    return
  }
  let path = if parsed.operands.is_empty() { "-" } else { parsed.operands[0] }
  let data = try {
    if path == "-" {
      @stdio.stdin.read_all().binary()
    } else {
      @fs.read_file(path).binary()
    }
  } catch {
    err => {
      @stdio.stderr.write("rev: \{err}\n")
      @sys.exit(1)
      return
    }
  }
  @stdio.stdout.write(reverse_lines(data))
}
