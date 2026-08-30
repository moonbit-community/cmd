///|
priv suberror CliError {
  CliError(String)
}

///|
let open_end : Int = 0x7FFFFFFF

///|
fn parse_positive(text : String, spec : String) -> Int raise CliError {
  let n = @string.parse_int(text) catch {
    _ => raise CliError("cut: invalid list: '\{spec}'")
  }
  if n < 1 {
    raise CliError("cut: list positions are numbered from 1: '\{spec}'")
  }
  n
}

///|
fn parse_list(spec : String) -> Array[(Int, Int)] raise CliError {
  let ranges : Array[(Int, Int)] = []
  for part in spec.split(",") {
    let item = part.to_owned()
    if item is "" {
      raise CliError("cut: invalid list: '\{spec}'")
    }
    let pieces : Array[String] = item
      .split("-")
      .map(v => v.to_owned())
      .collect()
    match pieces {
      [n] => {
        let v = parse_positive(n, spec)
        ranges.push((v, v))
      }
      ["", ""] => raise CliError("cut: invalid list: '\{spec}'")
      [a, b] => {
        let lo = if a is "" { 1 } else { parse_positive(a, spec) }
        let hi = if b is "" { open_end } else { parse_positive(b, spec) }
        if lo > hi {
          raise CliError("cut: invalid decreasing range: '\{spec}'")
        }
        ranges.push((lo, hi))
      }
      _ => raise CliError("cut: invalid list: '\{spec}'")
    }
  }
  if ranges.is_empty() {
    raise CliError("cut: invalid list: '\{spec}'")
  }
  ranges
}

///|
fn selected(ranges : Array[(Int, Int)], index : Int) -> Bool {
  for r in ranges {
    let (lo, hi) = r
    if index >= lo && index <= hi {
      return true
    }
  }
  false
}

///|
fn cut_fields(
  line : Bytes,
  ranges : Array[(Int, Int)],
  delimiter : Byte,
  only_delimited : Bool,
) -> Bytes? {
  let fields : Array[Bytes] = []
  let mut start = 0
  for index = 0; index < line.length(); index = index + 1 {
    if line[index] == delimiter {
      fields.push(line[start:index].to_owned())
      start = index + 1
    }
  }
  if start == 0 {
    if only_delimited {
      return None
    }
    return Some(line)
  }
  fields.push(line[start:].to_owned())
  let kept : Array[Byte] = []
  let mut first = true
  for index, field in fields {
    if selected(ranges, index + 1) {
      if !first {
        kept.push(delimiter)
      }
      for byte in field {
        kept.push(byte)
      }
      first = false
    }
  }
  Some(Bytes::from_array(kept))
}

///|
fn cut_characters(line : Bytes, ranges : Array[(Int, Int)]) -> Bytes {
  let out : Array[Byte] = []
  for index, byte in line {
    if selected(ranges, index + 1) {
      out.push(byte)
    }
  }
  Bytes::from_array(out)
}

///|
async fn process_reader(
  reader : &@io.Reader,
  field_ranges : Array[(Int, Int)]?,
  char_ranges : Array[(Int, Int)]?,
  delimiter : Byte,
  only_delimited : Bool,
) -> Unit {
  let scanner = @stream.LineScanner::new(reader)
  while scanner.next() is Some(line) {
    match field_ranges {
      Some(ranges) =>
        match cut_fields(line.data, ranges, delimiter, only_delimited) {
          Some(out) => {
            @stdio.stdout.write(out)
            @stdio.stdout.write("\n")
          }
          None => ()
        }
      None =>
        match char_ranges {
          Some(ranges) => {
            @stdio.stdout.write(cut_characters(line.data, ranges))
            @stdio.stdout.write("\n")
          }
          None => ()
        }
    }
  }
}

///|
async fn main {
  let args = @env.args()[1:]
  let parsed = @cli.parse(args, [
    @cli.flag("only-delimited", short='s'),
    @cli.option("delimiter", short='d'),
    @cli.option("fields", short='f'),
    @cli.option("characters", short='c'),
    @cli.flag("help"),
  ]) catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.write("cut: \{message}: '\{option}'\n")
      @sys.exit(2)
      return
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.write(
      "Usage: cut (-c LIST | -f LIST [-d CHAR] [-s]) [FILE...]\n",
    )
    return
  }
  let only_delimited = parsed.contains("only-delimited")
  let delimiter = match parsed.last_value("delimiter") {
    Some(d) => {
      let encoded = @utf8.encode(d)
      if encoded.length() != 1 {
        @stdio.stderr.write(
          "cut: the delimiter must be a single byte in C locale\n",
        )
        @sys.exit(2)
        return
      }
      encoded[0]
    }
    None => b'\t'
  }
  let fields_spec = parsed.last_value("fields")
  let chars_spec = parsed.last_value("characters")
  if fields_spec is Some(_) && chars_spec is Some(_) {
    @stdio.stderr.write("cut: fields and characters are mutually exclusive\n")
    @sys.exit(2)
    return
  } else if fields_spec is None && chars_spec is None {
    @stdio.stderr.write(
      "cut: you must specify a list of fields (-f) or characters (-c)\n",
    )
    @sys.exit(2)
    return
  }
  let (field_ranges, char_ranges) = try {
    let field_ranges = match fields_spec {
      Some(spec) => Some(parse_list(spec))
      None => None
    }
    let char_ranges = match chars_spec {
      Some(spec) => Some(parse_list(spec))
      None => None
    }
    (field_ranges, char_ranges)
  } catch {
    CliError(msg) => {
      @stdio.stderr.write("\{msg}\n")
      @sys.exit(2)
      return
    }
  }
  let files = parsed.operands
  let sources = if files.is_empty() { ["-"] } else { files }
  let mut failed = false
  for path in sources {
    try {
      if path == "-" {
        process_reader(
          @stdio.stdin, field_ranges, char_ranges, delimiter, only_delimited,
        )
      } else {
        let file = @fs.open(path, mode=ReadOnly)
        defer file.close()
        process_reader(
          file, field_ranges, char_ranges, delimiter, only_delimited,
        )
      }
    } catch {
      err => {
        @stdio.stderr.write("cut: \{err}\n")
        failed = true
        continue
      }
    }
  }
  if failed {
    @sys.exit(1)
  }
}
