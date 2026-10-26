///|
priv suberror CliError {
  CliError(String)
}

///|
priv enum GroupSeparator {
  NoSeparator
  Prepend
  Separate
  Append
  Both
}

///|
priv enum OutputMode {
  Summarize
  AllRepeated(GroupSeparator)
  EveryGroup(GroupSeparator)
}

///|
fn normalized_args(args : ArrayView[String]) -> Array[String] {
  let result : Array[String] = []
  let mut options = true
  let mut value_next = false
  for arg in args {
    if value_next {
      value_next = false
      result.push(arg)
      continue
    }
    if options && arg == "--" {
      options = false
      result.push(arg)
    } else if options && arg == "--all-repeated" {
      result.push("--all-repeated=none")
    } else if options && arg == "--group" {
      result.push("--group=separate")
    } else {
      result.push(arg)
    }
    if options {
      if arg is ("--skip-fields" | "--skip-chars" | "--check-chars") {
        value_next = true
      } else if arg.has_prefix("-") && !arg.has_prefix("--") {
        for offset in 1..<arg.length() {
          if arg[offset] is ('f' | 's' | 'w') {
            value_next = offset + 1 == arg.length()
            break
          }
        }
      }
    }
  }
  result
}

///|
fn parse_args(args : ArrayView[String]) -> @cli.ParsedArgs raise @cli.CliError {
  @cli.parse(normalized_args(args), [
    @cli.flag("count", short='c'),
    @cli.flag("repeated", short='d'),
    // Long optional values and the value-free short flag share one public name.
    @cli.option("all-repeated"),
    @cli.flag("all-repeated", short='D'),
    @cli.option("group"),
    @cli.flag("unique", short='u'),
    @cli.flag("ignore-case", short='i'),
    @cli.option("skip-fields", short='f'),
    @cli.option("skip-chars", short='s'),
    @cli.option("check-chars", short='w'),
    @cli.flag("zero-terminated", short='z'),
    @cli.flag("help"),
  ])
}

///|
fn parse_group_separator(
  value : String,
  all_repeated : Bool,
) -> GroupSeparator raise CliError {
  let methods = if all_repeated {
    ["none", "prepend", "separate"]
  } else {
    ["prepend", "append", "separate", "both"]
  }
  let matches = methods.filter(choice => choice.has_prefix(value))
  if matches.length() != 1 {
    let option = if all_repeated { "--all-repeated" } else { "--group" }
    let problem = if matches.is_empty() { "invalid" } else { "ambiguous" }
    let valid = methods.map(choice => "  - '\{choice}'\n").join("")
    raise CliError(
      "uniq: \{problem} argument '\{value}' for '\{option}'\nValid arguments are:\n\{valid}Try 'uniq --help' for more information.\n",
    )
  }
  match matches[0] {
    "none" => NoSeparator
    "prepend" => Prepend
    "append" => Append
    "both" => Both
    _ => Separate
  }
}

///|
fn output_mode(parsed : @cli.ParsedArgs) -> OutputMode raise CliError {
  let mut repeated_separator = NoSeparator
  for value in parsed.occurrences.get("all-repeated").unwrap_or([]) {
    repeated_separator = match value {
      Some(value) => parse_group_separator(value, true)
      None => NoSeparator
    }
  }
  let mut group_separator = Separate
  for value in parsed.values("group") {
    group_separator = parse_group_separator(value, false)
  }
  let all_repeated = parsed.contains("all-repeated")
  if parsed.contains("group") &&
    (
      parsed.contains("count") ||
      parsed.contains("repeated") ||
      parsed.contains("unique") ||
      all_repeated
    ) {
    raise CliError(
      "uniq: --group is mutually exclusive with -c/-d/-D/-u\nTry 'uniq --help' for more information.\n",
    )
  }
  if parsed.contains("count") && all_repeated {
    raise CliError(
      "uniq: printing all duplicated lines and repeat counts is meaningless\nTry 'uniq --help' for more information.\n",
    )
  }
  if parsed.contains("group") {
    EveryGroup(group_separator)
  } else if all_repeated {
    AllRepeated(repeated_separator)
  } else {
    Summarize
  }
}

///|
fn pad_left(text : String, width : Int32) -> String {
  let sb = StringBuilder()
  for _ in 0..<(width - text.length()) {
    sb.write_char(' ')
  }
  sb.write_string(text)
  sb.to_string()
}

///|
fn parse_count(
  text : String,
  option : String,
  gnu_description? : String,
) -> Int32 raise CliError {
  let message = match gnu_description {
    Some(description) => "uniq: \{text}: invalid number of \{description}"
    None => "uniq: invalid number of \{option}: '\{text}'"
  }
  let count = @string.parse_int(text) catch { _ => raise CliError(message) }
  if count < 0 {
    raise CliError(message)
  }
  count
}

///|
fn is_blank(byte : Byte) -> Bool {
  byte is (b' ' | b'\t')
}

///|
fn comparison_key(
  line : BytesView,
  skip_fields : Int32,
  skip_chars : Int32,
  check_chars : Int32?,
  ignore_case : Bool,
) -> BytesView {
  let mut start = 0
  for _ in 0..<skip_fields {
    while start < line.length() && is_blank(line[start]) {
      start += 1
    }
    while start < line.length() && !is_blank(line[start]) {
      start += 1
    }
  }
  start = Int32::min(line.length(), start + skip_chars)
  let end = match check_chars {
    Some(width) => Int32::min(line.length(), start + width)
    None => line.length()
  }
  if !ignore_case {
    return line[start:end]
  }
  let folded : Array[Byte] = []
  for byte in line[start:end] {
    let value = byte.to_int()
    folded.push(
      if value >= 0x41 && value <= 0x5A {
        (value + 0x20).to_byte()
      } else {
        byte
      },
    )
  }
  Bytes::from_array(folded)[:]
}

///|
fn write_group(
  writer : @buffer.Buffer,
  line : BytesView,
  count : Int32,
  show_count : Bool,
  only_repeated : Bool,
  only_unique : Bool,
  delimiter : Byte,
) -> Unit {
  let selected = if only_repeated && only_unique {
    false
  } else if only_repeated {
    count > 1
  } else if only_unique {
    count == 1
  } else {
    true
  }
  if selected {
    if show_count {
      writer.write_string_utf8(pad_left(count.to_string(), 7) + " ")
    }
    write_record(writer, line, delimiter)
  }
}

///|
fn write_record(
  writer : @buffer.Buffer,
  line : BytesView,
  delimiter : Byte,
) -> Unit {
  writer.write_bytes(line)
  writer.write_byte(delimiter)
}

///|
async fn process_reader(
  reader : &@io.Reader,
  show_count : Bool,
  only_repeated : Bool,
  only_unique : Bool,
  ignore_case : Bool,
  skip_fields : Int32,
  skip_chars : Int32,
  check_chars : Int32?,
  delimiter : Byte,
  mode : OutputMode,
  writer~ : &@io.Writer = @stdio.stdout,
) -> Unit {
  let scanner = @stream.RecordReader::new(reader, delimiter~)
  let destination = writer
  let writer = @buffer.Buffer(size_hint=@stream.chunk_size)
  defer @stream.flush_buffer(destination, writer)
  let mut previous : BytesView? = None
  let mut previous_key : BytesView? = None
  let mut count = 0
  let mut repeated_group_printed = false
  while scanner.next_batch() is Some(batch) {
    while batch.next() is Some(record) {
      let key = comparison_key(
        record.data,
        skip_fields,
        skip_chars,
        check_chars,
        ignore_case,
      )
      match mode {
        EveryGroup(separator) => {
          let first_group = previous_key is None
          let new_group = previous_key is None || previous_key != Some(key)
          if new_group &&
            (
              separator is (Prepend | Both) ||
              (!first_group && separator is (Separate | Append))
            ) {
            write_record(writer, b"", delimiter)
          }
          write_record(writer, record.data, delimiter)
          previous_key = Some(key)
        }
        AllRepeated(separator) =>
          match (previous, previous_key) {
            (Some(pending), Some(old_key)) if old_key == key => {
              if count == 1 {
                if separator is Prepend ||
                  (separator is Separate && repeated_group_printed) {
                  write_record(writer, b"", delimiter)
                }
                repeated_group_printed = true
                count = 2
              }
              write_record(writer, pending, delimiter)
              previous = Some(record.data)
            }
            _ => {
              if count > 1 && !only_unique && previous is Some(pending) {
                write_record(writer, pending, delimiter)
              }
              previous = Some(record.data)
              previous_key = Some(key)
              count = 1
            }
          }
        Summarize =>
          match (previous, previous_key) {
            (Some(_), Some(old_key)) if old_key == key => count += 1
            (Some(old), _) => {
              write_group(
                writer, old, count, show_count, only_repeated, only_unique, delimiter,
              )
              previous = Some(record.data)
              previous_key = Some(key)
              count = 1
            }
            _ => {
              previous = Some(record.data)
              previous_key = Some(key)
              count = 1
            }
          }
      }
      if writer.length() >= @stream.chunk_size {
        @stream.flush_buffer(destination, writer)
      }
    }
  }
  match mode {
    Summarize =>
      if previous is Some(value) {
        write_group(
          writer, value, count, show_count, only_repeated, only_unique, delimiter,
        )
      }
    EveryGroup(Append | Both) =>
      if previous_key is Some(_) {
        write_record(writer, b"", delimiter)
      }
    AllRepeated(_) =>
      if count > 1 && !only_unique && previous is Some(pending) {
        write_record(writer, pending, delimiter)
      }
    _ => ()
  }
}

///|
async fn main {
  let metadata_args = @env.args()[1:]
  if metadata_args.length() == 1 && metadata_args[0] == "--version" {
    @stdio.stdout.write("uniq 0.2.3\n")
    return
  }
  let args = @env.args()[1:]
  let parsed = parse_args(args) catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.write("uniq: \{message}: '\{option}'\n")
      @sys.exit(2)
      return
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.write(
      "Usage: uniq [-cduDiz] [--all-repeated[=METHOD]] [--group[=METHOD]] [-f FIELDS] [-s CHARS] [-w CHARS] [FILE]\n      --help      display this help and exit\n      --version   display version and exit\n",
    )
    return
  }
  if parsed.operands.length() > 1 {
    @stdio.stderr.write("uniq: extra operand: '\{parsed.operands[1]}'\n")
    @sys.exit(2)
    return
  }
  let mode = output_mode(parsed) catch {
    CliError(message) => {
      @stdio.stderr.write(message)
      @sys.exit(1)
      return
    }
  }
  let (skip_fields, skip_chars, check_chars) = try {
    let gnu_counts = mode is AllRepeated(_)
    let fields = match parsed.last_value("skip-fields") {
      Some(text) =>
        parse_count(
          text,
          "fields",
          gnu_description?=if gnu_counts {
            Some("fields to skip")
          } else {
            None
          },
        )
      None => 0
    }
    let chars = match parsed.last_value("skip-chars") {
      Some(text) =>
        parse_count(
          text,
          "characters",
          gnu_description?=if gnu_counts { Some("bytes to skip") } else { None },
        )
      None => 0
    }
    let width = match parsed.last_value("check-chars") {
      Some(text) =>
        Some(
          parse_count(
            text,
            "characters",
            gnu_description?=if gnu_counts {
              Some("bytes to compare")
            } else {
              None
            },
          ),
        )
      None => None
    }
    (fields, chars, width)
  } catch {
    CliError(message) => {
      @stdio.stderr.write(message + "\n")
      @sys.exit(if mode is AllRepeated(_) { 1 } else { 2 })
      return
    }
  }
  let delimiter : Byte = if parsed.contains("zero-terminated") {
    b'\x00'
  } else {
    b'\n'
  }
  let path = if parsed.operands.is_empty() { "-" } else { parsed.operands[0] }
  try {
    if path == "-" {
      process_reader(
        @stdio.stdin,
        parsed.contains("count"),
        parsed.contains("repeated"),
        parsed.contains("unique"),
        parsed.contains("ignore-case"),
        skip_fields,
        skip_chars,
        check_chars,
        delimiter,
        mode,
      )
    } else {
      let file = @fs.open(path, mode=ReadOnly)
      defer file.close()
      process_reader(
        file,
        parsed.contains("count"),
        parsed.contains("repeated"),
        parsed.contains("unique"),
        parsed.contains("ignore-case"),
        skip_fields,
        skip_chars,
        check_chars,
        delimiter,
        mode,
      )
    }
  } catch {
    err => {
      @stdio.stderr.write("uniq: \{err}\n")
      @sys.exit(1)
      return
    }
  }
}
