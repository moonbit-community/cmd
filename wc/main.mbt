///|
priv struct Counts {
  mut lines : Int64
  mut words : Int64
  mut chars : Int64
  mut bytes : Int64
}

///|
fn Counts::new() -> Counts {
  { lines: 0, words: 0, chars: 0, bytes: 0, }
}

///|
fn Counts::add(self : Counts, other : Counts) -> Unit {
  self.lines += other.lines
  self.words += other.words
  self.chars += other.chars
  self.bytes += other.bytes
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
  while @stream.read_chunk(reader) is Some(chunk) {
    counts.bytes += chunk.length().to_int64()
    for b in chunk {
      if b is b'\n' {
        counts.lines += 1
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
  counts
}

///|
priv struct Selection {
  lines : Bool
  words : Bool
  chars : Bool
  bytes : Bool
}

///|
fn render_counts(
  counts : Counts,
  selection : Selection,
  name : String?,
) -> String {
  let parts : Array[String] = []
  if selection.lines {
    parts.push(counts.lines.to_string())
  }
  if selection.words {
    parts.push(counts.words.to_string())
  }
  if selection.chars {
    parts.push(counts.chars.to_string())
  }
  if selection.bytes {
    parts.push(counts.bytes.to_string())
  }
  if name is Some(n) {
    parts.push(n)
  }
  parts.join(" ")
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
    @cli.flag("help"),
  ]) catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.write("wc: \{message}: '\{option}'\n")
      @sys.exit(2)
      return
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.write("Usage: wc [-lwcm] [FILE...]\n")
    return
  }
  let lines = parsed.contains("lines")
  let words = parsed.contains("words")
  let chars = parsed.contains("chars")
  let bytes = parsed.contains("bytes")
  let selection : Selection = if lines || words || chars || bytes {
    { lines, words, chars, bytes, }
  } else {
    { lines: true, words: true, chars: false, bytes: true, }
  }
  let files = parsed.operands
  let total = Counts::new()
  let mut failed = false
  if files.is_empty() {
    let counts = count_reader(@stdio.stdin)
    @stdio.stdout.write(render_counts(counts, selection, None) + "\n")
  } else {
    for path in files {
      let counts = count_source(path) catch {
        err => {
          @stdio.stderr.write("wc: \{err}\n")
          failed = true
          continue
        }
      }
      total.add(counts)
      @stdio.stdout.write(render_counts(counts, selection, Some(path)) + "\n")
    }
    if files.length() > 1 {
      @stdio.stdout.write(render_counts(total, selection, Some("total")) + "\n")
    }
  }
  if failed {
    @sys.exit(1)
  }
}
