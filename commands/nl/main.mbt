///|
fn pad_left(text : String, width : Int32, fill~ : Char = ' ') -> String {
  let sb = StringBuilder()
  for _ in 0..<(width - text.length()) {
    sb.write_char(fill)
  }
  sb.write_string(text)
  sb.to_string()
}

///|
fn format_number(number : Int32, width : Int32, format : String) -> String {
  let text = number.to_string()
  match format {
    "ln" => text + " ".repeat((width - text.length()).max(0))
    "rz" if text.has_prefix("-") =>
      "-" + pad_left(text[1:].to_owned(), width - 1, fill='0')
    "rz" => pad_left(text, width, fill='0')
    _ => pad_left(text, width)
  }
}

///|
fn spaces(width : Int32) -> String {
  let sb = StringBuilder()
  for _ in 0..<width {
    sb.write_char(' ')
  }
  sb.to_string()
}

///|
// Deferred output remains cancellable if the downstream writer stalls.
#warnings("-cancellable_defer")
async fn process_reader(
  reader : &@io.Reader,
  header_style : String,
  body_style : String,
  footer_style : String,
  width : Int32,
  separator : String,
  number : Ref[Int32],
  starting_number : Int32,
  increment : Int32,
  number_format : String,
  join_blank_lines : Int32,
  no_renumber : Bool,
  section_delimiter : String,
  section : Ref[Int32],
  blank_run : Ref[Int32],
  writer~ : &@io.Writer = @stdio.stdout,
) -> Unit {
  let output = @stream.BlockWriter::new(writer)
  defer output.flush()
  let scanner = @stream.RecordReader::new(reader)
  let state : Numbering = {
    header_style,
    body_style,
    footer_style,
    width,
    separator,
    number,
    starting_number,
    increment,
    number_format,
    join_blank_lines,
    no_renumber,
    section,
    blank_run,
    markers: [
      @utf8.encode(section_delimiter.repeat(3)),
      @utf8.encode(section_delimiter.repeat(2)),
      @utf8.encode(section_delimiter),
    ],
    blank_prefix: None,
  }
  while scanner.next_batch() is Some(batch) {
    while state.buffer_batch(batch, output) is Some((record, numbered)) {
      output.write_slice(record, 0, record.length())
      if numbered {
        number.val += increment
      }
    }
  }
}

///|
async fn main {
  let metadata_args = @env.args()[1:]
  if metadata_args.length() == 1 && metadata_args[0] == "--version" {
    @stdio.stdout.write("nl 0.2.7\n")
    return
  }
  let args = @env.args()[1:]
  let parsed = @cli.parse(args, [
    @cli.option("body-numbering", short='b'),
    @cli.option("header-numbering", short='h'),
    @cli.option("footer-numbering", short='f'),
    @cli.option("number-width", short='w'),
    @cli.option("number-separator", short='s'),
    @cli.option("starting-line-number", short='v'),
    @cli.option("line-increment", short='i'),
    @cli.option("join-blank-lines", short='l'),
    @cli.option("number-format", short='n'),
    @cli.option("section-delimiter", short='d'),
    @cli.flag("no-renumber", short='p'),
    @cli.flag("help"),
  ]) catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.write("nl: \{message}: '\{option}'\n")
      @sys.exit(1)
      return
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.write(
      "Usage: nl [-b STYLE] [-h STYLE] [-f STYLE] [-v NUMBER] [-i NUMBER] [-l NUMBER] [-n FORMAT] [-w NUMBER] [-s STRING] [-d STRING] [-p] [FILE...]\n      --help      display this help and exit\n      --version   display version and exit\nOrdinary option/operand errors exit 1; documented capability refusals retain their own status.\n",
    )
    return
  }
  let body_style = parsed.last_value("body-numbering").unwrap_or("t")
  let header_style = parsed.last_value("header-numbering").unwrap_or("n")
  let footer_style = parsed.last_value("footer-numbering").unwrap_or("n")
  for
    entry in [
      ("body", body_style),
      ("header", header_style),
      ("footer", footer_style),
    ] {
    let (label, style) = entry
    if !(style is ("a" | "t" | "n")) {
      @stdio.stderr.write("nl: invalid \{label} numbering style: '\{style}'\n")
      @sys.exit(1)
      return
    }
  }
  let width_text = parsed.last_value("number-width").unwrap_or("6")
  let width = @string.parse_int(width_text) catch {
    _ => {
      @stdio.stderr.write(
        "nl: invalid line number field width: '\{width_text}'\n",
      )
      @sys.exit(1)
      return
    }
  }
  if width < 1 {
    @stdio.stderr.write(
      "nl: invalid line number field width: '\{width_text}'\n",
    )
    @sys.exit(1)
    return
  }
  let separator = parsed.last_value("number-separator").unwrap_or("\t")
  let starting_text = parsed.last_value("starting-line-number").unwrap_or("1")
  let starting_number = @string.parse_int(starting_text) catch {
    _ => {
      @stdio.stderr.write(
        "nl: invalid starting line number: '\{starting_text}'\n",
      )
      @sys.exit(1)
      return
    }
  }
  let increment_text = parsed.last_value("line-increment").unwrap_or("1")
  let increment = @string.parse_int(increment_text) catch {
    _ => {
      @stdio.stderr.write(
        "nl: invalid line number increment: '\{increment_text}'\n",
      )
      @sys.exit(1)
      return
    }
  }
  let join_blank_text = parsed.last_value("join-blank-lines").unwrap_or("1")
  let join_blank_lines = @string.parse_int(join_blank_text) catch {
    _ => {
      @stdio.stderr.write(
        "nl: invalid blank-line group size: '\{join_blank_text}'\n",
      )
      @sys.exit(1)
      return
    }
  }
  if join_blank_lines < 1 {
    @stdio.stderr.write(
      "nl: invalid blank-line group size: '\{join_blank_text}'\n",
    )
    @sys.exit(1)
    return
  }
  let number_format = parsed.last_value("number-format").unwrap_or("rn")
  if !(number_format is ("ln" | "rn" | "rz")) {
    @stdio.stderr.write("nl: invalid line number format: '\{number_format}'\n")
    @sys.exit(1)
    return
  }
  let section_delimiter = match parsed.last_value("section-delimiter") {
    Some(value) if @utf8.encode(value).length() == 1 => value + ":"
    Some(value) => value
    None => "\\:"
  }
  let files = parsed.operands
  let sources = if files.is_empty() { ["-"] } else { files }
  let number = Ref(starting_number)
  let section = Ref(1)
  let blank_run = Ref(0)
  let no_renumber = parsed.contains("no-renumber")
  let mut failed = false
  for path in sources {
    try {
      if path == "-" {
        process_reader(
          @stdio.stdin, header_style, body_style, footer_style, width, separator,
          number, starting_number, increment, number_format, join_blank_lines, no_renumber,
          section_delimiter, section, blank_run,
        )
      } else {
        let file = @fs.open(path, mode=ReadOnly)
        defer file.close()
        process_reader(
          file, header_style, body_style, footer_style, width, separator, number,
          starting_number, increment, number_format, join_blank_lines, no_renumber,
          section_delimiter, section, blank_run,
        )
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
