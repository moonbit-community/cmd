///|
// Strategy: grep-span-output
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
  mut prefiltered : Bool
  mut pending_match : MatchEmitter?
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
    prefiltered: false,
    pending_match: None,
  }
}

///|
// A record inside one immutable chunk is a view. Only a cross-chunk record
// needs accumulation; consumed prefixes are never rescanned or recopied.
fn GrepInput::next_buffered(self : GrepInput) -> Record? {
  guard self.error is None else { return None }
  let start = self.position
  guard self.bytes[start:].find(self.delimiter) is Some(relative) else {
    return None
  }
  let end = start + relative
  let offset = self.offset
  self.consume_records(end + 1, 1L)
  Some({
    data: self.bytes[start:end],
    terminated: true,
    number: self.number,
    offset,
  })
}

///|
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
          self.prefiltered = false
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
    ManyFixed(set) =>
      set.matches(if ignore_case { folded_bytes(record)[:] } else { record })
    Fixed(patterns, whole, word) => {
      let line = if ignore_case { folded_bytes(record)[:] } else { record }
      fixed_span(patterns, line, 0, whole, word) is Some(_)
    }
    Regular(patterns, whole, word) => {
      for pattern in patterns {
        if pattern.matches(record, whole~, word~) {
          return true
        }
      }
      false
    }
  }
}

///|
priv struct MatchEmitter {
  record : Record
  next : (Int32) -> (Int32, Int32)?
  mut hit : (Int32, Int32)?
  selected : Bool
}

///|
fn MatchEmitter::new(
  record : Record,
  matcher : Matcher,
  options : GrepOptions,
) -> MatchEmitter {
  let next : (Int32) -> (Int32, Int32)? = match matcher {
    ManyFixed(set) => {
      let line = if options.ignore_case {
        folded_bytes(record.data)[:]
      } else {
        record.data
      }
      position => set.find_span(line, start=position)
    }
    Fixed(patterns, whole, word) => {
      let line = if options.ignore_case {
        folded_bytes(record.data)[:]
      } else {
        record.data
      }
      position => fixed_span(patterns, line, position, whole, word)
    }
    Regular(patterns, whole, word) => {
      let searches = @bytere.search_bytes(patterns, record.data, whole~, word~)
      position => {
        let mut best : (Int32, Int32)? = None
        for search in searches {
          if search.find_span(start=position) is Some(hit) {
            match best {
              Some((start, end)) =>
                if hit.0 < start || (hit.0 == start && hit.1 > end) {
                  best = Some(hit)
                }
              None => best = Some(hit)
            }
          }
        }
        best
      }
    }
  }
  let first = next(0)
  { record, next, hit: first, selected: first is Some(_), }
}

///|
fn MatchEmitter::consume(
  self : MatchEmitter,
  path : String,
  options : GrepOptions,
  prefix_filename : Bool,
  buffer : @buffer.Buffer,
) -> Bool {
  let record = self.record
  while self.hit is Some((start, end)) {
    let position = if end > start {
      if prefix_filename {
        buffer.write_string_utf8(path)
        buffer.write_byte(b':')
      }
      if options.line_number {
        buffer.write_string_utf8(record.number.to_string())
        buffer.write_byte(b':')
      }
      if options.byte_offset {
        buffer.write_string_utf8((record.offset + start.to_int64()).to_string())
        buffer.write_byte(b':')
      }
      buffer.write_bytes(record.data[start:end])
      buffer.write_byte(if options.zero_terminated { b'\x00' } else { b'\n' })
      end
    } else {
      start + 1
    }
    self.hit = if position > record.data.length() {
      None
    } else {
      (self.next)(position)
    }
    if buffer.length() >= @stream.chunk_size {
      return false
    }
  }
  true
}

///|
/// Resume a pending record after output flushing, then consume buffered records
/// synchronously. Only refill and flush cross an async boundary.
fn GrepInput::emit_buffered(
  self : GrepInput,
  path : String,
  matcher : Matcher,
  options : GrepOptions,
  prefix_filename : Bool,
  buffer : @buffer.Buffer,
) -> UInt64 {
  let mut selected = 0UL
  for ;; {
    let emitter = match self.pending_match {
      Some(emitter) => emitter
      None => {
        guard self.next_buffered() is Some(record) else { break }
        let emitter = MatchEmitter::new(record, matcher, options)
        self.pending_match = Some(emitter)
        emitter
      }
    }
    if !emitter.consume(path, options, prefix_filename, buffer) {
      break
    }
    if emitter.selected {
      selected += 1UL
    }
    self.pending_match = None
  }
  selected
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
  // Record output owns BufferedWriter; span output owns reset-before-write
  // storage. Only the input-error boundary flushes BufferedWriter after failure.
  let spans = @buffer.Buffer(size_hint=@stream.chunk_size)
  defer @stream.flush_buffer(stdout, spans)
  let before : @deque.Deque[Record] = @deque.Deque([])
  let mut selected_count = 0UL
  let mut emitted_through = 0L
  let mut after = 0
  let mut binary_reported = false
  let execution = options.execution(prefix_filename)
  let emit_records = !(execution is Summary(_))
  for ;; {
    if !options.invert && !options.context_enabled {
      input.skip_nonmatching(matcher, options.ignore_case)
    }
    if execution is BatchedRecords &&
      (!input.binary || options.binary_mode != Report) {
      selected_count += input.collect_records(matcher, options, spans)
      @stream.flush_buffer(output, spans)
    }
    if execution is MatchSpans &&
      (!input.binary || options.binary_mode != Report) {
      selected_count += input.emit_buffered(
        path, matcher, options, prefix_filename, spans,
      )
      if spans.length() >= @stream.chunk_size {
        @stream.flush_buffer(stdout, spans)
        continue
      }
    }
    if execution is Summary(true) {
      selected_count += input.count_buffered(
        matcher,
        options.ignore_case,
        options.invert,
      )
    }
    let record = {
      errdefer output.flush()
      match input.next_buffered() {
        Some(record) => Some(record)
        None => input.next()
      }
    }
    guard record is Some(record) else { break }
    if execution is MatchSpans &&
      (!input.binary || options.binary_mode != Report) {
      input.pending_match = Some(MatchEmitter::new(record, matcher, options))
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
        @stream.flush_buffer(stdout, spans)
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
