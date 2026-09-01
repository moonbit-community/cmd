///|
priv suberror CliError {
  CliError(String)
}

///|
priv struct Entry {
  line : String
  key : String
  numeric : Double
  index : Int
}

///|
fn split_lines(text : String) -> Array[String] {
  if text is "" {
    return []
  }
  let lines : Array[String] = text.split("\n").map(v => v.to_owned()).collect()
  if text.has_suffix("\n") {
    ignore(lines.pop())
  }
  lines
}

///|
fn split_fields(line : String, separator : String?) -> Array[String] {
  match separator {
    Some(sep) => line.split(sep).map(v => v.to_owned()).collect()
    None => {
      let fields : Array[String] = []
      let sb = StringBuilder()
      let mut in_field = false
      for c in line {
        if c == ' ' || c == '\t' {
          if in_field {
            fields.push(sb.to_string())
            sb.reset()
            in_field = false
          }
        } else {
          sb.write_char(c)
          in_field = true
        }
      }
      if in_field {
        fields.push(sb.to_string())
      }
      fields
    }
  }
}

///|
fn parse_positive(text : StringView, spec : String) -> Int raise CliError {
  let n = @string.parse_int(text) catch {
    _ => raise CliError("sort: invalid key specification: '\{spec}'")
  }
  if n < 1 {
    raise CliError("sort: invalid key specification: '\{spec}'")
  }
  n
}

///|
fn parse_key(spec : String) -> (Int, Int) raise CliError {
  let pieces : Array[String] = spec.split(",").map(v => v.to_owned()).collect()
  match pieces {
    [a] => {
      let start = parse_positive(a, spec)
      (start, 0x7FFFFFFF)
    }
    [a, b] => {
      let start = parse_positive(a, spec)
      let end = parse_positive(b, spec)
      if start > end {
        raise CliError("sort: invalid key specification: '\{spec}'")
      }
      (start, end)
    }
    _ => raise CliError("sort: invalid key specification: '\{spec}'")
  }
}

///|
fn extract_key(
  line : String,
  key : (Int, Int)?,
  separator : String?,
  out_sep : String,
) -> String {
  match key {
    None => line
    Some((start, end)) => {
      let fields = split_fields(line, separator)
      let kept : Array[String] = []
      for index, field in fields {
        let position = index + 1
        if position >= start && position <= end {
          kept.push(field)
        }
      }
      kept.join(out_sep)
    }
  }
}

///|
/// Parse the leading numeric prefix (optional sign, digits, optional decimal
/// part) of a key, ignoring leading blanks. Lines without one sort as 0.
fn numeric_prefix(key : String) -> Double {
  let chars : Array[Char] = key.iter().collect()
  let mut start = 0
  while start < chars.length() && (chars[start] == ' ' || chars[start] == '\t') {
    start += 1
  }
  let sb = StringBuilder()
  let mut i = start
  if i < chars.length() && (chars[i] == '-' || chars[i] == '+') {
    sb.write_char(chars[i])
    i += 1
  }
  let mut saw_digit = false
  while i < chars.length() && chars[i] is ('0'..='9') {
    sb.write_char(chars[i])
    saw_digit = true
    i += 1
  }
  if i < chars.length() && chars[i] == '.' {
    sb.write_char('.')
    i += 1
    while i < chars.length() && chars[i] is ('0'..='9') {
      sb.write_char(chars[i])
      saw_digit = true
      i += 1
    }
  }
  if !saw_digit {
    return 0.0
  }
  @string.parse_double(sb.to_string()) catch {
    _ => 0.0
  }
}

///|
async fn read_source_text(path : String) -> String {
  if path == "-" {
    @stdio.stdin.read_all().text()
  } else {
    @fs.read_file_to_string(path)
  }
}

///|
async fn main {
  let args = @env.args()[1:]
  let parsed = @cli.parse(args, [
    @cli.flag("reverse", short='r'),
    @cli.flag("numeric-sort", short='n'),
    @cli.flag("unique", short='u'),
    @cli.flag("ignore-case", short='f'),
    @cli.option("key", short='k'),
    @cli.option("field-separator", short='t'),
    @cli.flag("help"),
  ]) catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.write("sort: \{message}: '\{option}'\n")
      @sys.exit(2)
      return
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.write("Usage: sort [-rnuif] [-k KEY] [-t CHAR] [FILE...]\n")
    return
  }
  let reverse = parsed.contains("reverse")
  let numeric = parsed.contains("numeric-sort")
  let unique = parsed.contains("unique")
  let fold_case = parsed.contains("ignore-case")
  let separator = match parsed.last_value("field-separator") {
    Some(sep) => {
      if sep.char_length() != 1 {
        @stdio.stderr.write(
          "sort: the field separator must be a single character\n",
        )
        @sys.exit(2)
        return
      }
      Some(sep)
    }
    None => None
  }
  let key_spec = try {
    match parsed.last_value("key") {
      Some(spec) => Some(parse_key(spec))
      None => None
    }
  } catch {
    CliError(msg) => {
      @stdio.stderr.write("\{msg}\n")
      @sys.exit(2)
      return
    }
  }
  let out_sep = match separator {
    Some(sep) => sep
    None => " "
  }
  let files = parsed.operands
  let sources = if files.is_empty() { ["-"] } else { files }
  if files.is_empty() {
    @cli.warn_stdin_wait("sort")
  }
  let lines : Array[String] = []
  for path in sources {
    let text = read_source_text(path) catch {
      err => {
        @stdio.stderr.write("sort: \{err}\n")
        @sys.exit(1)
        return
      }
    }
    lines.append(split_lines(text))
  }
  let entries : Array[Entry] = []
  for index, line in lines {
    let raw_key = extract_key(line, key_spec, separator, out_sep)
    let key = if fold_case { raw_key.to_lower() } else { raw_key }
    entries.push({
      line,
      key,
      numeric: if numeric {
        numeric_prefix(key)
      } else {
        0.0
      },
      index,
    })
  }
  fn key_compare(a : Entry, b : Entry) -> Int {
    if numeric {
      a.numeric.compare(b.numeric)
    } else {
      a.key.compare(b.key)
    }
  }

  entries.sort_by(fn(a, b) {
    let mut cmp = key_compare(a, b)
    if cmp == 0 {
      // Last-resort comparison on the whole line, like GNU sort.
      cmp = a.line.compare(b.line)
    }
    if reverse {
      cmp = -cmp
    }
    if cmp == 0 {
      // Stability tiebreak: sort_by itself is unstable.
      a.index - b.index
    } else {
      cmp
    }
  })
  let mut previous : Entry? = None
  for entry in entries {
    let emit = match previous {
      Some(prev) => if unique { key_compare(prev, entry) != 0 } else { true }
      None => true
    }
    if emit {
      @stdio.stdout.write(entry.line + "\n")
      previous = Some(entry)
    }
  }
}
