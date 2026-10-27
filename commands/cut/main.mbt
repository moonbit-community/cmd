///|
priv suberror CliError {
  CliError(String)
}

///|
let open_end : Int32 = 0x7FFFFFFF

///|
fn parse_positive(text : String, spec : String) -> Int32 raise CliError {
  let n = @string.parse_int(text) catch {
    _ => raise CliError("cut: invalid list: '\{spec}'")
  }
  if n < 1 {
    raise CliError("cut: list positions are numbered from 1: '\{spec}'")
  }
  n
}

///|
fn parse_list(spec : String) -> Array[(Int32, Int32)] raise CliError {
  let ranges : Array[(Int32, Int32)] = []
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
  normalize_ranges(ranges)
}

///|
fn normalize_ranges(ranges : Array[(Int32, Int32)]) -> Array[(Int32, Int32)] {
  ranges.sort_by((a, b) => a.0.compare(b.0))
  let merged : Array[(Int32, Int32)] = []
  for range in ranges {
    if !merged.is_empty() {
      let last = merged.length() - 1
      let (lo, hi) = merged[last]
      if range.0 <= hi {
        merged[last] = (lo, Int32::max(hi, range.1))
        continue
      }
    }
    // Adjacent explicit ranges retain their output-delimiter boundary.
    merged.push(range)
  }
  merged
}

///|
fn complement_ranges(ranges : Array[(Int32, Int32)]) -> Array[(Int32, Int32)] {
  let result : Array[(Int32, Int32)] = []
  let mut start = 1
  for (lo, hi) in ranges {
    if start < lo {
      result.push((start, lo - 1))
    }
    if hi == open_end {
      return result
    }
    start = hi + 1
  }
  result.push((start, open_end))
  result
}

///|
fn output_delimiter_bytes(value : String) -> Bytes {
  if value == "" {
    b"\x00"
  } else {
    @utf8.encode(value)
  }
}

///|
fn cut_fields_into(
  line : BytesView,
  ranges : Array[(Int32, Int32)],
  delimiter : Byte,
  only_delimited : Bool,
  output_delimiter : Bytes,
  kept : @buffer.Buffer,
) -> Bool {
  if !line.iter().any(byte => byte == delimiter) {
    if only_delimited {
      return false
    }
    kept.write_bytes(line)
    return true
  }
  let mut start = 0
  let mut field = 1
  let mut range_index = 0
  let mut first = true
  let last_field = ranges.last().map(range => range.1).unwrap_or(0)
  for index in 0..<=line.length() {
    if index == line.length() || line[index] == delimiter {
      while range_index < ranges.length() && ranges[range_index].1 < field {
        range_index += 1
      }
      if range_index < ranges.length() && ranges[range_index].0 <= field {
        if !first {
          kept.write_bytes(output_delimiter)
        }
        kept.write_bytes(line[start:index])
        first = false
      }
      start = index + 1
      field += 1
      if field > last_field {
        break
      }
    }
  }
  true
}

///|
#inline
fn cut_characters_into(
  line : BytesView,
  ranges : Array[(Int32, Int32)],
  output_delimiter : Bytes?,
  out : @buffer.Buffer,
) -> Unit {
  let mut first = true
  for (lo, hi) in ranges {
    if lo > line.length() {
      break
    }
    if !first && output_delimiter is Some(separator) {
      out.write_bytes(separator)
    }
    let end = Int32::min(hi, line.length())
    if end == lo {
      out.write_byte(line[lo - 1])
    } else {
      out.write_bytes(line[lo - 1:end])
    }
    first = false
  }
}

///|
async fn cut_same_delimiter(
  scanner : @stream.LineScanner,
  ranges : Array[(Int32, Int32)],
  delimiter : Byte,
  only_delimited : Bool,
  output_delimiter : Bytes,
  writer~ : &@io.Writer = @stdio.stdout,
) -> Unit {
  guard scanner.next() is Some(first) else { return }
  let ending = Bytes::from_array([delimiter])
  if !first.terminated {
    if !only_delimited {
      writer.write(first.data)
      writer.write(ending)
    }
    return
  }
  let mut record = Some(first)
  let mut field = 1
  let mut range_index = 0
  let mut selected_field = false
  while record is Some(line) {
    while range_index < ranges.length() && ranges[range_index].1 < field {
      range_index += 1
    }
    if range_index < ranges.length() && ranges[range_index].0 <= field {
      if selected_field {
        writer.write(output_delimiter)
      }
      writer.write(line.data)
      selected_field = true
    }
    field += 1
    record = scanner.next()
  }
  if selected_field || !only_delimited || field > 2 {
    writer.write(ending)
  }
}

///|
async fn cut_no_fields(
  reader : &@io.Reader,
  delimiter : Byte,
  record_delimiter : Byte,
  only_delimited : Bool,
  writer~ : &@io.Writer = @stdio.stdout,
) -> Unit {
  // GNU 9.11's empty selection preserves its block-dependent undelimited fast path.
  let buffer = FixedArray::make(256 * 1024, b'\x00')
  let ending = Bytes::from_array([record_delimiter])
  let mut start = 0
  let mut limit = 0
  let mut eof = false
  for ;; {
    let remaining = limit - start
    if remaining < 4 && !eof {
      for index in 0..<remaining {
        buffer[index] = buffer[start + index]
      }
      let read = reader.read(
        buffer,
        offset=remaining,
        max_len=buffer.length() - remaining,
      )
      start = 0
      limit = remaining + read
      eof = read == 0
    }
    if start == limit {
      return
    }
    if delimiter == record_delimiter {
      if !only_delimited {
        writer.write(ending)
      }
      return
    }
    if !buffer[start:limit].iter().any(byte => byte == delimiter) {
      let mut stop = if eof { limit } else { start }
      if !eof {
        for index = limit - 1; index >= start; index = index - 1 {
          if buffer[index] == record_delimiter {
            stop = index + 1
            break
          }
        }
      }
      if stop > start {
        if !only_delimited {
          writer.write(Bytes::from_array(buffer[start:stop]))
          if eof && buffer[stop - 1] != record_delimiter {
            writer.write(ending)
          }
        }
        start = stop
        continue
      }
    }
    if !only_delimited {
      for index in start..<limit {
        if buffer[index] == record_delimiter {
          writer.write(ending)
        }
      }
    }
    start = limit
  }
}

///|
async fn process_reader(
  reader : &@io.Reader,
  field_ranges : Array[(Int32, Int32)]?,
  char_ranges : Array[(Int32, Int32)]?,
  delimiter : Byte,
  record_delimiter : Byte,
  only_delimited : Bool,
  output_delimiter : Bytes?,
  writer~ : &@io.Writer = @stdio.stdout,
) -> Unit {
  if field_ranges is Some(ranges) && ranges.is_empty() {
    cut_no_fields(reader, delimiter, record_delimiter, only_delimited, writer~)
    return
  }
  let field_output_delimiter = output_delimiter.unwrap_or(
    Bytes::from_array([delimiter]),
  )
  if field_ranges is Some(ranges) && delimiter == record_delimiter {
    cut_same_delimiter(
      @stream.LineScanner::new(reader, delimiter=record_delimiter),
      ranges,
      delimiter,
      only_delimited,
      field_output_delimiter,
      writer~,
    )
    return
  }
  let scanner = @stream.RecordReader::new(reader, delimiter=record_delimiter)
  let output = @buffer.Buffer(size_hint=@stream.chunk_size)
  defer @stream.flush_buffer(writer, output)
  let consume_record : (BytesView, Bool) -> Bool = match
    (field_ranges, char_ranges) {
    (Some(ranges), _) =>
      (line, _) => {
        if cut_fields_into(
            line, ranges, delimiter, only_delimited, field_output_delimiter, output,
          ) {
          output.write_byte(record_delimiter)
        }
        output.length() < @stream.chunk_size
      }
    (None, Some(ranges)) =>
      (line, _) => {
        cut_characters_into(line, ranges, output_delimiter, output)
        output.write_byte(record_delimiter)
        output.length() < @stream.chunk_size
      }
    _ => (_, _) => true
  }
  while scanner.next_batch() is Some(batch) {
    while !batch.each_while(consume_record) {
      @stream.flush_buffer(writer, output)
    }
  }
}

///|
async fn main {
  let metadata_args = @env.args()[1:]
  if metadata_args.length() == 1 && metadata_args[0] == "--version" {
    @stdio.stdout.write("cut 0.2.4\n")
    return
  }
  let args = @env.args()[1:]
  let parsed = @cli.parse(args, [
    @cli.flag("only-delimited", short='s'),
    @cli.option("delimiter", short='d'),
    @cli.option("fields", short='f'),
    @cli.option("bytes", short='b'),
    @cli.option("characters", short='c'),
    @cli.flag("complement"),
    @cli.option("output-delimiter"),
    @cli.flag("zero-terminated", short='z'),
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
      "Usage: cut (-b LIST | -c LIST | -f LIST [-d CHAR] [-s]) [--complement] [--output-delimiter=STRING] [-z] [FILE...]\n      --help      display this help and exit\n      --version   display version and exit\n",
    )
    return
  }
  let only_delimited = parsed.contains("only-delimited")
  let record_delimiter = if parsed.contains("zero-terminated") {
    b'\x00'
  } else {
    b'\n'
  }
  let delimiter = match parsed.last_value("delimiter") {
    Some(d) => {
      let encoded = @utf8.encode(d)
      if encoded.length() > 1 {
        @stdio.stderr.write(
          "cut: the delimiter must be a single byte in C locale\n",
        )
        @sys.exit(2)
        return
      }
      if encoded.is_empty() {
        b'\x00'
      } else {
        encoded[0]
      }
    }
    None => b'\t'
  }
  let fields_spec = parsed.last_value("fields")
  let chars_spec = parsed.last_value("characters")
  let bytes_spec = parsed.last_value("bytes")
  let mode_count = (if fields_spec is Some(_) { 1 } else { 0 }) +
    (if chars_spec is Some(_) { 1 } else { 0 }) +
    (if bytes_spec is Some(_) { 1 } else { 0 })
  if mode_count > 1 {
    @stdio.stderr.write(
      "cut: only one list may be specified\nTry 'cut --help' for more information.\n",
    )
    @sys.exit(1)
    return
  } else if mode_count == 0 {
    @stdio.stderr.write(
      "cut: you must specify a list of fields (-f) or characters (-c)\n",
    )
    @sys.exit(2)
    return
  }
  if fields_spec is None &&
    (parsed.contains("delimiter") || parsed.contains("only-delimited")) {
    @stdio.stderr.write(
      if parsed.contains("delimiter") {
        "cut: an input delimiter makes sense\n\tonly when operating on fields\nTry 'cut --help' for more information.\n"
      } else {
        "cut: suppressing non-delimited lines makes sense\n\tonly when operating on fields\nTry 'cut --help' for more information.\n"
      },
    )
    @sys.exit(1)
    return
  }
  let (field_ranges, char_ranges) = try {
    let field_ranges = match fields_spec {
      Some(spec) => Some(parse_list(spec))
      None => None
    }
    let selected_chars = match chars_spec {
      Some(spec) => Some(spec)
      None => bytes_spec
    }
    let char_ranges = match selected_chars {
      Some(spec) => Some(parse_list(spec))
      None => None
    }
    if parsed.contains("complement") {
      (field_ranges.map(complement_ranges), char_ranges.map(complement_ranges))
    } else {
      (field_ranges, char_ranges)
    }
  } catch {
    CliError(msg) => {
      @stdio.stderr.write("\{msg}\n")
      @sys.exit(2)
      return
    }
  }
  let output_delimiter = parsed
    .last_value("output-delimiter")
    .map(output_delimiter_bytes)
  let files = parsed.operands
  let sources = if files.is_empty() { ["-"] } else { files }
  let mut failed = false
  for path in sources {
    try {
      if path == "-" {
        process_reader(
          @stdio.stdin, field_ranges, char_ranges, delimiter, record_delimiter, only_delimited,
          output_delimiter,
        )
      } else {
        let file = @fs.open(path, mode=ReadOnly)
        defer file.close()
        process_reader(
          file, field_ranges, char_ranges, delimiter, record_delimiter, only_delimited,
          output_delimiter,
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
