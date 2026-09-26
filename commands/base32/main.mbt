///|
priv suberror CliError {
  CliError(String)
}

///|
fn base32_char(v : Int) -> Char {
  if v < 26 {
    (0x41 + v).unsafe_to_char()
  } else {
    (0x32 + v - 26).unsafe_to_char()
  }
}

///|
fn base32_value(c : Char) -> Int raise CliError {
  match c {
    'A'..='Z' => c.to_int() - 0x41
    '2'..='7' => c.to_int() - 0x32 + 26
    _ => raise CliError("base32: invalid input character: '\{c}'")
  }
}

///|
fn append_wrapped(sb : StringBuilder, text : String, wrap : Int) -> Unit {
  let mut column = 0
  for c in text {
    sb.write_char(c)
    column += 1
    if wrap > 0 && column == wrap {
      sb.write_char('\n')
      column = 0
    }
  }
  if wrap > 0 && !text.is_empty() && column != 0 {
    sb.write_char('\n')
  }
}

///|
fn encode_bytes(input : Bytes, wrap : Int) -> Bytes {
  let encoded = StringBuilder()
  let mut index = 0
  while index < input.length() {
    let remaining = input.length() - index
    let count = if remaining > 5 { 5 } else { remaining }
    let b0 = input[index].to_int()
    let b1 = if count > 1 { input[index + 1].to_int() } else { 0 }
    let b2 = if count > 2 { input[index + 2].to_int() } else { 0 }
    let b3 = if count > 3 { input[index + 3].to_int() } else { 0 }
    let b4 = if count > 4 { input[index + 4].to_int() } else { 0 }
    let c0 = (b0 >> 3) & 0x1F
    let c1 = ((b0 << 2) | (b1 >> 6)) & 0x1F
    let c2 = (b1 >> 1) & 0x1F
    let c3 = ((b1 << 4) | (b2 >> 4)) & 0x1F
    let c4 = ((b2 << 1) | (b3 >> 7)) & 0x1F
    let c5 = (b3 >> 2) & 0x1F
    let c6 = ((b3 << 3) | (b4 >> 5)) & 0x1F
    let c7 = b4 & 0x1F
    encoded.write_char(base32_char(c0))
    encoded.write_char(base32_char(c1))
    if count == 1 {
      encoded.write_string("======")
    } else if count == 2 {
      encoded.write_char(base32_char(c2))
      encoded.write_char(base32_char(c3))
      encoded.write_string("====")
    } else if count == 3 {
      encoded.write_char(base32_char(c2))
      encoded.write_char(base32_char(c3))
      encoded.write_char(base32_char(c4))
      encoded.write_string("===")
    } else if count == 4 {
      encoded.write_char(base32_char(c2))
      encoded.write_char(base32_char(c3))
      encoded.write_char(base32_char(c4))
      encoded.write_char(base32_char(c5))
      encoded.write_char(base32_char(c6))
      encoded.write_string("=")
    } else {
      encoded.write_char(base32_char(c2))
      encoded.write_char(base32_char(c3))
      encoded.write_char(base32_char(c4))
      encoded.write_char(base32_char(c5))
      encoded.write_char(base32_char(c6))
      encoded.write_char(base32_char(c7))
    }
    index += count
  }
  let wrapped = StringBuilder()
  append_wrapped(wrapped, encoded.to_string(), wrap)
  @utf8.encode(wrapped.to_string())
}

///|
fn decode_block(block : Array[Byte], out : Array[Byte]) -> Unit raise CliError {
  if block.length() != 8 {
    raise CliError("base32: invalid input length")
  }
  let c0 = base32_value(block[0].to_int().unsafe_to_char())
  let c1 = base32_value(block[1].to_int().unsafe_to_char())
  // GNU emits each byte as soon as its required symbols are checked.
  out.push(((c0 << 3) | (c1 >> 2)).to_byte())
  if block[2] == b'=' {
    if block[3] != b'=' ||
      block[4] != b'=' ||
      block[5] != b'=' ||
      block[6] != b'=' ||
      block[7] != b'=' {
      raise CliError("base32: invalid padding")
    }
    return
  }
  let c2 = base32_value(block[2].to_int().unsafe_to_char())
  let c3 = base32_value(block[3].to_int().unsafe_to_char())
  out.push(((c1 << 6) | (c2 << 1) | (c3 >> 4)).to_byte())
  if block[4] == b'=' {
    if block[5] != b'=' || block[6] != b'=' || block[7] != b'=' {
      raise CliError("base32: invalid padding")
    }
    return
  }
  let c4 = base32_value(block[4].to_int().unsafe_to_char())
  out.push(((c3 << 4) | (c4 >> 1)).to_byte())
  if block[5] == b'=' {
    if block[6] != b'=' || block[7] != b'=' {
      raise CliError("base32: invalid padding")
    }
    return
  }
  let c5 = base32_value(block[5].to_int().unsafe_to_char())
  let c6 = base32_value(block[6].to_int().unsafe_to_char())
  out.push(((c4 << 7) | (c5 << 2) | (c6 >> 3)).to_byte())
  if block[7] != b'=' {
    let c7 = base32_value(block[7].to_int().unsafe_to_char())
    out.push(((c6 << 5) | c7).to_byte())
  }
}

///|
// Complete groups are emitted as soon as they are accepted. GNU base32
// preserves this valid prefix when a later group is malformed.
async fn decode_to_writer(
  input : Bytes,
  ignore_garbage : Bool,
  writer : &@io.Writer,
) -> Unit raise CliError {
  let block : Array[Byte] = []
  for byte in input {
    if byte == b'\n' {
      continue
    }
    let c = byte.to_int().unsafe_to_char()
    let valid = (c >= 'A' && c <= 'Z') || (c >= '2' && c <= '7') || c == '='
    if !valid {
      if ignore_garbage {
        continue
      }
      raise CliError("base32: invalid input character: '\{c}'")
    }
    block.push(byte)
    if block.length() == 8 {
      let decoded : Array[Byte] = []
      let mut decoding = true
      errdefer (if decoding && !decoded.is_empty() {
        writer.write(Bytes::from_array(decoded)) catch {
          write_err => raise CliError("base32: write failed: \{write_err}")
        }
      })
      decode_block(block, decoded)
      decoding = false
      writer.write(Bytes::from_array(decoded)) catch {
        err => raise CliError("base32: write failed: \{err}")
      }
      block.clear()
    }
  }
  if !block.is_empty() {
    raise CliError("base32: invalid input length")
  }
}

///|
async fn main {
  let args = @env.args()[1:]
  let parsed = @cli.parse(args, [
    @cli.flag("decode", short='d'),
    @cli.flag("ignore-garbage", short='i'),
    @cli.option("wrap", short='w'),
    @cli.flag("help"),
  ]) catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.write("base32: \{message}: '\{option}'\n")
      @sys.exit(2)
      return
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.write("Usage: base32 [-d] [-i] [-w COLS] [FILE]\n")
    return
  }
  if parsed.operands.length() > 1 {
    @stdio.stderr.write("base32: extra operand: '\{parsed.operands[1]}'\n")
    @sys.exit(2)
    return
  }
  let wrap_text = parsed.last_value("wrap").unwrap_or("76")
  let wrap = @string.parse_int(wrap_text) catch {
    _ => {
      @stdio.stderr.write("base32: invalid wrap size: '\{wrap_text}'\n")
      @sys.exit(2)
      return
    }
  }
  if wrap < 0 {
    @stdio.stderr.write("base32: invalid wrap size: '\{wrap_text}'\n")
    @sys.exit(2)
    return
  }
  let path = if parsed.operands.is_empty() { "-" } else { parsed.operands[0] }
  try {
    let input = if path == "-" {
      @stdio.stdin.read_all().binary()
    } else {
      let file = @fs.open(path, mode=ReadOnly)
      defer file.close()
      file.read_all().binary()
    }
    if parsed.contains("decode") {
      decode_to_writer(input, parsed.contains("ignore-garbage"), @stdio.stdout)
    } else {
      @stdio.stdout.write(encode_bytes(input, wrap))
    }
  } catch {
    CliError(msg) => {
      @stdio.stderr.write("\{msg}\n")
      @sys.exit(1)
      return
    }
    err => {
      @stdio.stderr.write("base32: \{err}\n")
      @sys.exit(1)
      return
    }
  }
}
