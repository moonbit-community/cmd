///|
// Strategy: jq-frame-chunks

///|
/// Frames JSON values without waiting for the end of the entire input stream.
/// A frame is parsed by the standard JSON parser before it reaches the query.
priv struct JsonInput {
  reader : &@io.Reader
  mut chunk : Bytes
  mut position : Int32
}

///|
fn JsonInput::new(reader : &@io.Reader) -> JsonInput {
  { reader, chunk: b"", position: 0, }
}

///|
priv struct JsonFrame {
  bytes : Array[Byte]
  mut compound : Bool
  mut depth : Int32
  mut quoted : Bool
  mut escaped : Bool
}

///|
fn json_space(byte : Byte) -> Bool {
  byte is (b' ' | b'\t' | b'\r' | b'\n')
}

///|
fn JsonInput::scan(self : JsonInput, frame : JsonFrame) -> Bool {
  while self.position < self.chunk.length() {
    let byte = self.chunk[self.position]
    self.position += 1
    if frame.bytes.is_empty() {
      if json_space(byte) {
        continue
      }
      frame.bytes.push(byte)
      frame.compound = byte is (b'{' | b'[')
      frame.depth = if frame.compound { 1 } else { 0 }
      frame.quoted = byte == b'"'
      continue
    }
    if frame.quoted {
      frame.bytes.push(byte)
      if frame.escaped {
        frame.escaped = false
      } else if byte == b'\\' {
        frame.escaped = true
      } else if byte == b'"' {
        frame.quoted = false
        if !frame.compound {
          return true
        }
      }
    } else if frame.compound {
      frame.bytes.push(byte)
      match byte {
        b'"' => frame.quoted = true
        b'{' | b'[' => frame.depth += 1
        b'}' | b']' => {
          frame.depth -= 1
          if frame.depth == 0 {
            return true
          }
        }
        _ => ()
      }
    } else if json_space(byte) {
      return true
    } else if byte is (b'{' | b'[' | b'"') {
      self.position -= 1
      return true
    } else {
      frame.bytes.push(byte)
    }
  }
  false
}

///|
async fn JsonInput::next(self : JsonInput) -> Json? {
  let frame : JsonFrame = {
    bytes: [],
    compound: false,
    depth: 0,
    quoted: false,
    escaped: false,
  }
  while !self.scan(frame) {
    match self.reader.read_some(max_len=65536) {
      None => break
      Some(chunk) => {
        self.chunk = chunk
        self.position = 0
      }
    }
  }
  if frame.bytes.is_empty() {
    None
  } else {
    Some(@json.parse(@utf8.decode(Bytes::from_array(frame.bytes))))
  }
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
