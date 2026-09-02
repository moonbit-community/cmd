///|
fn pad_left(text : String, width : Int) -> String {
  let sb = StringBuilder()
  for _ in 0..<(width - text.length()) {
    sb.write_char(' ')
  }
  sb.write_string(text)
  sb.to_string()
}

///|
fn spaces(width : Int) -> String {
  let sb = StringBuilder()
  for _ in 0..<width {
    sb.write_char(' ')
  }
  sb.to_string()
}

///|
async fn process_reader(
  reader : &@io.Reader,
  style : String,
  width : Int,
  separator : String,
  number : Ref[Int],
) -> Unit {
  let scanner = @stream.LineScanner::new(reader)
  while scanner.next() is Some(line) {
    let numbered = match style {
      "a" => true
      "t" => !line.data.is_empty()
      _ => false
    }
    if numbered {
      @stdio.stdout.write(pad_left(number.val.to_string(), width) + separator)
      @stdio.stdout.write(line.data)
      @stdio.stdout.write("\n")
      number.val += 1
    } else {
      @stdio.stdout.write(spaces(width))
      @stdio.stdout.write(line.data)
      @stdio.stdout.write("\n")
    }
  }
}

///|
async fn main {
  let args = @env.args()[1:]
  let parsed = @cli.parse(args, [
    @cli.option("body-numbering", short='b'),
    @cli.option("number-width", short='w'),
    @cli.option("number-separator", short='s'),
    @cli.flag("help"),
  ]) catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.write("nl: \{message}: '\{option}'\n")
      @sys.exit(2)
      return
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.write(
      "Usage: nl [-b STYLE] [-w NUMBER] [-s STRING] [FILE...]\n",
    )
    return
  }
  let style = parsed.last_value("body-numbering").unwrap_or("t")
  if !(style is ("a" | "t" | "n")) {
    @stdio.stderr.write("nl: invalid body numbering style: '\{style}'\n")
    @sys.exit(2)
    return
  }
  let width_text = parsed.last_value("number-width").unwrap_or("6")
  let width = @string.parse_int(width_text) catch {
    _ => {
      @stdio.stderr.write(
        "nl: invalid line number field width: '\{width_text}'\n",
      )
      @sys.exit(2)
      return
    }
  }
  if width < 1 {
    @stdio.stderr.write(
      "nl: invalid line number field width: '\{width_text}'\n",
    )
    @sys.exit(2)
    return
  }
  let separator = parsed.last_value("number-separator").unwrap_or("\t")
  let files = parsed.operands
  let sources = if files.is_empty() { ["-"] } else { files }
  let number = Ref(1)
  let mut failed = false
  for path in sources {
    try {
      if path == "-" {
        process_reader(@stdio.stdin, style, width, separator, number)
      } else {
        let file = @fs.open(path, mode=ReadOnly)
        defer file.close()
        process_reader(file, style, width, separator, number)
      }
    } catch {
      err => {
        @stdio.stderr.write("nl: \{err}\n")
        failed = true
        continue
      }
    }
  }
  if failed {
    @sys.exit(1)
  }
}
