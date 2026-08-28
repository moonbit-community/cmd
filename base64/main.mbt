///|
priv suberror CliError {
  CliError(String)
}

///|
fn base64_command() -> @argparse.Command {
  Command(
    "base64",
    about="Base64 encode or decode a file or stdin.",
    flags=[FlagArg("decode", short='d', about="Decode instead of encode.")],
    options=[
      OptionArg(
        "wrap",
        short='w',
        about="Wrap encoded lines after N characters (0 disables; default 76).",
        default_values=["76"],
      ),
    ],
    positionals=[
      PositionArg(
        "input",
        about="[file] ('-' or no file reads stdin)",
        num_args=ValueRange(lower=0, upper=1),
      ),
    ],
    disable_help_subcommand=true,
  )
}

///|
fn b64_char(v : Int) -> Char {
  if v < 26 {
    (0x41 + v).unsafe_to_char()
  } else if v < 52 {
    (0x61 + v - 26).unsafe_to_char()
  } else if v < 62 {
    (0x30 + v - 52).unsafe_to_char()
  } else if v == 62 {
    '+'
  } else {
    '/'
  }
}

///|
fn sextet(c : Char) -> Int raise CliError {
  match c {
    'A'..='Z' => c.to_int() - 0x41
    'a'..='z' => c.to_int() - 0x61 + 26
    '0'..='9' => c.to_int() - 0x30 + 52
    '+' => 62
    '/' => 63
    _ => raise CliError("base64: invalid input character: '\{c}'")
  }
}

///|
async fn encode_stream(reader : &@io.Reader, wrap : Int) -> Unit {
  let mut column = 0
  let mut emitted = false
  fn emit(sb : StringBuilder, c : Char) {
    sb.write_char(c)
    emitted = true
    column += 1
    if wrap > 0 && column == wrap {
      sb.write_char('\n')
      column = 0
    }
  }
  let pending : Array[Byte] = []
  while @stream.read_chunk(reader) is Some(chunk) {
    let data : Array[Byte] = []
    data.append(pending)
    pending.clear()
    for byte in chunk {
      data.push(byte)
    }
    let out = StringBuilder()
    let mut index = 0
    while index + 2 < data.length() {
      let n = (data[index].to_int() << 16) |
        (data[index + 1].to_int() << 8) |
        data[index + 2].to_int()
      emit(out, b64_char((n >> 18) & 0x3F))
      emit(out, b64_char((n >> 12) & 0x3F))
      emit(out, b64_char((n >> 6) & 0x3F))
      emit(out, b64_char(n & 0x3F))
      index += 3
    }
    for byte in data[index:] {
      pending.push(byte)
    }
    @stdio.stdout.write(out.to_string())
  }
  if !pending.is_empty() {
    let out = StringBuilder()
    let b0 = pending[0].to_int()
    let b1 = if pending.length() > 1 { pending[1].to_int() } else { 0 }
    let n = (b0 << 16) | (b1 << 8)
    emit(out, b64_char((n >> 18) & 0x3F))
    emit(out, b64_char((n >> 12) & 0x3F))
    if pending.length() > 1 {
      emit(out, b64_char((n >> 6) & 0x3F))
    } else {
      emit(out, '=')
    }
    emit(out, '=')
    @stdio.stdout.write(out.to_string())
  }
  if emitted && column != 0 {
    @stdio.stdout.write("\n")
  }
}

///|
fn ascii_whitespace(byte : Byte) -> Bool {
  byte.to_int() is (0x20 | 0x09 | 0x0A | 0x0D | 0x0B | 0x0C)
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
async fn decode_stream(reader : &@io.Reader) -> Unit {
  let quad : Array[Byte] = []
  let mut finished = false
  while @stream.read_chunk(reader) is Some(chunk) {
    let out : Array[Byte] = []
    for byte in chunk {
      if ascii_whitespace(byte) {
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
fn option_value(matches : @argparse.Matches, name : String) -> String? {
  match matches.values.get(name) {
    Some(vals) =>
      if vals.is_empty() {
        None
      } else {
        Some(vals[vals.length() - 1])
      }
    None => None
  }
}

///|
async fn main {
  let args = @env.args()[1:]
  let command = base64_command()
  let matches = command.parse(argv=args, env=Map([])) catch {
    err => {
      @stdio.stderr.write("\{err}\n")
      @sys.exit(2)
      return
    }
  }
  let decode_mode = matches.flags.get_or_default("decode", false)
  let wrap_text = option_value(matches, "wrap").unwrap_or("76")
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
  let inputs = matches.values.get("input").unwrap_or([])
  let path = if inputs.is_empty() { "-" } else { inputs[0] }
  try {
    if path == "-" {
      if decode_mode {
        decode_stream(@stdio.stdin)
      } else {
        encode_stream(@stdio.stdin, wrap)
      }
    } else {
      let file = @fs.open(path, mode=ReadOnly)
      defer file.close()
      if decode_mode {
        decode_stream(file)
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
