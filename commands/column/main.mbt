///|
fn split_whitespace(line : String) -> Array[String] {
  let fields : Array[String] = []
  let mut start = 0
  let mut index = 0
  let mut in_field = false
  while index <= line.length() {
    let at_end = index == line.length()
    let blank = !at_end && (line[index] == ' ' || line[index] == '\t')
    if at_end || blank {
      if in_field {
        fields.push(line[start:index].to_owned())
        in_field = false
      }
      index += 1
    } else {
      if !in_field {
        start = index
        in_field = true
      }
      index += 1
    }
  }
  fields
}

///|
fn split_fields(line : String, separator : String?) -> Array[String] {
  match separator {
    Some(value) => line.split(value).map(item => item.to_owned()).collect()
    None => split_whitespace(line)
  }
}

///|
fn table(
  lines : Array[String],
  separator : String?,
  output_separator : String,
) -> String {
  let rows : Array[Array[String]] = []
  for line in lines {
    if line.trim() != "" {
      rows.push(split_fields(line, separator))
    }
  }
  let widths : Array[Int] = []
  for row in rows {
    for index, field in row {
      while widths.length() <= index {
        widths.push(0)
      }
      widths[index] = widths[index].max(field.length())
    }
  }
  let output = StringBuilder()
  for row_index, row in rows {
    for index, field in row {
      output.write_string(field)
      if index + 1 < row.length() {
        let padding = widths[index] - field.length()
        for _ in 0..<padding {
          output.write_char(' ')
        }
        output.write_string(output_separator)
      }
    }
    if row_index + 1 < rows.length() {
      output.write_char('\n')
    }
  }
  output.to_string()
}

///|
fn help_message() -> String {
  let message =
    #|Usage: column [OPTION]... [FILE]...
    #|Columnate input, or copy input when table mode is not selected.
    #|  -t, --table           create a table
    #|  -s, --separator=SEP   use SEP as the input field separator
    #|  -o, --output-separator=SEP
    #|                        use SEP between aligned columns
    #|      --help            display this help and exit
    #|      --version         display version and exit
  message
}

///|
async fn read_source(path : String) -> String {
  if path == "-" {
    @stdio.stdin.read_all().text()
  } else {
    @fs.read_file(path).text()
  }
}

///|
async fn main {
  let parsed = @cli.parse(@env.args()[1:], [
    @cli.flag("table", short='t'),
    @cli.option("separator", short='s'),
    @cli.option("output-separator", short='o'),
    @cli.flag("help"),
    @cli.flag("version"),
  ]) catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.write("column: \{message}: '\{option}'\n")
      @sys.exit(2)
      return
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.write(help_message())
    return
  }
  if parsed.contains("version") {
    @stdio.stdout.write("column (cli) \{command_version}\n")
    return
  }
  let separator = parsed.last_value("separator")
  if separator is Some(value) && value.length() != 1 {
    @stdio.stderr.write("column: separator must be one byte\n")
    @sys.exit(2)
    return
  }
  let output_separator = parsed.last_value("output-separator").unwrap_or(" ")
  let sources = if parsed.operands.is_empty() { ["-"] } else { parsed.operands }
  let mut failed = false
  let mut all = ""
  for path in sources {
    let input = read_source(path) catch {
      err => {
        @stdio.stderr.write("column: \{path}: \{err}\n")
        failed = true
        continue
      }
    }
    if parsed.contains("table") {
      let value = table(
        input.split("\n").map(line => line.to_owned()).collect(),
        separator,
        output_separator,
      )
      all += value
    } else {
      all += input
    }
  }
  @stdio.stdout.write(all)
  if failed {
    @sys.exit(1)
  }
}
