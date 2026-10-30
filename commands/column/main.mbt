///|
priv struct FieldSeparator {
  members : FixedArray[Bool]
  preserve_empty : Bool
}

///|
fn FieldSeparator::new(separator : String?) -> FieldSeparator {
  let members = FixedArray::make(128, false)
  // The command rejects non-ASCII input separators before creating a snapshot.
  for char in separator.unwrap_or(" \t") {
    if char.to_int() < 128 {
      members[char.to_int()] = true
    }
  }
  { members, preserve_empty: separator is Some(_), }
}

///|
// Input is converted to the GNU/Linux C-locale byte representation before
// layout. Control bytes are preserved but occupy no printable cells.
fn display_width(field : String, table~ : Bool = false) -> Int32 {
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
fn input_line(data : BytesView) -> String? {
  let end = data.find(b"\x00").unwrap_or(data.length())
  let prefix = data[:end]
  if input_is_ascii(prefix) {
    if prefix
      .iter()
      .all(byte => byte is (b' ' | b'\t' | b'\r' | b'\n' | b'\x0b' | b'\x0c')) {
      return None
    }
    // Every byte is ASCII, so decoding cannot replace or combine input bytes.
    return Some(@utf8.decode_lossy(prefix))
  }
  let line = StringBuilder()
  for byte in prefix {
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
  if value
    .iter()
    .all(c => c is (' ' | '\t' | '\r' | '\n' | '\u000b' | '\u000c')) {
    None
  } else {
    Some(value)
  }
}

///|
fn input_is_ascii(data : BytesView) -> Bool {
  let mut offset = 0
  while data.length() - offset >= 8 {
    if (data.unsafe_read_uint64_le(offset) & 0x8080808080808080UL) != 0UL {
      return false
    }
    offset += 8
  }
  for byte in data[offset:] {
    if byte >= 128 {
      return false
    }
  }
  true
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
    #|Layout uses temporary files and requires filesystem write access.
    #|
  help
}

///|
async fn main {
  let metadata_args = @env.args()[1:]
  if metadata_args.length() == 1 && metadata_args[0] == "--version" {
    @stdio.stdout.write("column 0.1.6\n")
    return
  }
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
    @stdio.stdout.write("column \{command_version}\n")
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
  let failed = run_layout(
    parsed.operands,
    table=parsed.contains("table"),
    separator~,
    output_separator=parsed.last_value("output-separator").unwrap_or("  "),
    width~,
    fill_rows=parsed.contains("fillrows"),
  ) catch {
    err => {
      @stdio.stderr.write("column: \{err}\n")
      true
    }
  }
  if failed {
    @sys.exit(1)
  }
}
