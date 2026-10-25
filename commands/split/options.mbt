///|
priv suberror SplitError {
  SplitError(Int32, String)
}

///|
priv enum Method {
  BytesPer(Int64)
  LinesPer(Int64)
  LineBytes(Int64)
  Chunks(Int64, Int64, Bool)
  RoundRobin(Int64, Int64)
}

///|
priv struct Options {
  layout : Method
  prefix : String
  additional : String
  alphabet : String
  start : String?
  width : Int32
  automatic : Bool
  elide : Bool
  filter : String?
}

///|
fn usage_error(message : String) -> Unit raise SplitError {
  raise SplitError(1, message + "\nTry 'split --help' for more information.")
}

///|
fn positive(
  value : String,
  label~ : String = "invalid positive count",
) -> Int64 raise SplitError {
  let mut start = 0
  while start < value.length() &&
        value[start] is (' ' | '\t' | '\n' | '\r' | '\u000b' | '\u000c') {
    start += 1
  }
  if start < value.length() && value[start] == '+' {
    start += 1
  }
  if start == value.length() {
    raise SplitError(1, "\{label}: '\{value}'")
  }
  for index in start..<value.length() {
    if value[index] < '0' || value[index] > '9' {
      raise SplitError(1, "\{label}: '\{value}'")
    }
  }
  let count = @string.parse_int64(value[start:]) catch {
    _ => 9223372036854775807L
  }
  if count <= 0 {
    raise SplitError(1, "\{label}: '\{value}'")
  }
  count
}

///|
fn byte_count(
  value : String,
  label~ : String = "invalid number of bytes",
) -> Int64 raise SplitError {
  let mut start = 0
  while start < value.length() &&
        value[start] is (' ' | '\t' | '\n' | '\r' | '\u000b' | '\u000c') {
    start += 1
  }
  if start < value.length() && value[start] == '+' {
    start += 1
  }
  let mut end = start
  while end < value.length() && value[end] >= '0' && value[end] <= '9' {
    end += 1
  }
  if end == start {
    raise SplitError(1, "\{label}: '\{value}'")
  }
  let count = @string.parse_int64(value[start:end]) catch {
    _ => 9223372036854775807L
  }
  if count == 0 {
    raise SplitError(1, "\{label}: '\{value}'")
  }
  let multiplier = match value[end:] {
    "" => 1L
    "b" => 512L
    "kB" => 1000L
    "K" | "KiB" => 1024L
    "MB" => 1000000L
    "M" | "MiB" => 1048576L
    "GB" => 1000000000L
    "G" | "GiB" => 1073741824L
    _ => raise SplitError(1, "\{label}: '\{value}'")
  }
  if count > 9223372036854775807L / multiplier {
    9223372036854775807L
  } else {
    count * multiplier
  }
}

///|
fn normalized_args(args : ArrayView[String]) -> Array[String] {
  let result : Array[String] = []
  let mut options = true
  let mut value_next = false
  for arg in args {
    if value_next {
      result.push(arg)
      value_next = false
      continue
    }
    if options && arg == "--" {
      options = false
    }
    result.push(
      if options && arg == "--numeric-suffixes" {
        "-d"
      } else if options && arg == "--hex-suffixes" {
        "-x"
      } else {
        arg
      },
    )
    if options {
      if [
          "--bytes", "--lines", "--line-bytes", "--number", "--suffix-length", "--additional-suffix",
          "--filter",
        ].contains(arg) {
        value_next = true
      } else if arg.has_prefix("-") && !arg.has_prefix("--") {
        for index in 1..<arg.length() {
          if arg[index] is ('b' | 'l' | 'C' | 'n' | 'a') {
            value_next = index + 1 == arg.length()
            break
          }
        }
      }
    }
  }
  result
}

///|
fn parse_args(args : ArrayView[String]) -> @cli.ParsedArgs raise @cli.CliError {
  @cli.parse(normalized_args(args), [
    @cli.option("lines", short='l'),
    @cli.option("bytes", short='b'),
    @cli.option("line-bytes", short='C'),
    @cli.option("number", short='n'),
    @cli.option("suffix-length", short='a'),
    @cli.option("additional-suffix"),
    @cli.option("numeric-suffixes"),
    @cli.flag("numeric-suffixes", short='d'),
    @cli.option("hex-suffixes"),
    @cli.flag("hex-suffixes", short='x'),
    @cli.flag("elide-empty-files", short='e'),
    @cli.option("filter"),
    @cli.flag("help"),
    @cli.flag("version"),
  ])
}

///|
fn chunk_method(value : String) -> Method raise SplitError {
  let mut start = 0
  while start < value.length() &&
        value[start] is (' ' | '\t' | '\n' | '\r' | '\u000b' | '\u000c') {
    start += 1
  }
  let value = value[start:].to_owned()
  let (text, lines, round_robin) = if value.has_prefix("l/") {
    (value[2:].to_owned(), true, false)
  } else if value.has_prefix("r/") {
    (value[2:].to_owned(), false, true)
  } else {
    (value, false, false)
  }
  let parts = text.split("/").collect()
  let (selected, count) = match parts[:] {
    [count] =>
      (0L, positive(count.to_owned(), label="invalid number of chunks"))
    [selected, count] => {
      let count = positive(count.to_owned(), label="invalid number of chunks")
      let selected = positive(selected.to_owned(), label="invalid chunk number")
      if selected > count {
        raise SplitError(1, "invalid chunk number: '\{selected}'")
      }
      (selected, count)
    }
    _ => raise SplitError(1, "invalid number of chunks: '\{text}'")
  }
  if round_robin {
    RoundRobin(count, selected)
  } else {
    Chunks(count, selected, lines)
  }
}

///|
fn options(parsed : @cli.ParsedArgs) -> Options raise SplitError {
  let mut chosen : Method? = None
  let mut alphabet = "abcdefghijklmnopqrstuvwxyz"
  let mut start : String? = None
  let mut requested = 0
  let mut additional = ""
  let positions : Map[String, Int32] = Map([])
  for name in parsed.order {
    let index = positions.get(name).unwrap_or(0)
    positions[name] = index + 1
    let value = parsed.occurrences
      .get(name)
      .unwrap_or([])
      .get(index)
      .unwrap_or(None)
    if ["bytes", "lines", "line-bytes", "number"].contains(name) {
      if chosen is Some(_) {
        usage_error("cannot split in more than one way")
      }
      chosen = Some(
        match name {
          "bytes" => BytesPer(byte_count(value.unwrap()))
          "line-bytes" =>
            LineBytes(
              byte_count(value.unwrap(), label="invalid number of lines"),
            )
          "number" => chunk_method(value.unwrap())
          _ =>
            LinesPer(positive(value.unwrap(), label="invalid number of lines"))
        },
      )
    } else if name == "suffix-length" {
      requested = @string.parse_int(value.unwrap()) catch {
        _ => raise SplitError(1, "invalid suffix length")
      }
      if requested < 0 {
        raise SplitError(1, "invalid suffix length")
      }
    } else if name == "numeric-suffixes" || name == "hex-suffixes" {
      alphabet = if name == "numeric-suffixes" {
        "0123456789"
      } else {
        "0123456789abcdef"
      }
      if value is Some(value) {
        for character in value {
          if !alphabet.contains(character.to_string()) {
            usage_error(
              "'\{value}': invalid start value for \{if alphabet.length() == 16 { "hexadecimal" } else { "numerical" }} suffix",
            )
          }
        }
        let mut offset = 0
        while offset + 1 < value.length() && value[offset] == '0' {
          offset += 1
        }
        start = Some(value[offset:].to_owned())
      }
    } else if name == "additional-suffix" {
      additional = value.unwrap()
      let windows_separator = match @async.platform {
        Windows => additional.contains("\\")
        _ => false
      }
      if additional.contains("/") || windows_separator {
        usage_error(
          "invalid suffix '\{additional}', contains directory separator",
        )
      }
    }
  }
  let layout = chosen.unwrap_or(LinesPer(1000L))
  let selected = match layout {
    Chunks(_, selected, _) | RoundRobin(_, selected) => selected
    _ => 0L
  }
  if selected != 0 && parsed.contains("filter") {
    usage_error(
      "--filter does not process a chunk extracted to standard output",
    )
  }
  if start is Some(value) {
    for character in value {
      if !alphabet.contains(character.to_string()) {
        usage_error("suffix start contains a digit outside the final alphabet")
      }
    }
  }
  let count = match layout {
    Chunks(count, _, _) | RoundRobin(count, _) => count
    _ => 0L
  }
  let mut last = if count == 0 { 0L } else { count - 1 }
  if count != 0 && start is Some(value) {
    let from = @string.parse_int64(value) catch { _ => count }
    if from >= 0 && from < count {
      last = if last > 9223372036854775807L - from {
        9223372036854775807L
      } else {
        last + from
      }
    }
  }
  let mut needed = 1
  while last >= alphabet.length().to_int64() {
    needed += 1
    last /= alphabet.length().to_int64()
  }
  if requested != 0 && count != 0 && requested < needed {
    raise SplitError(1, "the suffix length needs to be at least \{needed}")
  }
  let width = if requested != 0 {
    requested
  } else if needed > 2 {
    needed
  } else {
    2
  }
  if parsed.operands.length() > 2 {
    usage_error("extra operand '\{parsed.operands[2]}'")
  }
  if start is Some(value) && value.length() > width {
    usage_error(
      "numerical suffix start value is too large for the suffix length",
    )
  }
  {
    layout,
    prefix: parsed.operands.get(1).unwrap_or("x"),
    additional,
    alphabet,
    start,
    width,
    automatic: requested == 0 && start is None && count == 0,
    elide: parsed.contains("elide-empty-files"),
    filter: parsed.last_value("filter"),
  }
}
