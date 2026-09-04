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
fn is_continuation(b : Byte) -> Bool {
  (b.to_int() & 0xC0) == 0x80
}

///|
/// Count valid UTF-8 encoded characters. Bytes that are not part of a valid
/// sequence are skipped without being counted, like GNU wc -m.
fn count_utf8_chars(data : Bytes, at_eof : Bool) -> (Int64, Int) {
  let mut count : Int64 = 0
  let mut i = 0
  while i < data.length() {
    let b0 = data[i].to_int()
    if b0 < 0x80 {
      count += 1
      i += 1
      continue
    }
    // (sequence length, valid range for the second byte)
    let (len, lo1, hi1) = if b0 >= 0xC2 && b0 <= 0xDF {
      (2, 0x80, 0xBF)
    } else if b0 == 0xE0 {
      (3, 0xA0, 0xBF)
    } else if (b0 >= 0xE1 && b0 <= 0xEC) || b0 == 0xEE || b0 == 0xEF {
      (3, 0x80, 0xBF)
    } else if b0 == 0xED {
      (3, 0x80, 0x9F)
    } else if b0 == 0xF0 {
      (4, 0x90, 0xBF)
    } else if b0 >= 0xF1 && b0 <= 0xF3 {
      (4, 0x80, 0xBF)
    } else if b0 == 0xF4 {
      (4, 0x80, 0x8F)
    } else {
      (0, 0, 0)
    }
    if len > 0 && i + len > data.length() && !at_eof {
      break
    }
    if len == 0 || i + len > data.length() {
      i += 1
      continue
    }
    let second = data[i + 1].to_int()
    if second < lo1 || second > hi1 {
      i += 1
      continue
    }
    let mut ok = true
    for k in 2..<len {
      if !is_continuation(data[i + k]) {
        ok = false
        break
      }
    }
    if ok {
      count += 1
      i += len
    } else {
      i += 1
    }
  }
  (count, i)
}

///|
async fn count_reader(reader : &@io.Reader) -> Counts {
  let counts = Counts::new()
  let pending : Array[Byte] = []
  let mut in_word = false
  let mut line_width : Int64 = 0
  while @stream.read_chunk(reader) is Some(chunk) {
    counts.bytes += chunk.length().to_int64()
    for b in chunk {
      if b is b'\n' {
        counts.lines += 1
        counts.max_line_length = Int64::max(counts.max_line_length, line_width)
        line_width = 0
      } else if b is b'\t' {
        line_width += 8 - line_width % 8
      } else if b.to_int() >= 0x20 && b.to_int() <= 0x7E {
        line_width += 1
      }
      if is_space_byte(b) {
        in_word = false
      } else if !in_word {
        in_word = true
        counts.words += 1
      }
      pending.push(b)
    }
    let data = Bytes::from_array(pending)
    let (chars, consumed) = count_utf8_chars(data, false)
    counts.chars += chars
    if consumed > 0 {
      let remaining = pending[consumed:].to_owned()
      pending.clear()
      pending.append(remaining)
    }
  }
  if !pending.is_empty() {
    counts.chars += count_utf8_chars(Bytes::from_array(pending), true).0
  }
  counts.max_line_length = Int64::max(counts.max_line_length, line_width)
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
fn pad_left(text : String, width : Int) -> String {
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
  width : Int,
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
fn count_width(counts : Counts, selection : Selection) -> Int {
  let mut width = 1
  if selection.lines {
    width = Int::max(width, counts.lines.to_string().length())
  }
  if selection.words {
    width = Int::max(width, counts.words.to_string().length())
  }
  if selection.chars {
    width = Int::max(width, counts.chars.to_string().length())
  }
  if selection.bytes {
    width = Int::max(width, counts.bytes.to_string().length())
  }
  if selection.max_line_length {
    width = Int::max(width, counts.max_line_length.to_string().length())
  }
  width
}

///|
fn nul_file_names(data : Bytes) -> Array[String] raise {
  let names : Array[String] = []
  let mut start = 0
  for index, byte in data {
    if byte is b'\x00' {
      if index == start {
        raise CliError("wc: invalid zero-length file name")
      }
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
async fn count_source(path : String) -> Counts {
  if path == "-" {
    count_reader(@stdio.stdin)
  } else {
    let file = @async_fs.open(path, mode=ReadOnly)
    defer file.close()
    count_reader(file)
  }
}

///|
async fn main {
  let args = @env.args()[1:]
  let parsed = @cli.parse(args, [
    @cli.flag("lines", short='l'),
    @cli.flag("words", short='w'),
    @cli.flag("bytes", short='c'),
    @cli.flag("chars", short='m'),
    @cli.flag("max-line-length", short='L'),
    @cli.option("files0-from"),
    @cli.flag("help"),
  ]) catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.write("wc: \{message}: '\{option}'\n")
      @sys.exit(2)
      return
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.write("Usage: wc [-lwcmL] [--files0-from=FILE] [FILE...]\n")
    return
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
  if parsed.contains("files0-from") && files.is_empty() {
    return
  }
  let total = Counts::new()
  let mut failed = false
  if files.is_empty() {
    let counts = count_reader(@stdio.stdin)
    @stdio.stdout.write(render_counts(counts, selection, None, 1) + "\n")
  } else {
    let completed : Array[(Counts, String)] = []
    for path in files {
      let counts = count_source(path) catch {
        err => {
          @stdio.stderr.write("wc: \{err}\n")
          failed = true
          continue
        }
      }
      total.add(counts)
      completed.push((counts, path))
    }
    let width = if files.length() > 1 {
      count_width(total, selection)
    } else {
      1
    }
    for item in completed {
      let (counts, path) = item
      @stdio.stdout.write(
        render_counts(counts, selection, Some(path), width) + "\n",
      )
    }
    if files.length() > 1 {
      @stdio.stdout.write(
        render_counts(total, selection, Some("total"), width) + "\n",
      )
    }
  }
  if failed {
    @sys.exit(1)
  }
}
