///|
fn split_fields(line : String, separator : String?) -> Array[String] {
  let fields : Array[String] = []
  let delimiters = separator.unwrap_or(" \t")
  let mut start = 0
  for index, char in line {
    if delimiters.contains(char.to_string()) {
      if separator is Some(_) || index > start {
        fields.push(line[start:index].to_owned())
      }
      start = index + 1
    }
  }
  if separator is Some(_) || start < line.length() {
    fields.push(line[start:].to_owned())
  }
  fields
}

///|
// Input is converted to the GNU/Linux C-locale byte representation before
// layout. Control bytes are preserved but occupy no printable cells.
fn display_width(field : String, table? : Bool = false) -> Int {
  let mut width = 0
  let mut i = 0
  while i < field.length() {
    let c = field[i]
    i += 1
    if c >= ' ' && c <= '~' {
      width += 1
    } else if table && i < field.length() && field[i] == '[' {
      // util-linux 2.40's table width skips control + '[' ... 'm'.
      // Its default grid uses the unfiltered printable-character count.
      let mut end = i + 1
      while end < field.length() && field[end] != 'm' {
        end += 1
      }
      if end < field.length() {
        i = end + 1
      }
    }
  }
  width
}

///|
fn table(
  lines : Array[String],
  separator : String?,
  output_separator : String,
) -> String {
  let rows = lines.map(line => split_fields(line, separator))
  let widths : Array[Int] = []
  for row in rows {
    for index, field in row {
      while widths.length() <= index {
        widths.push(0)
      }
      widths[index] = widths[index].max(display_width(field, table=true))
    }
  }
  let output = StringBuilder()
  for row in rows {
    for index in 0..<widths.length() {
      let field = row.get(index).unwrap_or("")
      output.write_string(field)
      if index + 1 < widths.length() {
        output.write_string(
          " ".repeat(widths[index] - display_width(field, table=true)),
        )
        output.write_string(output_separator)
      }
    }
    output.write_char('\n')
  }
  output.to_string()
}

///|
fn columns(lines : Array[String], width : Int, fill_rows : Bool) -> String {
  if lines.is_empty() {
    return ""
  }
  let longest = lines
    .iter()
    .fold(init=0, (n, line) => n.max(display_width(line)))
  if longest >= width {
    return lines.join("\n") + "\n"
  }
  let stride = (longest / 8 + 1) * 8
  let count = (width / stride).max(1).min(lines.length())
  let rows = (lines.length() + count - 1) / count
  let output = StringBuilder()
  for row in 0..<rows {
    let mut position = 0
    let mut end_column = stride
    for col in 0..<count {
      let index = if fill_rows { row * count + col } else { row + col * rows }
      if index >= lines.length() {
        break
      }
      if col > 0 {
        while (position / 8 + 1) * 8 <= end_column {
          output.write_char('\t')
          position = (position / 8 + 1) * 8
        }
        end_column += stride
      }
      output.write_string(lines[index])
      position += display_width(lines[index])
    }
    output.write_char('\n')
  }
  output.to_string()
}

///|
fn input_lines(data : Bytes) -> Array[String] {
  let result : Array[String] = []
  let mut start = 0
  for end in 0..<=data.length() {
    if end < data.length() && data[end] != b'\n' {
      continue
    }
    let line = StringBuilder()
    for byte in data[start:end] {
      if byte == 0 {
        break
      }
      if byte >= 128 {
        let hex = "0123456789abcdef"
        line.write_string("\\x")
        line.write_char(hex[byte.to_int() / 16].to_char().unwrap())
        line.write_char(hex[byte.to_int() % 16].to_char().unwrap())
      } else {
        line.write_char(byte.to_int().to_char().unwrap())
      }
    }
    let value = line.to_string()
    if !value
      .iter()
      .all(c => c is (' ' | '\t' | '\r' | '\n' | '\u000b' | '\u000c')) {
      result.push(value)
    }
    start = end + 1
  }
  result
}

///|
fn help_message() -> String {
  let help =
    #|Usage: column [OPTION]... [FILE]...
    #|Columnate input in columns (default), or align a table with -t.
    #|  -t, --table                 create a table
    #|  -s, --separator=CHARS       table delimiters (default: space and TAB)
    #|  -o, --output-separator=SEP  table separator (default: two spaces)
    #|  -c, --output-width=WIDTH    output width (default: COLUMNS or 80)
    #|  -x, --fillrows              fill rows before columns
    #|      --help                 display this help and exit
    #|      --version              display version and exit
    #|Layout uses the C locale. Bytes above ASCII are printed as \xHH.
    #|
  help
}

///|
async fn main {
  let parsed = @cli.parse(@env.args()[1:], [
    @cli.flag("table", short='t'),
    @cli.option("separator", short='s'),
    @cli.option("output-separator", short='o'),
    @cli.option("output-width", short='c'),
    @cli.flag("fillrows", short='x'),
    @cli.flag("help"),
    @cli.flag("version"),
  ]) catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.write("column: \{message}: '\{option}'\n")
      @sys.exit(1)
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
  if separator is Some(value) && value.iter().any(c => c.to_int() >= 128) {
    @stdio.stderr.write("column: unsupported non-ASCII input separator\n")
    @sys.exit(2)
    return
  }
  let default_width = @string.parse_int(
    @env.get_env_var("COLUMNS").unwrap_or("80"),
  ) catch {
    _ => 80
  }
  let width = match parsed.last_value("output-width") {
    None => if default_width > 0 { default_width } else { 80 }
    Some("unlimited") => 0
    Some(value) => @string.parse_int(value) catch { _ => -1 }
  }
  if width < 0 {
    @stdio.stderr.write("column: invalid output width\n")
    @sys.exit(1)
    return
  }
  let lines : Array[String] = []
  let mut failed = false
  if parsed.operands.is_empty() {
    lines.append(input_lines(@stdio.stdin.read_all().binary()))
  } else {
    for path in parsed.operands {
      // util-linux treats '-' as a filename; omitted operands select stdin.
      let data = @fs.read_file(path).binary() catch {
        err => {
          @stdio.stderr.write("column: \{path}: \{err}\n")
          failed = true
          continue
        }
      }
      lines.append(input_lines(data))
    }
  }
  @stdio.stdout.write(
    if parsed.contains("table") {
      table(
        lines,
        separator,
        parsed.last_value("output-separator").unwrap_or("  "),
      )
    } else {
      columns(lines, width, parsed.contains("fillrows"))
    },
  )
  if failed {
    @sys.exit(1)
  }
}
