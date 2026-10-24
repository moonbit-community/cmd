///|
priv struct GrepInput {
  reader : &@io.Reader
  delimiter : Bytes
  binary_mode : BinaryMode
  mut bytes : Bytes
  mut position : Int32
  mut offset : Int64
  mut number : Int64
  mut binary : Bool
  mut error : Error?
}

///|
fn GrepInput::new(
  reader : &@io.Reader,
  delimiter : Byte,
  binary_mode : BinaryMode,
) -> GrepInput {
  {
    reader,
    delimiter: Bytes::from_array([delimiter]),
    binary_mode,
    bytes: b"",
    position: 0,
    offset: 0L,
    number: 0L,
    binary: false,
    error: None,
  }
}

///|
// A record inside one immutable chunk is a view. Only a cross-chunk record
// needs accumulation; consumed prefixes are never rescanned or recopied.
async fn GrepInput::next(self : GrepInput) -> Record? {
  if self.error is Some(error) {
    raise error
  }
  let offset = self.offset
  let mut pending : @buffer.Buffer? = None
  for ;; {
    if self.position == self.bytes.length() {
      let chunk = self.reader.read_some(max_len=65536) catch {
        error => {
          self.error = Some(error)
          None
        }
      }
      match chunk {
        None => {
          if pending is Some(buffer) {
            self.number += 1L
            return Some({
              data: buffer.to_bytes()[:],
              terminated: false,
              number: self.number,
              offset,
            })
          }
          if self.error is Some(error) {
            raise error
          }
          return None
        }
        Some(bytes) => {
          self.bytes = bytes
          self.position = 0
          if self.binary_mode != Text && bytes.find(b"\x00") is Some(_) {
            self.binary = true
            if self.binary_mode == WithoutMatch {
              return None
            }
          }
        }
      }
    }
    let start = self.position
    self.position = match self.bytes[start:].find(self.delimiter[:]) {
      Some(relative) => start + relative
      None => self.bytes.length()
    }
    let part = self.bytes[start:self.position]
    self.offset += part.length().to_int64()
    if self.position < self.bytes.length() {
      self.position += 1
      self.offset += 1L
      self.number += 1L
      let data = match pending {
        Some(buffer) => {
          buffer.write_bytes(part)
          buffer.write_byte(self.delimiter[0])
          let bytes = buffer.to_bytes()
          bytes[:bytes.length() - 1]
        }
        None => part
      }
      return Some({ data, terminated: true, number: self.number, offset, })
    }
    if !part.is_empty() {
      let buffer = match pending {
        Some(buffer) => buffer
        None => {
          let buffer = @buffer.Buffer()
          pending = Some(buffer)
          buffer
        }
      }
      buffer.write_bytes(part)
    }
  }
}

///|
fn Matcher::matches_record(
  self : Matcher,
  record : BytesView,
  ignore_case : Bool,
) -> Bool {
  match self {
    Fixed(patterns, whole, word) => {
      let line = if ignore_case { folded_bytes(record)[:] } else { record }
      fixed_span(patterns, line, 0, whole, word) is Some(_)
    }
    Regular(_, _, _) => self.next_match(bytes_as_string(record), 0) is Some(_)
  }
}

///|
async fn write_matches(
  record : Record,
  path : String,
  matcher : Matcher,
  options : GrepOptions,
  prefix_filename : Bool,
  output : &@io.Writer,
) -> Bool {
  let next : (Int32) -> (Int32, Int32)? = match matcher {
    Fixed(patterns, whole, word) => {
      let line = if options.ignore_case {
        folded_bytes(record.data)[:]
      } else {
        record.data
      }
      position => fixed_span(patterns, line, position, whole, word)
    }
    Regular(_, _, _) => {
      let line = bytes_as_string(record.data)
      position => matcher.next_match(line, position)
    }
  }
  let mut position = 0
  let first = next(position)
  let mut hit = first
  while hit is Some((start, end)) {
    if end > start {
      write_record(
        {
          data: record.data[start:end],
          terminated: record.terminated && end == record.data.length(),
          number: record.number,
          offset: record.offset + start.to_int64(),
        },
        path,
        options,
        prefix_filename,
        true,
        output,
      )
      position = end
    } else {
      position = start + 1
    }
    if position > record.data.length() {
      break
    }
    hit = next(position)
  }
  first is Some(_)
}

///|
async fn process_reader(
  reader : &@io.Reader,
  path : String,
  matcher : Matcher,
  options : GrepOptions,
  prefix_filename : Bool,
  stdout~ : &@io.Writer = @stdio.stdout,
  stderr~ : &@io.Writer = @stdio.stderr,
) -> Bool {
  let input = GrepInput::new(
    reader,
    if options.zero_terminated {
      b'\x00'
    } else {
      b'\n'
    },
    if options.zero_terminated {
      Text
    } else {
      options.binary_mode
    },
  )
  let output = @io.BufferedWriter::new(stdout, size=65536)
  let before : @deque.Deque[Record] = @deque.Deque([])
  let mut selected_count = 0UL
  let mut emitted_through = 0L
  let mut after = 0
  let mut binary_reported = false
  let emit_records = !options.count &&
    !options.files_with_matches &&
    !options.files_without_match &&
    !options.quiet
  for ;; {
    let record = {
      errdefer output.flush()
      input.next()
    }
    guard record is Some(record) else { break }
    if emit_records &&
      options.only_matching &&
      !options.invert &&
      (!input.binary || options.binary_mode != Report) {
      if write_matches(record, path, matcher, options, prefix_filename, output) {
        selected_count += 1UL
      }
      continue
    }
    let matched = matcher.matches_record(record.data, options.ignore_case)
    let keep = if options.invert { !matched } else { matched }
    if keep {
      selected_count += 1UL
      if options.quiet {
        return true
      }
      if !options.count && options.files_with_matches {
        output.write(path + "\n")
        output.flush()
        return true
      }
    }
    if !emit_records {
      continue
    }
    if input.binary && options.binary_mode == Report {
      if keep && !binary_reported {
        output.flush()
        let name = if path == "-" { "(standard input)" } else { path }
        stderr.write("grep: \{name}: binary file matches\n")
        binary_reported = true
      }
      continue
    }
    if options.only_matching {
      continue
    }
    if keep {
      let first = match before.front() {
        Some(record) => record.number
        None => record.number
      }
      if options.context_enabled &&
        emitted_through > 0L &&
        first > emitted_through + 1L {
        output.write("--\n")
      }
      while before.pop_front() is Some(context) {
        if context.number > emitted_through {
          write_record(context, path, options, prefix_filename, false, output)
          emitted_through = context.number
        }
      }
      write_record(record, path, options, prefix_filename, true, output)
      emitted_through = record.number
      after = options.after_context
    } else if after > 0 {
      write_record(record, path, options, prefix_filename, false, output)
      emitted_through = record.number
      after -= 1
    }
    if options.before_context > 0 {
      before.push_back(record)
      if before.length() > options.before_context {
        ignore(before.pop_front())
      }
    }
  }
  if input.binary && options.binary_mode == WithoutMatch {
    selected_count = 0UL
  }
  if options.count {
    let prefix = if prefix_filename { path + ":" } else { "" }
    output.write("\{prefix}\{selected_count}\n")
  } else if options.files_without_match && selected_count == 0UL {
    output.write(path + "\n")
  }
  output.flush()
  if options.files_without_match {
    selected_count == 0UL
  } else {
    selected_count > 0UL
  }
}
