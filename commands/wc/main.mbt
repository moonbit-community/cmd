///|
priv suberror CliError {
  CliError(String)
}

///|
priv struct Counts {
  mut lines : Int64
  mut words : Int64
  mut chars : Int64
  mut bytes : Int64
  mut max_line_length : Int64
}

///|
fn Counts::new() -> Counts {
  { lines: 0, words: 0, chars: 0, bytes: 0, max_line_length: 0, }
}

///|
fn Counts::add(self : Counts, other : Counts) -> Unit {
  self.lines += other.lines
  self.words += other.words
  self.chars += other.chars
  self.bytes += other.bytes
  self.max_line_length = Int64::max(self.max_line_length, other.max_line_length)
}

///|
fn is_space_byte(b : Byte) -> Bool {
  b is (b' ' | b'\t' | b'\n' | b'\r' | 0x0B | 0x0C)
}

///|
async fn count_reader(
  reader : &@io.Reader,
  selection : Selection,
  counts? : Counts,
) -> Counts {
  let counts = match counts {
    Some(counts) => counts
    None => Counts::new()
  }
  let buffer = FixedArray::make(1048576, b'\x00')
  let data = buffer.unsafe_reinterpret_as_bytes()
  let mut in_word = false
  let mut line_width : Int64 = 0
  defer {
    counts.max_line_length = Int64::max(counts.max_line_length, line_width)
  }
  while reader.read(buffer, max_len=buffer.length()) is count && count > 0 {
    let chunk = data[:count]
    if selection.bytes {
      counts.bytes += count.to_int64()
    }
    if selection.chars {
      counts.chars += count.to_int64()
    }
    if selection.lines && !selection.words && !selection.max_line_length {
      counts.lines += @bytesearch.count(b'\n', buffer, 0, count).to_int64()
    } else if selection.words && !selection.max_line_length {
      let mut offset = 0
      let mut lines = 0
      let mut words = 0
      while offset + 16 <= count {
        let block = @v128.v128_load(buffer, offset)
        let spaces = @v128.i8x16_bitmask(
          @v128.v128_or_(
            @v128.i8x16_eq(block, @v128.i8x16_splat(b' ')),
            @v128.v128_and_(
              @v128.i8x16_ge_u(block, @v128.i8x16_splat(b'\t')),
              @v128.i8x16_le_u(block, @v128.i8x16_splat(b'\r')),
            ),
          ),
        )
        // A word starts at a non-space byte preceded by space, including the
        // carried final-byte classification from the preceding vector/read.
        let preceding_space = if in_word { 0 } else { 1 }
        words += ((spaces ^ 0xFFFF) & ((spaces << 1) | preceding_space)).popcnt()
        in_word = (spaces & 0x8000) == 0
        if selection.lines {
          lines += @v128.i8x16_bitmask(
            @v128.i8x16_eq(block, @v128.i8x16_splat(b'\n')),
          ).popcnt()
        }
        offset += 16
      }
      while offset < count {
        let byte = buffer[offset]
        if selection.lines && byte == b'\n' {
          lines += 1
        }
        if is_space_byte(byte) {
          in_word = false
        } else if !in_word {
          words += 1
          in_word = true
        }
        offset += 1
      }
      counts.words += words.to_int64()
      counts.lines += lines.to_int64()
    } else if selection.lines || selection.words || selection.max_line_length {
      for b in chunk {
        if selection.lines && b is b'\n' {
          counts.lines += 1
        }
        if selection.max_line_length {
          if b is b'\n' {
            counts.max_line_length = Int64::max(
              counts.max_line_length,
              line_width,
            )
            line_width = 0
          } else if b is b'\t' {
            line_width += 8 - line_width % 8
          } else if b.to_int() >= 0x20 && b.to_int() <= 0x7E {
            line_width += 1
          }
        }
        if selection.words {
          if is_space_byte(b) {
            in_word = false
          } else if !in_word {
            in_word = true
            counts.words += 1
          }
        }
      }
    }
  }
  counts
}

///|
priv struct Selection {
  lines : Bool
  words : Bool
  chars : Bool
  bytes : Bool
  max_line_length : Bool
}

///|
fn pad_left(text : String, width : Int32) -> String {
  let output = StringBuilder()
  for _ in 0..<(width - text.length()) {
    output.write_char(' ')
  }
  output.write_string(text)
  output.to_string()
}

///|
fn render_counts(
  counts : Counts,
  selection : Selection,
  name : String?,
  width : Int32,
) -> String {
  let parts : Array[String] = []
  if selection.lines {
    parts.push(pad_left(counts.lines.to_string(), width))
  }
  if selection.words {
    parts.push(pad_left(counts.words.to_string(), width))
  }
  if selection.chars {
    parts.push(pad_left(counts.chars.to_string(), width))
  }
  if selection.bytes {
    parts.push(pad_left(counts.bytes.to_string(), width))
  }
  if selection.max_line_length {
    parts.push(pad_left(counts.max_line_length.to_string(), width))
  }
  if name is Some(n) {
    parts.push(n)
  }
  parts.join(" ")
}

///|
async fn count_width(files : Array[String], selection : Selection) -> Int32 {
  let counters = [
      selection.lines,
      selection.words,
      selection.chars,
      selection.bytes,
      selection.max_line_length,
    ]
    .filter(value => value)
    .length()
  if files.is_empty() || (files.length() == 1 && counters == 1) {
    return 1
  }
  let mut minimum = 1
  let mut size : UInt64 = 0
  for index, path in files {
    if path == "-" {
      minimum = 7
      continue
    }
    let bytes = try {
      if @async_fs.kind(path) == Regular {
        Some(@async_fs.file_size(path))
      } else {
        None
      }
    } catch {
      _ => {
        if index == 0 {
          return 1
        }
        continue
      }
    }
    match bytes {
      Some(bytes) => {
        let next = size + bytes.reinterpret_as_uint64()
        size = if next < size { 0xFFFFFFFFFFFFFFFFUL } else { next }
      }
      None => minimum = 7
    }
  }
  let mut width = 1
  while size >= 10 {
    size /= 10
    width += 1
  }
  width.max(minimum)
}

///|
priv enum TotalMode {
  Auto
  Always
  Only
  Never
}

///|
fn parse_total_mode(value : String) -> TotalMode raise CliError {
  let choices = ["auto", "always", "only", "never"]
  let matches = choices.filter(choice => choice.has_prefix(value))
  guard matches is [choice] else {
    let kind = if matches.is_empty() { "invalid" } else { "ambiguous" }
    raise CliError(
      "wc: \{kind} argument '\{value}' for '--total'\nValid arguments are:\n  - 'auto'\n  - 'always'\n  - 'only'\n  - 'never'\nTry 'wc --help' for more information.",
    )
  }
  match choice {
    "auto" => Auto
    "always" => Always
    "only" => Only
    _ => Never
  }
}

///|
fn nul_file_names(data : Bytes) -> Array[String] raise {
  let names : Array[String] = []
  let mut start = 0
  for index, byte in data {
    if byte is b'\x00' {
      names.push(@utf8.decode(data[start:index].to_owned()))
      start = index + 1
    }
  }
  if start < data.length() {
    names.push(@utf8.decode(data[start:].to_owned()))
  }
  names
}

///|
async fn read_file_list(path : String) -> Array[String] {
  let data = if path == "-" {
    @stdio.stdin.read_all().binary()
  } else {
    @async_fs.read_file(path).binary()
  }
  nul_file_names(data)
}

///|
fn quoted_name(path : String) -> String {
  if !path.is_empty() &&
    path
    .iter()
    .all(char => {
      char is ('a'..<='z' | 'A'..<='Z' | '0'..<='9') ||
      "_./=-+,:".contains(char.to_string())
    }) {
    path
  } else {
    "'" + path.replace_all(old="'", new="'\\''") + "'"
  }
}

///|
fn input_error(path : String, error : Error) -> String {
  let message = match error {
    @os_error.OSError(_, ..) as os_error =>
      if os_error.is_ENOENT() {
        "No such file or directory"
      } else if os_error.is_EACCES() {
        "Permission denied"
      } else if os_error.is_ENOTDIR() {
        "Not a directory"
      } else {
        os_error.to_string()
      }
    _ => error.to_string()
  }
  "wc: " + quoted_name(path) + ": " + message
}

///|
async fn read_counted(
  reader : &@io.Reader,
  path : String,
  selection : Selection,
) -> (Counts?, String?) {
  let counts = Counts::new()
  let error = try {
    ignore(count_reader(reader, selection, counts~))
    None
  } catch {
    error => Some(input_error(path, error))
  }
  (Some(counts), error)
}

///|
async fn count_source(
  path : String,
  selection : Selection,
) -> (Counts?, String?) {
  if path == "-" {
    read_counted(@stdio.stdin, path, selection)
  } else {
    let file = @async_fs.open(path, mode=ReadOnly) catch {
      error => return (None, Some(input_error(path, error)))
    }
    defer file.close()
    if file.kind() == Directory {
      (
        Some(Counts::new()),
        Some("wc: " + quoted_name(path) + ": Is a directory"),
      )
    } else {
      read_counted(file, path, selection)
    }
  }
}

///|
async fn main {
  let metadata_args = @env.args()[1:]
  if metadata_args.length() == 1 && metadata_args[0] == "--version" {
    @stdio.stdout.write("wc 0.2.5\n")
    return
  }
  let args = @env.args()[1:]
  let parsed = @cli.parse(args, [
    @cli.flag("lines", short='l'),
    @cli.flag("words", short='w'),
    @cli.flag("bytes", short='c'),
    @cli.flag("chars", short='m'),
    @cli.flag("max-line-length", short='L'),
    @cli.option("files0-from"),
    @cli.option("total"),
    @cli.flag("help"),
  ]) catch {
    @cli.CliError(option~, message~, ..) => {
      if option == "total" {
        @stdio.stderr.write(
          "wc: option '--total' requires an argument\nTry 'wc --help' for more information.\n",
        )
        @sys.exit(1)
        return
      }
      @stdio.stderr.write("wc: \{message}: '\{option}'\n")
      @sys.exit(2)
      return
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.write(
      "Usage: wc [-lwcmL] [--files0-from=FILE] [--total=WHEN] [FILE...]\n      --total=WHEN  print totals: auto (default), always, only, never\n      --help      display this help and exit\n      --version   display version and exit\nCounting uses the fixed C byte profile; -m counts every byte.\n",
    )
    return
  }
  let mode = parse_total_mode(parsed.last_value("total").unwrap_or("auto")) catch {
    CliError(message) => {
      @stdio.stderr.write(message + "\n")
      @sys.exit(1)
      return
    }
  }
  let lines = parsed.contains("lines")
  let words = parsed.contains("words")
  let chars = parsed.contains("chars")
  let bytes = parsed.contains("bytes")
  let max_line_length = parsed.contains("max-line-length")
  let selection : Selection = if lines ||
    words ||
    chars ||
    bytes ||
    max_line_length {
    { lines, words, chars, bytes, max_line_length, }
  } else {
    {
      lines: true,
      words: true,
      chars: false,
      bytes: true,
      max_line_length: false,
    }
  }
  if parsed.contains("files0-from") && !parsed.operands.is_empty() {
    @stdio.stderr.write("wc: extra operand with --files0-from\n")
    @sys.exit(1)
    return
  }
  let files = match parsed.last_value("files0-from") {
    Some(path) =>
      read_file_list(path) catch {
        err => {
          @stdio.stderr.write("wc: \{err}\n")
          @sys.exit(1)
          return
        }
      }
    None => parsed.operands
  }
  let implicit_stdin = files.is_empty() && !parsed.contains("files0-from")
  let sources = if implicit_stdin { ["-"] } else { files }
  let width = if mode is Only { 1 } else { count_width(sources, selection) }
  let total = Counts::new()
  let mut failed = false
  for index, path in sources {
    if path == "" {
      let prefix = match parsed.last_value("files0-from") {
        Some(list) => quoted_name(list) + ":" + (index + 1).to_string() + ": "
        None => ""
      }
      @stdio.stderr.write("wc: " + prefix + "invalid zero-length file name\n")
      failed = true
      continue
    }
    if path == "-" && parsed.last_value("files0-from") == Some("-") {
      @stdio.stderr.write(
        "wc: when reading file names from standard input, no file name of '-' allowed\n",
      )
      failed = true
      continue
    }
    let (counts, error) = count_source(path, selection)
    if error is Some(message) {
      @stdio.stderr.write(message + "\n")
      failed = true
    }
    if counts is Some(counts) {
      total.add(counts)
      if !(mode is Only) {
        let name = if implicit_stdin { None } else { Some(path) }
        @stdio.stdout.write(
          render_counts(counts, selection, name, width) + "\n",
        )
      }
    }
  }
  if mode is (Always | Only) || (mode is Auto && files.length() > 1) {
    @stdio.stdout.write(
      render_counts(
        total,
        selection,
        if mode is Only {
          None
        } else {
          Some("total")
        },
        width,
      ) +
      "\n",
    )
  }
  if failed {
    @sys.exit(1)
  }
}
