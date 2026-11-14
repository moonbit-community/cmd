///|
// Strategy: jq-frame-chunks

///|
/// Open the next operand only when the parser asks for another byte.
priv struct Sources {
  inputs : Array[InputSource]
  stdin : &@io.Reader
  report : async (String) -> Unit
  separate_files : Bool
  boundaries : Set[Int64]
  mut index : Int32
  mut active : &@io.Reader?
  mut file : @fs.File?
  mut chunk : Bytes
  mut position : Int32
  mut offset : Int64
  mut filename : String?
  mut line : Int32
  mut status : Int32
}

///|
fn Sources::new(
  inputs : Array[InputSource],
  stdin : &@io.Reader,
  report : async (String) -> Unit,
  separate_files~ : Bool = false,
) -> Sources {
  {
    inputs,
    stdin,
    report,
    separate_files,
    boundaries: Set([]),
    index: 0,
    active: None,
    file: None,
    chunk: b"",
    position: 0,
    offset: 0L,
    filename: None,
    line: 0,
    status: 0,
  }
}

///|
fn Sources::close(self : Sources) -> Unit {
  if self.file is Some(file) {
    file.close()
  }
  self.file = None
  self.active = None
}

///|
async fn Sources::next_chunk(self : Sources) -> Bytes? {
  while true {
    if self.active is None {
      if self.index == self.inputs.length() {
        return None
      }
      let source = self.inputs[self.index]
      self.index += 1
      self.chunk = b""
      self.position = 0
      self.line = 0
      match source {
        Stdin => {
          self.active = Some(self.stdin)
          self.filename = Some("<stdin>")
        }
        File(path) => {
          self.filename = Some(path)
          let file = @fs.open(path, mode=ReadOnly) catch {
            error => {
              self.status = 2
              let reason = if @fs.exists(path) {
                error.to_string()
              } else {
                "No such file or directory"
              }
              (self.report)(
                "jq: error: Could not open file \{path}: \{reason}\n",
              )
              continue
            }
          }
          self.file = Some(file)
          self.active = Some(file)
        }
      }
    }
    let reader = self.active.unwrap()
    if self.position == self.chunk.length() {
      match reader.read_some(max_len=65536) {
        None => {
          self.close()
          self.boundaries.add(self.offset)
          // Logs are independently framed per operand, unlike jq raw input.
          if self.separate_files {
            self.offset += 1L
            return Some(b"\n")
          }
          continue
        }
        Some(chunk) => {
          self.chunk = chunk
          self.position = 0
        }
      }
    }
    let limit = StreamParserBufferBytes.min(self.chunk.length() - self.position)
    let start = self.position
    let mut count = 0
    while count < limit {
      let byte = self.chunk[self.position]
      self.position += 1
      self.offset += 1L
      count += 1
      if byte == b'\n' {
        self.line += 1
        break
      }
    }
    return Some(self.chunk[start:self.position].to_owned())
  }
  None
}

///|
priv struct InputCursor {
  sources : Sources
  parser : StreamInput
  options : CliOptions
  mut slurped : Bool
}

///|
fn InputCursor::new(
  options : CliOptions,
  stdin : &@io.Reader,
  report : async (String) -> Unit,
) -> InputCursor {
  let sources = Sources::new(
    options.inputs,
    stdin,
    report,
    separate_files=options.logs,
  )
  {
    sources,
    parser: StreamInput::pull(() => sources.next_chunk(), sources.boundaries),
    options,
    slurped: false,
  }
}

///|
async fn InputCursor::next(self : InputCursor) -> Json? {
  if self.options.slurp {
    if self.slurped {
      return None
    }
    self.slurped = true
    if self.options.raw_input {
      let bytes : Array[Byte] = []
      while self.parser.take() is Some(byte) {
        bytes.push(byte)
      }
      return Some(Json::string(@utf8.decode_lossy(Bytes::from_array(bytes))))
    }
    let values : Array[Json] = []
    while self.next_value() is Some(value) {
      values.push(value)
    }
    return Some(Json::array(values))
  }
  self.next_value()
}

///|
async fn InputCursor::next_value(self : InputCursor) -> Json? {
  if self.options.raw_input || self.options.logs {
    while true {
      let bytes : Array[Byte] = []
      let mut ended = false
      while self.parser.take() is Some(byte) {
        ended = true
        if byte == b'\n' {
          break
        }
        bytes.push(byte)
      }
      if !ended {
        return None
      }
      let data = Bytes::from_array(bytes)
      let text = if self.options.logs {
        @utf8.decode(data)
      } else {
        @utf8.decode_lossy(data)
      }
      if self.options.raw_input {
        return Some(Json::string(text))
      }
      return Some(@json.parse(text) catch { _ => continue })
    }
  }
  if self.options.stream {
    return self.parser.next_event(errors=self.options.stream_errors)
  }
  self.parser.next_json()
}

///|
fn assemble(root : Json, path : ArrayView[Json], value : Json) -> Json {
  match path {
    [] => value
    [String(key), .. rest] => {
      let fields = match root {
        Object(fields) => fields
        _ => Map([])
      }
      fields[key] = assemble(fields.get(key).unwrap_or(null), rest, value)
      Json::object(fields)
    }
    [Number(index, ..), .. rest] => {
      let items = match root {
        Array(items) => items
        _ => []
      }
      let index = index.to_int()
      while items.length() <= index {
        items.push(null)
      }
      items[index] = assemble(items[index], rest, value)
      Json::array(items)
    }
    _ => root
  }
}

///|
#warnings("-78")
async fn InputCursor::request(
  self : InputCursor,
  request : @ast.Request,
) -> Result[Json?, @ast.InterpreterError] {
  match request {
    Input =>
      Ok(self.next()) catch {
        StreamError(message, line, column) =>
          Err(@ast.InputError("\{message} at line \{line}, column \{column}"))
        error => raise error
      }
    InputFilename =>
      Ok(Some(self.sources.filename.map(Json::string).unwrap_or(null)))
    InputLineNumber => Ok(Some(Json(self.sources.line)))
    ModuleMetadata(_) =>
      Err(@ast.EvalError("Module metadata loader is unavailable"))
  }
}
