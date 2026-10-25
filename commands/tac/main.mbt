///|
fn starts_with_at(data : Bytes, index : Int32, separator : Bytes) -> Bool {
  if index + separator.length() > data.length() {
    return false
  }
  for offset in 0..<separator.length() {
    if data[index + offset] != separator[offset] {
      return false
    }
  }
  true
}

///|
fn reverse_records(
  data : Bytes,
  separator : Bytes,
  before : Bool,
  regex~ : @bytere.Pattern? = None,
) -> Bytes {
  let output : Array[Byte] = []
  let text = if regex is Some(_) { @bytere.text(data) } else { "" }
  let mut search_end = data.length()
  let mut past_end = data.length()
  let mut first = true
  while search_end > 0 {
    let match_span = if regex is Some(pattern) {
      pattern.rfind_span(text, search_end)
    } else {
      let mut position = search_end - separator.length()
      while position >= 0 && !starts_with_at(data, position, separator) {
        position -= 1
      }
      if position < 0 {
        None
      } else {
        Some((position, position + separator.length()))
      }
    }
    guard match_span is Some((start, end)) else { break }
    let boundary = if before { start } else { end }
    if before || !first || boundary != past_end {
      output.append(data[boundary:past_end].to_array())
    }
    past_end = boundary
    search_end = start
    first = false
  }
  output.append(data[:past_end].to_array())
  Bytes::from_array(output)
}

///|
fn help_message() -> String {
  let message =
    #|Usage: tac [OPTION]... [FILE]...
    #|      --help      display this help and exit
    #|      --version   display version and exit
    #|
    #|Write each FILE to standard output, last line first.
    #|With no FILE, or when FILE is -, read standard input.
    #|
    #|  -b, --before             Attach the separator before records.
    #|  -s, --separator=STRING   Use STRING instead of newline.
    #|  -r, --regex              Use an Emacs-style byte regular expression.
  message
}

///|
async fn main {
  let metadata_args = @env.args()[1:]
  if metadata_args.length() == 1 && metadata_args[0] == "--version" {
    @stdio.stdout.write("tac 0.1.3\n")
    return
  }
  let parsed = @cli.parse(@env.args()[1:], [
    @cli.flag("before", short='b'),
    @cli.option("separator", short='s'),
    @cli.flag("regex", short='r'),
    @cli.flag("help"),
  ]) catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.write("tac: \{message}: '\{option}'\n")
      @sys.exit(2)
      return
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.write(help_message() + "\n")
    return
  }
  let value = parsed.last_value("separator").unwrap_or("\n")
  if parsed.contains("regex") && value.is_empty() {
    @stdio.stderr.write("tac: separator cannot be empty\n")
    @sys.exit(1)
    return
  }
  let regex = try {
    if parsed.contains("regex") {
      Some(@bytere.compile(@bytere.argument(value), emacs=true))
    } else {
      None
    }
  } catch {
    @bytere.PatternError(message) => {
      let message = match message {
        "unmatched opening parenthesis" => "Unmatched ( or \\("
        "unmatched closing parenthesis" => "Unmatched ) or \\)"
        "unterminated bracket expression" => "Unmatched [, [^, [:, [., or [="
        "trailing backslash in regular expression" => "Trailing backslash"
        "invalid backreference" => "Invalid back reference"
        _ => message
      }
      @stdio.stderr.write("tac: " + message + "\n")
      @sys.exit(1)
      return
    }
    error => {
      @stdio.stderr.write("tac: " + error.to_string() + "\n")
      @sys.exit(1)
      return
    }
  }
  let separator = if value.is_empty() { b"\x00" } else { @utf8.encode(value) }
  let paths = if parsed.operands.is_empty() { ["-"] } else { parsed.operands }
  let mut status = 0
  for path in paths {
    let mut opened = path == "-"
    try {
      let data = if path == "-" {
        @stdio.stdin.read_all().binary()
      } else {
        let file = @fs.open(path, mode=ReadOnly)
        opened = true
        defer file.close()
        if file.kind() == @fs.FileKind::Directory {
          @stdio.stderr.write("tac: " + path + ": read error: Is a directory\n")
          status = 1
          continue
        }
        file.read_all().binary()
      }
      @stdio.stdout.write(
        reverse_records(data, separator, parsed.contains("before"), regex~),
      )
    } catch {
      error => {
        let message = error_message(error)
        if path == "-" {
          @stdio.stderr.write(
            "tac: 'standard input': read error: " +
            message +
            "\ntac: -: " +
            message +
            "\n",
          )
        } else if opened {
          @stdio.stderr.write(
            "tac: " + path + ": read error: " + message + "\n",
          )
        } else {
          @stdio.stderr.write(
            "tac: failed to open '" +
            path.replace_all(old="'", new="'\\''") +
            "' for reading: " +
            message +
            "\n",
          )
        }
        status = 1
      }
    }
  }
  if status != 0 {
    @sys.exit(status)
  }
}

///|
fn error_message(error : Error) -> String {
  match error {
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
