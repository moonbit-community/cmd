///|
priv suberror CliError {
  CliError(String)
}

///|
fn hex_digit(n : Int) -> Char {
  if n < 10 {
    (0x30 + n).unsafe_to_char()
  } else {
    (0x61 + n - 10).unsafe_to_char()
  }
}

///|
fn write_hex_byte(sb : StringBuilder, b : Byte) -> Unit {
  sb.write_char(hex_digit(b.to_int() >> 4))
  sb.write_char(hex_digit(b.to_int() & 0xF))
}

///|
fn hex_val(byte : Byte) -> Int {
  let value = byte.to_int()
  if value >= 0x30 && value <= 0x39 {
    value - 0x30
  } else if value >= 0x61 && value <= 0x66 {
    value - 0x61 + 10
  } else if value >= 0x41 && value <= 0x46 {
    value - 0x41 + 10
  } else {
    -1
  }
}

///|
fn dump_line(data : ArrayView[Byte], cols : Int, offset : Int) -> String {
  let sb = StringBuilder()
  for k in 0..<8 {
    sb.write_char(hex_digit((offset >> ((7 - k) * 4)) & 0xF))
  }
  sb.write_string(": ")
  for index in 0..<cols {
    if index > 0 && index % 2 == 0 {
      sb.write_char(' ')
    }
    if index < data.length() {
      write_hex_byte(sb, data[index])
    } else {
      sb.write_string("  ")
    }
  }
  sb.write_string("  ")
  for byte in data {
    let code = byte.to_int()
    if code >= 0x20 && code <= 0x7E {
      sb.write_char(code.unsafe_to_char())
    } else {
      sb.write_char('.')
    }
  }
  sb.write_char('\n')
  sb.to_string()
}

///|
fn limited_length(length : Int, remaining : Int?) -> Int {
  match remaining {
    Some(value) => if value < length { value } else { length }
    None => length
  }
}

///|
async fn dump_stream(
  reader : &@io.Reader,
  plain : Bool,
  cols : Int,
  limit : Int?,
  start_offset : Int64,
) -> Unit {
  let pending : Array[Byte] = []
  let mut offset = start_offset.to_int()
  let mut plain_column = 0
  let mut remaining = limit
  while remaining != Some(0) && @stream.read_chunk(reader) is Some(chunk) {
    let take = limited_length(chunk.length(), remaining)
    if remaining is Some(value) {
      remaining = Some(value - take)
    }
    if plain {
      let out = StringBuilder()
      for byte in chunk[0:take] {
        write_hex_byte(out, byte)
        plain_column += 1
        if plain_column == cols {
          out.write_char('\n')
          plain_column = 0
        }
      }
      @stdio.stdout.write(out.to_string())
    } else {
      let data : Array[Byte] = []
      data.append(pending)
      pending.clear()
      for byte in chunk[0:take] {
        data.push(byte)
      }
      let mut index = 0
      while index + cols <= data.length() {
        @stdio.stdout.write(dump_line(data[index:index + cols], cols, offset))
        index += cols
        offset += cols
      }
      for byte in data[index:] {
        pending.push(byte)
      }
    }
  }
  if plain {
    if plain_column != 0 {
      @stdio.stdout.write("\n")
    }
  } else if !pending.is_empty() {
    @stdio.stdout.write(dump_line(pending, cols, offset))
  }
}

///|
fn reverse_dump_line(line : Bytes) -> (Int, Bytes)? {
  let out : Array[Byte] = []
  if line.length() < 9 {
    return None
  }
  let mut offset = 0
  for index in 0..<8 {
    let value = hex_val(line[index])
    if value < 0 {
      return None
    }
    offset = (offset << 4) | value
  }
  let mut i = 8
  while i < line.length() && line[i] != b':' {
    i += 1
  }
  if i >= line.length() {
    return None
  }
  i += 1
  while i < line.length() {
    if line[i] == b' ' {
      if i + 1 < line.length() && line[i + 1] == b' ' {
        break
      }
      i += 1
      continue
    }
    if i + 1 >= line.length() {
      return None
    }
    let high = hex_val(line[i])
    let low = hex_val(line[i + 1])
    if high < 0 || low < 0 {
      return None
    }
    out.push(((high << 4) | low).to_byte())
    i += 2
  }
  Some((offset, Bytes::from_array(out)))
}

///|
async fn reverse_plain_stream(reader : &@io.Reader) -> Unit {
  let mut high = -1
  while @stream.read_chunk(reader) is Some(chunk) {
    let out : Array[Byte] = []
    for byte in chunk {
      if byte is (b' ' | b'\t' | b'\n' | b'\r') {
        continue
      }
      let value = hex_val(byte)
      if value < 0 {
        raise CliError(
          "xxd: invalid hex character: '\{byte.to_int().unsafe_to_char()}'",
        )
      }
      if high < 0 {
        high = value
      } else {
        out.push(((high << 4) | value).to_byte())
        high = -1
      }
    }
    if !out.is_empty() {
      @stdio.stdout.write(Bytes::from_array(out))
    }
  }
  if high >= 0 {
    raise CliError("xxd: odd number of hex digits")
  }
}

///|
async fn reverse_dump_stream(reader : &@io.Reader) -> Unit {
  let scanner = @stream.LineScanner::new(reader)
  let output : Array[Byte] = []
  while scanner.next() is Some(line) {
    match reverse_dump_line(line.data) {
      Some((line_offset, bytes)) => {
        if line_offset > 16 * 1024 * 1024 {
          raise CliError("xxd: addressed offset is too large")
        }
        let mut offset = line_offset
        while output.length() < offset {
          output.push(b'\x00')
        }
        for byte in bytes {
          if offset < output.length() {
            output[offset] = byte
          } else {
            output.push(byte)
          }
          offset += 1
        }
      }
      None => raise CliError("xxd: malformed hex dump line")
    }
  }
  @stdio.stdout.write(Bytes::from_array(output))
}

///|
fn include_name(path : String, symbol_name : String?) -> String {
  if symbol_name is Some(value) {
    return value
  }
  let raw = if path == "-" { "" } else { path }
  let normalized = StringBuilder()
  for char in raw {
    if char is ('a'..='z' | 'A'..='Z' | '0'..='9' | '_') {
      normalized.write_char(char)
    } else {
      normalized.write_char('_')
    }
  }
  let raw = normalized.to_string()
  let result = raw
  if result == "" {
    "data"
  } else {
    result
  }
}

///|
fn include_output(path : String, data : Bytes, symbol_name : String?) -> String {
  if path == "-" && symbol_name is None {
    let out = StringBuilder()
    for index, byte in data {
      write_hex_byte(out, byte)
      if index + 1 < data.length() {
        out.write_string(", ")
      }
    }
    if !data.is_empty() {
      out.write_char('\n')
    }
    return out.to_string()
  }
  let name = include_name(path, symbol_name)
  let out = StringBuilder()
  out.write_string("unsigned char \{name}[] = {")
  for index, byte in data {
    if index % 12 == 0 {
      out.write_string("\n  ")
    }
    out.write_string("0x")
    write_hex_byte(out, byte)
    if index + 1 < data.length() {
      out.write_string(", ")
    }
  }
  if !data.is_empty() {
    out.write_char('\n')
  }
  out.write_string("};\nunsigned int \{name}_len = \{data.length()};\n")
  out.to_string()
}

///|
fn parse_number(
  parsed : @cli.ParsedArgs,
  name : String,
  minimum? : Int = 1,
) -> Int? raise CliError {
  match parsed.last_value(name) {
    Some(text) => {
      let n = @string.parse_int(text) catch {
        _ => raise CliError("xxd: invalid -\{name} value: '\{text}'")
      }
      if n < minimum {
        raise CliError("xxd: invalid -\{name} value: '\{text}'")
      }
      Some(n)
    }
    None => None
  }
}

///|
fn parse_seek(parsed : @cli.ParsedArgs) -> Int64? raise CliError {
  match parsed.last_value("seek") {
    Some(text) => {
      let value = @string.parse_int64(text) catch {
        _ => raise CliError("xxd: invalid seek offset: '\{text}'")
      }
      if value < 0L {
        raise CliError("xxd: negative seek offset is not supported")
      }
      if value > 2147483647L {
        raise CliError("xxd: seek offset is too large for this target")
      }
      Some(value)
    }
    None => None
  }
}

///|
async fn skip_bytes(reader : &@io.Reader, count : Int64) -> Int64 {
  let buffer : FixedArray[Byte] = FixedArray::make(65536, 0)
  let mut remaining = count
  while remaining > 0L {
    let limit = remaining.min(buffer.length().to_int64()).to_int()
    let n = reader.read(buffer, max_len=limit)
    if n == 0 {
      break
    }
    remaining -= n.to_int64()
  }
  count - remaining
}

///|
async fn write_zero_prefix(count : Int64) -> Unit {
  let mut remaining = count
  while remaining > 0L {
    let length = remaining.min(65536L).to_int()
    @stdio.stdout.write(Bytes::make(length, b'\x00'))
    remaining -= length.to_int64()
  }
}

///|
async fn main {
  let args = @env.args()[1:].map(arg => {
    if arg == "--revert" {
      "--reverse"
    } else {
      arg
    }
  })
  let parsed = @cli.parse(args, [
    @cli.flag("include", short='i'),
    @cli.flag("plain", short='p'),
    @cli.flag("reverse", short='r'),
    @cli.option("cols", short='c'),
    @cli.option("len", short='l'),
    @cli.option("seek", short='s'),
    @cli.option("name", short='n'),
    @cli.flag("help"),
  ]) catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.write("xxd: \{message}: '\{option}'\n")
      @sys.exit(2)
      return
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.write(
      "Usage: xxd [-ipr] [-c COLS] [-l LEN] [-s OFFSET] [FILE]\n",
    )
    return
  }
  if parsed.operands.length() > 1 {
    @stdio.stderr.write("xxd: extra operand: '\{parsed.operands[1]}'\n")
    @sys.exit(2)
    return
  }
  let plain = parsed.contains("plain")
  let reverse = parsed.contains("reverse")
  let include_mode = parsed.contains("include")
  let (cols_opt, len_opt, seek_opt) = (
    parse_number(parsed, "cols"),
    parse_number(parsed, "len", minimum=0),
    parse_seek(parsed),
  ) catch {
    CliError(msg) => {
      @stdio.stderr.write("\{msg}\n")
      @sys.exit(2)
      return
    }
  }
  let cols = match cols_opt {
    Some(n) => n
    None => if plain { 30 } else { 16 }
  }
  let inputs = parsed.operands
  let path = if inputs.is_empty() { "-" } else { inputs[0] }
  try {
    if include_mode {
      let data = if path == "-" {
        @stdio.stdin.read_all().binary()
      } else {
        @fs.read_file(path).binary()
      }
      @stdio.stdout.write(include_output(path, data, parsed.last_value("name")))
    } else if path == "-" {
      if reverse {
        if plain {
          write_zero_prefix(seek_opt.unwrap_or(0L).max(0L))
          reverse_plain_stream(@stdio.stdin)
        } else {
          reverse_dump_stream(@stdio.stdin)
        }
      } else {
        let skipped = skip_bytes(@stdio.stdin, seek_opt.unwrap_or(0L))
        dump_stream(@stdio.stdin, plain, cols, len_opt, skipped)
      }
    } else {
      let file = @fs.open(path, mode=ReadOnly)
      defer file.close()
      if reverse {
        if plain {
          write_zero_prefix(seek_opt.unwrap_or(0L).max(0L))
          reverse_plain_stream(file)
        } else {
          reverse_dump_stream(file)
        }
      } else {
        let skipped = skip_bytes(file, seek_opt.unwrap_or(0L))
        dump_stream(file, plain, cols, len_opt, skipped)
      }
    }
  } catch {
    CliError(msg) => {
      @stdio.stderr.write("\{msg}\n")
      @sys.exit(1)
      return
    }
    err => {
      @stdio.stderr.write("xxd: \{err}\n")
      @sys.exit(1)
      return
    }
  }
}
