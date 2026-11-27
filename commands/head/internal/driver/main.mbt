///|
priv suberror CliError {
  CliError(String)
}

///|
priv enum CountSpec {
  First(Int64)
  AllButLast(Int64)
}

///|
const CHUNK_SIZE : Int32 = 65536

///|
priv struct HeadOutput {
  writer : &@io.BinaryWriter
  mut failed : Bool
}

///|
impl @io.BinaryWriter for HeadOutput

///|
impl @io.BinaryWriterImpl for HeadOutput with fn name(_) {
  "HeadOutput"
}

///|
impl @io.BinaryWriterImpl for HeadOutput with fn get_controller(self) {
  @io.BinaryWriterImpl::get_controller(self.writer)
}

///|
impl @io.BinaryWriterImpl for HeadOutput with fn flush_partial_data(self) {
  self.writer.flush_partial_data()
}

///|
impl @io.BinaryWriterImpl for HeadOutput with fn raw_write_impl(
  self,
  data,
  offset~,
  len~,
) {
  errdefer {
    self.failed = true
  }
  self.writer.write(data[offset:offset + len])
  len
}

///|
fn scaled_count(
  number : Int64,
  suffix : String,
  original : String,
) -> Int64 raise CliError {
  if suffix == "b" {
    if number > 9223372036854775807L / 512L {
      raise CliError("head: invalid count: '\{original}'")
    }
    return number * 512L
  }
  let (base, power) = match suffix {
    "" => return number
    "kB" | "KB" => (1000L, 1)
    "K" | "KiB" => (1024L, 1)
    "MB" => (1000L, 2)
    "M" | "MiB" => (1024L, 2)
    "GB" => (1000L, 3)
    "G" | "GiB" => (1024L, 3)
    "TB" => (1000L, 4)
    "T" | "TiB" => (1024L, 4)
    "PB" => (1000L, 5)
    "P" | "PiB" => (1024L, 5)
    "EB" => (1000L, 6)
    "E" | "EiB" => (1024L, 6)
    "ZB" => (1000L, 7)
    "Z" | "ZiB" => (1024L, 7)
    "YB" => (1000L, 8)
    "Y" | "YiB" => (1024L, 8)
    "RB" => (1000L, 9)
    "R" | "RiB" => (1024L, 9)
    "QB" => (1000L, 10)
    "Q" | "QiB" => (1024L, 10)
    _ => raise CliError("head: invalid count: '\{original}'")
  }
  let mut result = number
  for _ in 0..<power {
    if result > 9223372036854775807L / base {
      raise CliError("head: invalid count: '\{original}'")
    }
    result *= base
  }
  result
}

///|
fn parse_count(text : String) -> CountSpec raise CliError {
  let (exclude_tail, unsigned) = if text is ['+', .. rest] {
    (false, rest.to_owned())
  } else if text is ['-', .. rest] {
    (true, rest.to_owned())
  } else {
    (false, text)
  }
  let mut split = 0
  while split < unsigned.length() && unsigned[split] is ('0'..<='9') {
    split += 1
  }
  if split == 0 {
    raise CliError("head: invalid count: '\{text}'")
  }
  let number = @string.parse_int64(unsigned[0:split]) catch {
    _ => raise CliError("head: invalid count: '\{text}'")
  }
  let count = scaled_count(number, unsigned[split:].to_owned(), text)
  if exclude_tail {
    AllButLast(count)
  } else {
    First(count)
  }
}

///|
fn obsolete_count_arg(arg : String) -> Array[String]? {
  if arg.length() < 2 || !(arg[0] is '-') {
    return None
  }
  let body = arg[1:]
  let mut split = 0
  while split < body.length() && body[split] is ('0'..<='9') {
    split += 1
  }
  if split == 0 {
    return None
  }
  let mut bytes_mode = false
  let mut lines_mode = false
  let mut scale = ""
  let flags : Array[String] = []
  for modifier in body[split:] {
    match modifier {
      'b' => {
        bytes_mode = true
        scale = "b"
      }
      'k' => {
        bytes_mode = true
        scale = "K"
      }
      'm' => {
        bytes_mode = true
        scale = "M"
      }
      'c' => bytes_mode = true
      'l' => lines_mode = true
      'q' => flags.push("-q")
      'v' => flags.push("-v")
      _ => return None
    }
  }
  if bytes_mode && lines_mode {
    return None
  }
  let normalized : Array[String] = [if bytes_mode { "-c" } else { "-n" }]
  normalized.push(body[0:split].to_owned() + scale)
  normalized.append(flags)
  Some(normalized)
}

///|
fn legacy_count_args(args : ArrayView[String]) -> Array[String] {
  let normalized : Array[String] = []
  if !args.is_empty() && obsolete_count_arg(args[0]) is Some(legacy) {
    normalized.append(legacy)
    for arg in args[1:] {
      normalized.push(arg)
    }
    return normalized
  }
  for arg in args {
    normalized.push(arg)
  }
  normalized
}

///|
async fn read_chunk(
  reader : &@io.BinaryReader,
  buffer : FixedArray[Byte],
) -> Bytes? {
  let count = reader.read_into(buffer.mut_view())
  if count == 0 {
    None
  } else {
    Some(Bytes::from_array(buffer[0:count]))
  }
}

///|
async fn write_record(
  writer : &@io.BinaryWriter,
  record : @stream.Line,
  delimiter : Byte,
) -> Unit {
  writer.write(record.data)
  if record.terminated {
    writer.write(if delimiter is b'\x00' { b"\x00" } else { b"\n" })
  }
}

///|
async fn head_records(
  reader : &@io.BinaryReader,
  writer : &@io.BinaryWriter,
  spec : CountSpec,
  delimiter : Byte,
) -> Unit {
  let scanner = @stream.LineScanner::from_binary(reader, delimiter~)
  match spec {
    First(count) => {
      let mut remaining = count
      while remaining > 0 && scanner.next() is Some(record) {
        write_record(writer, record, delimiter)
        remaining -= 1
      }
    }
    AllButLast(count) => {
      let pending : Array[@stream.Line] = []
      while scanner.next() is Some(record) {
        pending.push(record)
        if pending.length().to_int64() > count {
          write_record(writer, pending.remove(0), delimiter)
        }
      }
    }
  }
}

///|
async fn head_bytes(
  reader : &@io.BinaryReader,
  writer : &@io.BinaryWriter,
  spec : CountSpec,
) -> Unit {
  let buffer : FixedArray[Byte] = FixedArray::make(CHUNK_SIZE, 0)
  match spec {
    First(count) => {
      let mut remaining = count
      while remaining > 0 {
        match read_chunk(reader, buffer) {
          Some(chunk) =>
            if chunk.length().to_int64() <= remaining {
              writer.write(chunk)
              remaining -= chunk.length().to_int64()
            } else {
              writer.write(chunk[0:remaining.to_int()])
              remaining = 0
            }
          None => break
        }
      }
    }
    AllButLast(count) => {
      let pending : Array[Byte] = []
      while read_chunk(reader, buffer) is Some(chunk) {
        for byte in chunk {
          pending.push(byte)
        }
        let emit = pending.length().to_int64() - count
        if emit > 0L {
          writer.write(Bytes::from_array(pending[0:emit.to_int()]))
          let kept = pending[emit.to_int():].to_owned()
          pending.clear()
          pending.append(kept)
        }
      }
    }
  }
}

///|
async fn head_reader(
  reader : &@io.BinaryReader,
  writer : &@io.BinaryWriter,
  spec : CountSpec,
  bytes_mode : Bool,
  delimiter : Byte,
) -> Unit {
  if bytes_mode {
    head_bytes(reader, writer, spec)
  } else {
    head_records(reader, writer, spec, delimiter)
  }
}

///|
pub async fn run_main() -> Unit {
  let metadata_args = @env.args()[1:]
  if metadata_args.length() == 1 && metadata_args[0] == "--version" {
    @stdio.stdout.text.write("head \{MODULE_VERSION}\n")
    return
  }
  let args = legacy_count_args(@env.args()[1:])
  let parsed = @cli.parse(args, option_specs()) catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.text.write("head: \{message}: '\{option}'\n")
      @env.exit(1)
      return
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.text.write(metadata_help())
    return
  }
  let (spec, bytes_mode) = try {
    match parsed.last_occurrence(["lines", "bytes"]) {
      Some("bytes") => (parse_count(parsed.last_value("bytes").unwrap()), true)
      Some(_) => (parse_count(parsed.last_value("lines").unwrap()), false)
      None => (First(DEFAULT_LINES.to_int64()), false)
    }
  } catch {
    CliError(message) => {
      @stdio.stderr.text.write(message + "\n")
      @env.exit(1)
      return
    }
  }
  let sources = if parsed.operands.is_empty() { ["-"] } else { parsed.operands }
  let header_mode = parsed.last_occurrence(["quiet", "verbose"])
  let show_headers = header_mode == Some("verbose") ||
    (sources.length() > 1 && header_mode != Some("quiet"))
  let delimiter : Byte = if parsed.contains("zero-terminated") {
    b'\x00'
  } else {
    b'\n'
  }
  let mut failed = false
  let sink : HeadOutput = { writer: @stdio.stdout, failed: false, }
  let output = @io.BufferedWriter(sink, size=CHUNK_SIZE)
  for index, path in sources {
    try {
      if show_headers {
        let name = if path == "-" { "standard input" } else { path }
        let prefix = if index > 0 { "\n" } else { "" }
        @io.Utf8Writer(output).write("\{prefix}==> \{name} <==\n")
      }
      if path == "-" {
        head_reader(@stdio.stdin, output, spec, bytes_mode, delimiter)
      } else {
        let file = @fs.open(path, mode=ReadOnly)
        defer file.close()
        head_reader(file, output, spec, bytes_mode, delimiter)
      }
      output.flush()
    } catch {
      err => {
        if !sink.failed {
          output.flush() catch {
            write_error => {
              @stdio.stderr.text.write(
                "head: \{@stream.transport_cause(write_error)}\n",
              )
              @env.exit(1)
              return
            }
          }
        }
        @stdio.stderr.text.write("head: \{@stream.transport_cause(err)}\n")
        failed = true
        if sink.failed {
          break
        }
      }
    }
  }
  if failed {
    @env.exit(1)
  }
}
