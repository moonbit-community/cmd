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
    _ => raise CliError("base64: invalid input")
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
) -> Unit raise CliError {
  guard quad.length() >= 2 else { raise CliError("base64: invalid input") }
  let c0 = quad[0].to_int().unsafe_to_char()
  let c1 = quad[1].to_int().unsafe_to_char()
  let v0 = sextet(c0)
  let v1 = sextet(c1)
  // Commit each determined byte before validating later symbols or padding.
  out.push(((v0 << 2) | (v1 >> 4)).to_byte())
  guard quad.length() >= 3 else { raise CliError("base64: invalid input") }
  let c2 = quad[2].to_int().unsafe_to_char()
  if c2 == '=' {
    guard quad.length() == 4 && quad[3] == b'=' && (v1 & 15) == 0 else {
      raise CliError("base64: invalid input")
    }
    return
  }
  let v2 = sextet(c2)
  out.push(((v1 << 4) | (v2 >> 2)).to_byte())
  guard quad.length() == 4 else { raise CliError("base64: invalid input") }
  let c3 = quad[3].to_int().unsafe_to_char()
  if c3 == '=' {
    guard (v2 & 3) == 0 else { raise CliError("base64: invalid input") }
  } else {
    out.push(((v2 << 6) | sextet(c3)).to_byte())
  }
}

///|
async fn decode_stream(
  reader : &@io.Reader,
  ignore_garbage : Bool,
  writer~ : &@io.Writer = @stdio.stdout,
) -> Unit {
  let quad : Array[Byte] = []
  while @stream.read_chunk(reader) is Some(chunk) {
    let out : Array[Byte] = []
    try {
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
        quad.push(byte)
        if quad.length() == 4 {
          decode_quad(quad, out)
          quad.clear()
        }
      }
    } catch {
      CliError(message) => {
        if !out.is_empty() {
          writer.write(Bytes::from_array(out))
        }
        raise CliError(message)
      }
    }
    if !out.is_empty() {
      writer.write(Bytes::from_array(out))
    }
  }
  if !quad.is_empty() {
    // GNU 9.11 permits absent final padding, but not incomplete explicit padding.
    if !quad.contains(b'=') && (quad.length() == 2 || quad.length() == 3) {
      while quad.length() < 4 {
        quad.push(b'=')
      }
    }
    let out : Array[Byte] = []
    decode_quad(quad, out) catch {
      CliError(message) => {
        if !out.is_empty() {
          writer.write(Bytes::from_array(out))
        }
        raise CliError(message)
      }
    }
    if !out.is_empty() {
      writer.write(Bytes::from_array(out))
    }
  }
}

///|
async fn main {
  let metadata_args = @env.args()[1:]
  if metadata_args.length() == 1 && metadata_args[0] == "--version" {
    @stdio.stdout.write("base64 \{MODULE_VERSION}\n")
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
      @sys.exit(1)
      return
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.write(
      "Usage: base64 [-d|-D] [-i] [-w COLS] [FILE]\n      --help      display this help and exit\n      --version   display version and exit\nProject alias: -D selects -d/--decode; -D is not a GNU coreutils option.\nDecoding retains determined bytes before invalid input, checks canonical tail bits,\nand accepts missing final padding or concatenated padded groups (GNU 9.11).\nOrdinary option/operand errors exit 1; documented capability refusals retain their own status.\n",
    )
    return
  }
  if parsed.operands.length() > 1 {
    @stdio.stderr.write("base64: extra operand: '\{parsed.operands[1]}'\n")
    @sys.exit(1)
    return
  }
  let decode_mode = parsed.contains("decode")
  let ignore_garbage = parsed.contains("ignore-garbage")
  let wrap_text = parsed.last_value("wrap").unwrap_or("76")
  let wrap = @string.parse_int(wrap_text) catch {
    _ => {
      @stdio.stderr.write("base64: invalid wrap size: '\{wrap_text}'\n")
      @sys.exit(1)
      return
    }
  }
  if wrap < 0 {
    @stdio.stderr.write("base64: invalid wrap size: '\{wrap_text}'\n")
    @sys.exit(1)
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
