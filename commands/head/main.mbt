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
let chunk_size : Int = 65536

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
  while split < unsigned.length() && unsigned[split] is ('0'..='9') {
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
  while split < body.length() && body[split] is ('0'..='9') {
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
async fn read_chunk(reader : &@io.Reader, buffer : FixedArray[Byte]) -> Bytes? {
  let count = reader.read(buffer)
  if count == 0 {
    None
  } else {
    Some(Bytes::from_array(buffer[0:count]))
  }
}

///|
async fn write_record(record : @stream.Line, delimiter : Byte) -> Unit {
  @stdio.stdout.write(record.data)
  if record.terminated {
    @stdio.stdout.write(if delimiter is b'\x00' { b"\x00" } else { b"\n" })
  }
}

///|
async fn head_records(
  reader : &@io.Reader,
  spec : CountSpec,
  delimiter : Byte,
) -> Unit {
  let scanner = @stream.LineScanner::new(reader, delimiter~)
  match spec {
    First(count) => {
      let mut remaining = count
      while remaining > 0 && scanner.next() is Some(record) {
        write_record(record, delimiter)
        remaining -= 1
      }
    }
    AllButLast(count) => {
      let pending : Array[@stream.Line] = []
      while scanner.next() is Some(record) {
        pending.push(record)
        if pending.length().to_int64() > count {
          write_record(pending.remove(0), delimiter)
        }
      }
    }
  }
}

///|
async fn head_bytes(reader : &@io.Reader, spec : CountSpec) -> Unit {
  let buffer : FixedArray[Byte] = FixedArray::make(chunk_size, 0)
  match spec {
    First(count) => {
      let mut remaining = count
      while remaining > 0 {
        match read_chunk(reader, buffer) {
          Some(chunk) =>
            if chunk.length().to_int64() <= remaining {
              @stdio.stdout.write(chunk)
              remaining -= chunk.length().to_int64()
            } else {
              @stdio.stdout.write(chunk[0:remaining.to_int()])
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
          @stdio.stdout.write(Bytes::from_array(pending[0:emit.to_int()]))
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
  reader : &@io.Reader,
  spec : CountSpec,
  bytes_mode : Bool,
  delimiter : Byte,
) -> Unit {
  if bytes_mode {
    head_bytes(reader, spec)
  } else {
    head_records(reader, spec, delimiter)
  }
}

///|
async fn main {
  let args = legacy_count_args(@env.args()[1:])
  let parsed = @cli.parse(args, [
    @cli.flag("quiet", short='q'),
    @cli.flag("verbose", short='v'),
    @cli.flag("zero-terminated", short='z'),
    @cli.option("lines", short='n'),
    @cli.option("bytes", short='c'),
    @cli.flag("help"),
  ]) catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.write("head: \{message}: '\{option}'\n")
      @sys.exit(2)
      return
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.write("Usage: head [-qvz] [-n NUM|-c NUM] [FILE...]\n")
    return
  }
  let (spec, bytes_mode) = try {
    match parsed.last_occurrence(["lines", "bytes"]) {
      Some("bytes") => (parse_count(parsed.last_value("bytes").unwrap()), true)
      Some(_) => (parse_count(parsed.last_value("lines").unwrap()), false)
      None => (First(10L), false)
    }
  } catch {
    CliError(message) => {
      @stdio.stderr.write(message + "\n")
      @sys.exit(2)
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
  for index, path in sources {
    if show_headers {
      let name = if path == "-" { "standard input" } else { path }
      let prefix = if index > 0 { "\n" } else { "" }
      @stdio.stdout.write("\{prefix}==> \{name} <==\n")
    }
    try {
      if path == "-" {
        head_reader(@stdio.stdin, spec, bytes_mode, delimiter)
      } else {
        let file = @fs.open(path, mode=ReadOnly)
        defer file.close()
        head_reader(file, spec, bytes_mode, delimiter)
      }
    } catch {
      err => {
        @stdio.stderr.write("head: \{err}\n")
        failed = true
      }
    }
  }
  if failed {
    @sys.exit(1)
  }
}
