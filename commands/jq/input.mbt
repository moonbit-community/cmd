///|
/// Frames JSON values without waiting for the end of the entire input stream.
/// A frame is parsed by the standard JSON parser before it reaches the query.
priv struct JsonInput {
  reader : &@io.Reader
  mut chunk : Bytes
  mut position : Int
  mut pending : Byte?
}

///|
fn JsonInput::new(reader : &@io.Reader) -> JsonInput {
  { reader, chunk: b"", position: 0, pending: None, }
}

///|
async fn JsonInput::byte(self : JsonInput) -> Byte? {
  if self.pending is Some(byte) {
    self.pending = None
    return Some(byte)
  }
  if self.position == self.chunk.length() {
    match self.reader.read_some(max_len=65536) {
      None => return None
      Some(chunk) => {
        self.chunk = chunk
        self.position = 0
      }
    }
  }
  let byte = self.chunk[self.position]
  self.position += 1
  Some(byte)
}

///|
fn json_space(byte : Byte) -> Bool {
  byte is (b' ' | b'\t' | b'\r' | b'\n')
}

///|
async fn JsonInput::next(self : JsonInput) -> Json? {
  let frame : Array[Byte] = []
  while self.byte() is Some(byte) {
    if !json_space(byte) {
      frame.push(byte)
      break
    }
  }
  if frame.is_empty() {
    return None
  }
  let first = frame[0]
  let compound = first is (b'{' | b'[')
  let mut depth = if compound { 1 } else { 0 }
  let mut quoted = first == b'"'
  let mut escaped = false
  while self.byte() is Some(byte) {
    if quoted {
      frame.push(byte)
      if escaped {
        escaped = false
      } else if byte == b'\\' {
        escaped = true
      } else if byte == b'"' {
        quoted = false
        if !compound {
          break
        }
      }
    } else if compound {
      frame.push(byte)
      match byte {
        b'"' => quoted = true
        b'{' | b'[' => depth += 1
        b'}' | b']' => {
          depth -= 1
          if depth == 0 {
            break
          }
        }
        _ => ()
      }
    } else if json_space(byte) {
      break
    } else if byte is (b'{' | b'[' | b'"') {
      self.pending = Some(byte)
      break
    } else {
      frame.push(byte)
    }
  }
  Some(@json.parse(@utf8.decode(Bytes::from_array(frame))))
}

///|
priv struct Evaluation {
  query : @ast.Expr
  options : CliOptions
  colors : Array[String]?
  mut last : Json?
  values : Array[Json]
  raw : Array[Byte]
}

///|
async fn Evaluation::emit(self : Evaluation, input : Json) -> Unit {
  let options = self.options
  let last = write_results(
    @ast.eval(self.query, input),
    options.raw_output || options.join_output,
    options.compact_output,
    options.join_output,
    options.sort_keys,
    options.indent,
    options.tab,
    self.colors,
  )
  if last is Some(_) {
    self.last = last
  }
}

///|
async fn Evaluation::consume(self : Evaluation, value : Json) -> Unit {
  if self.options.slurp {
    self.values.push(value)
  } else {
    self.emit(value)
  }
}

///|
async fn Evaluation::read(self : Evaluation, reader : &@io.Reader) -> Unit {
  if self.options.raw_input && self.options.slurp {
    while reader.read_some(max_len=65536) is Some(chunk) {
      for byte in chunk {
        self.raw.push(byte)
      }
    }
  } else if self.options.raw_input || self.options.logs {
    let lines = @stream.LineScanner::new(reader)
    while lines.next() is Some(line) {
      let text = @utf8.decode(line.data)
      let value = if self.options.raw_input {
        Json::string(text)
      } else {
        @json.parse(text) catch {
          _ => continue
        }
      }
      self.consume(value)
    }
  } else {
    let input = JsonInput::new(reader)
    while input.next() is Some(value) {
      self.consume(value)
    }
  }
}
