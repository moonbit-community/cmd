///|
priv suberror CliError {
  CliError(String)
}

///|
let open_end : Int = 0x7FFFFFFF

///|
fn cut_command() -> @argparse.Command {
  Command(
    "cut",
    about="Print selected fields or characters of each line.",
    flags=[
      FlagArg(
        "only-delimited",
        short='s',
        about="Skip lines without the delimiter (field mode).",
      ),
    ],
    options=[
      OptionArg(
        "delimiter",
        short='d',
        about="Field delimiter character (default TAB).",
      ),
      OptionArg(
        "fields",
        short='f',
        about="Comma-separated field list, e.g. 1,3-5,7-.",
        allow_hyphen_values=true,
      ),
      OptionArg(
        "characters",
        short='c',
        about="Comma-separated character position list.",
        conflicts_with=["fields"],
        allow_hyphen_values=true,
      ),
    ],
    positionals=[
      PositionArg(
        "files",
        about="[file...] ('-' or no file reads stdin)",
        num_args=ValueRange(lower=0),
      ),
    ],
    disable_help_subcommand=true,
  )
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
  let command = cut_command()
  let matches = command.parse(argv=args, env=Map([])) catch {
    err => {
      @stdio.stderr.write("\{err}\n")
      @sys.exit(2)
      return
    }
  }
  let only_delimited = matches.flags.get_or_default("only-delimited", false)
  let delimiter = match option_value(matches, "delimiter") {
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
  let fields_spec = option_value(matches, "fields")
  let chars_spec = option_value(matches, "characters")
  if fields_spec is None && chars_spec is None {
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
  let files = matches.values.get("files").unwrap_or([])
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
