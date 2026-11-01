///|
priv suberror CliError {
  CliError(String)
}

///|
fn sextet(c : Char) -> Int32 raise CliError {
  match c {
    'A'..<='Z' => c.to_int() - 0x41
    'a'..<='z' => c.to_int() - 0x61 + 26
    '0'..<='9' => c.to_int() - 0x30 + 52
    '+' => 62
    '/' => 63
    _ => raise CliError("base64: invalid input character: '\{c}'")
  }
}

///|
async fn encode_stream(
  reader : &@io.Reader,
  wrap : Int32,
  writer~ : &@io.Writer = @stdio.stdout,
) -> Unit {
  let encoder = Base64Encoder::new(wrap)
  while @stream.read_chunk(reader) is Some(chunk) {
    writer.write(encoder.encode(chunk[:]))
  }
  writer.write(encoder.finish())
}

///|
fn decode_quad(
  quad : ArrayView[Byte],
  out : Array[Byte],
) -> Bool raise CliError {
  let c0 = quad[0].to_int().unsafe_to_char()
  let c1 = quad[1].to_int().unsafe_to_char()
  let c2 = quad[2].to_int().unsafe_to_char()
  let c3 = quad[3].to_int().unsafe_to_char()
  if c0 == '=' || c1 == '=' {
    raise CliError("base64: invalid padding")
  }
  if c2 == '=' && c3 != '=' {
    raise CliError("base64: invalid padding")
  }
  let v0 = sextet(c0)
  let v1 = sextet(c1)
  let v2 = if c2 == '=' { 0 } else { sextet(c2) }
  let v3 = if c3 == '=' { 0 } else { sextet(c3) }
  if c2 == '=' && (v1 & 0xF) != 0 {
    raise CliError("base64: invalid input")
  }
  if c3 == '=' && (v2 & 0x3) != 0 {
    raise CliError("base64: invalid input")
  }
  let n = (v0 << 18) | (v1 << 12) | (v2 << 6) | v3
  out.push(((n >> 16) & 0xFF).to_byte())
  if c2 != '=' {
    out.push(((n >> 8) & 0xFF).to_byte())
  }
  if c3 != '=' {
    out.push((n & 0xFF).to_byte())
  }
  c2 == '=' || c3 == '='
}

///|
async fn decode_stream(reader : &@io.Reader, ignore_garbage : Bool) -> Unit {
  let quad : Array[Byte] = []
  let mut finished = false
  while @stream.read_chunk(reader) is Some(chunk) {
    let out : Array[Byte] = []
    for byte in chunk {
      // GNU base64 always permits embedded newlines. Other whitespace is
      // garbage and is accepted only when -i was explicitly requested.
      if byte == b'\n' {
        continue
      }
      if ignore_garbage &&
        !((byte >= b'A' && byte <= b'Z') ||
        (byte >= b'a' && byte <= b'z') ||
        (byte >= b'0' && byte <= b'9') ||
        byte == b'+' ||
        byte == b'/' ||
        byte == b'=') {
        continue
      }
      if finished {
        raise CliError("base64: invalid padding")
      }
      quad.push(byte)
      if quad.length() == 4 {
        finished = decode_quad(quad, out)
        quad.clear()
      }
    }
    if !out.is_empty() {
      @stdio.stdout.write(Bytes::from_array(out))
    }
  }
  if !quad.is_empty() {
    raise CliError("base64: invalid input length")
  }
}

///|
async fn main {
  let metadata_args = @env.args()[1:]
  if metadata_args.length() == 1 && metadata_args[0] == "--version" {
    @stdio.stdout.write("base64 0.2.5\n")
    return
  }
  let args = @env.args()[1:]
  let parsed = @cli.parse(args, [
    @cli.flag("decode", short='d'),
    @cli.flag("decode", short='D'),
    @cli.flag("ignore-garbage", short='i'),
    @cli.option("wrap", short='w'),
    @cli.flag("help"),
  ]) catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.write("base64: \{message}: '\{option}'\n")
      @sys.exit(2)
      return
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.write(
      "Usage: base64 [-d|-D] [-i] [-w COLS] [FILE]\n      --help      display this help and exit\n      --version   display version and exit\n",
    )
    return
  }
  if parsed.operands.length() > 1 {
    @stdio.stderr.write("base64: extra operand: '\{parsed.operands[1]}'\n")
    @sys.exit(2)
    return
  }
  let decode_mode = parsed.contains("decode")
  let ignore_garbage = parsed.contains("ignore-garbage")
  let wrap_text = parsed.last_value("wrap").unwrap_or("76")
  let wrap = @string.parse_int(wrap_text) catch {
    _ => {
      @stdio.stderr.write("base64: invalid wrap size: '\{wrap_text}'\n")
      @sys.exit(2)
      return
    }
  }
  if wrap < 0 {
    @stdio.stderr.write("base64: invalid wrap size: '\{wrap_text}'\n")
    @sys.exit(2)
    return
  }
  let inputs = parsed.operands
  let path = if inputs.is_empty() { "-" } else { inputs[0] }
  try {
    if path == "-" {
      if decode_mode {
        decode_stream(@stdio.stdin, ignore_garbage)
      } else {
        encode_stream(@stdio.stdin, wrap)
      }
    } else {
      let file = @fs.open(path, mode=ReadOnly)
      defer file.close()
      if decode_mode {
        decode_stream(file, ignore_garbage)
      } else {
        encode_stream(file, wrap)
      }
    }
  } catch {
    CliError(msg) => {
      @stdio.stderr.write("\{msg}\n")
      @sys.exit(1)
      return
    }
    err => {
      @stdio.stderr.write("base64: \{err}\n")
      @sys.exit(1)
      return
    }
  }
}
