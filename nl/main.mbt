///|
fn nl_command() -> @argparse.Command {
  Command(
    "nl",
    about="Number lines of each input.",
    options=[
      OptionArg(
        "body-numbering",
        short='b',
        about="Numbering style: a (all lines), t (nonempty lines), n (none).",
        default_values=["t"],
      ),
      OptionArg(
        "number-width",
        short='w',
        about="Width of the line number column.",
        default_values=["6"],
      ),
      OptionArg(
        "number-separator",
        short='s',
        about="String between number and line.",
        default_values=["\t"],
      ),
    ],
    positionals=[
      PositionArg(
        "files",
        about="[file...] ('-' or no file reads stdin)",
        num_args=ValueRange(lower=0),
      ),
    ],
    disable_help_subcommand=true,
  )
}

///|
fn option_value(
  matches : @argparse.Matches,
  name : String,
  fallback : String,
) -> String {
  match matches.values.get(name) {
    Some(vals) =>
      if vals.is_empty() {
        fallback
      } else {
        vals[vals.length() - 1]
      }
    None => fallback
  }
}

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
  let command = nl_command()
  let matches = command.parse(argv=args, env=Map([])) catch {
    err => {
      @stdio.stderr.write("\{err}\n")
      @sys.exit(2)
      return
    }
  }
  let style = option_value(matches, "body-numbering", "t")
  if !(style is ("a" | "t" | "n")) {
    @stdio.stderr.write("nl: invalid body numbering style: '\{style}'\n")
    @sys.exit(2)
    return
  }
  let width_text = option_value(matches, "number-width", "6")
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
  let separator = option_value(matches, "number-separator", "\t")
  let files = matches.values.get("files").unwrap_or([])
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
