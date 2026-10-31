///|
priv suberror CliError {
  CliError(String)
}

///|
fn base32_value(c : Char) -> Int32 raise CliError {
  match c {
    'A'..<='Z' => c.to_int() - 0x41
    '2'..<='7' => c.to_int() - 0x32 + 26
    _ => raise CliError("base32: invalid input character: '\{c}'")
  }
}

///|
fn encode_groups(
  input : BytesView,
  output : FixedArray[Byte],
  destination : Int32,
) -> Unit {
  let alphabet = b"ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
  let mut target = destination
  for index = 0; index + 4 < input.length(); index = index + 5 {
    let a = input[index].to_int()
    let b = input[index + 1].to_int()
    let c = input[index + 2].to_int()
    let d = input[index + 3].to_int()
    let e = input[index + 4].to_int()
    output[target] = alphabet[a >> 3]
    output[target + 1] = alphabet[((a << 2) | (b >> 6)) & 31]
    output[target + 2] = alphabet[(b >> 1) & 31]
    output[target + 3] = alphabet[((b << 4) | (c >> 4)) & 31]
    output[target + 4] = alphabet[((c << 1) | (d >> 7)) & 31]
    output[target + 5] = alphabet[(d >> 2) & 31]
    output[target + 6] = alphabet[((d << 3) | (e >> 5)) & 31]
    output[target + 7] = alphabet[e & 31]
    target += 8
  }
}

///|
// Strategy: base32-byte-encoding
fn encode_bytes(input : Bytes, wrap : Int32) -> Bytes raise CliError {
  let groups = (input.length().to_int64() + 4) / 5
  let length = groups * 8
  let separators = if wrap > 0 {
    (length + wrap.to_int64() - 1) / wrap.to_int64()
  } else {
    0L
  }
  guard length + separators <= 2147483647L else {
    raise CliError("base32: encoded output is too large")
  }
  let alphabet = b"ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
  let encoded = FixedArray::make(length.to_int(), b'=')
  let mut index = 0
  let mut target = 0
  let complete = input.length() - input.length() % 5
  while index < complete {
    // Keep complete quanta in a compact byte kernel. The tail and wrapping
    // remain outside that loop; no I/O or input-specific decision occurs here.
    let count = (complete - index).min(65535)
    encode_groups(input[index:index + count], encoded, target)
    index += count
    target += count / 5 * 8
  }
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
    encoded[target] = alphabet[c0]
    encoded[target + 1] = alphabet[c1]
    if count > 1 {
      encoded[target + 2] = alphabet[c2]
      encoded[target + 3] = alphabet[c3]
    }
    if count > 2 {
      encoded[target + 4] = alphabet[c4]
    }
    if count > 3 {
      encoded[target + 5] = alphabet[c5]
      encoded[target + 6] = alphabet[c6]
    }
    if count > 4 {
      encoded[target + 7] = alphabet[c7]
    }
    index += count
    target += 8
  }
  if wrap <= 0 || length == 0 {
    return encoded.unsafe_reinterpret_as_bytes()
  }
  let output = FixedArray::make((length + separators).to_int(), b'\n')
  let mut source = 0
  let mut destination = 0
  while source < encoded.length() {
    let count = wrap.min(encoded.length() - source)
    encoded.blit_to(
      output,
      src_offset=source,
      dst_offset=destination,
      len=count,
    )
    source += count
    destination += count + 1
  }
  output.unsafe_reinterpret_as_bytes()
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
// Preserve whole-input acceptance before encoding/decoding and avoid a host
// read boundary for each 4 KiB segment of standard input.
async fn read_input(reader : &@io.Reader) -> Bytes {
  let input = @buffer.Buffer()
  while reader.read_some(max_len=65536) is Some(chunk) {
    input.write_bytes(chunk)
  }
  input.to_bytes()
}

///|
async fn main {
  let metadata_args = @env.args()[1:]
  if metadata_args.length() == 1 && metadata_args[0] == "--version" {
    @stdio.stdout.write("base32 0.1.4\n")
    return
  }
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
    @stdio.stdout.write(
      "Usage: base32 [-d] [-i] [-w COLS] [FILE]\n      --help      display this help and exit\n      --version   display version and exit\n",
    )
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
      read_input(@stdio.stdin)
    } else {
      let file = @fs.open(path, mode=ReadOnly)
      defer file.close()
      read_input(file)
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
