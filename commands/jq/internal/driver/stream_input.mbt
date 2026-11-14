///|
const StreamParserBufferBytes = 4091

///|
priv suberror StreamError {
  StreamError(String, Int32, Int32)
}

///|
// Retains one input chunk, one scalar token and the current nesting path.
// Container values are never materialized; empty containers are leaf events.
priv struct StreamInput {
  reader : &@io.Reader
  file_boundaries : Set[Int64]
  mut offset : Int64
  mut chunk : Bytes
  mut position : Int32
  mut line : Int32
  mut column : Int32
  mut buffer_position : Int32
  mut buffer_limit : Int32
  mut utf8_remaining : Int32
  mut buffer_end : Bool
}

///|
fn StreamInput::new(
  reader : &@io.Reader,
  file_boundaries~ : Set[Int64] = Set([]),
) -> StreamInput {
  {
    reader,
    file_boundaries,
    offset: 0L,
    chunk: b"",
    position: 0,
    line: 1,
    column: 0,
    buffer_position: 0,
    buffer_limit: StreamParserBufferBytes,
    utf8_remaining: 0,
    buffer_end: false,
  }
}

///|
async fn StreamInput::peek(self : StreamInput) -> Byte? {
  while self.position == self.chunk.length() {
    match self.reader.read_some(max_len=65536) {
      None => return None
      Some(chunk) => {
        self.chunk = chunk
        self.position = 0
      }
    }
  }
  if self.file_boundaries.contains(self.offset) {
    self.buffer_position = 0
    self.buffer_limit = StreamParserBufferBytes
    self.utf8_remaining = 0
    self.buffer_end = true
  }
  Some(self.chunk[self.position])
}

///|
async fn StreamInput::take(self : StreamInput) -> Byte? {
  let byte = self.peek()
  if byte is Some(byte) {
    self.position += 1
    self.offset += 1L
    self.advance_buffer(byte)
    if byte == b'\n' {
      self.line += 1
      self.column = 0
    } else {
      self.column += 1
    }
  }
  byte
}

///|
fn StreamInput::advance_buffer(self : StreamInput, byte : Byte) -> Unit {
  self.buffer_position += 1
  if self.buffer_position <= StreamParserBufferBytes {
    self.utf8_remaining = if byte >= b'\x80' && byte <= b'\xbf' {
      (self.utf8_remaining - 1).max(0)
    } else if byte >= b'\xc2' && byte <= b'\xdf' {
      1
    } else if byte >= b'\xe0' && byte <= b'\xef' {
      2
    } else if byte >= b'\xf0' && byte <= b'\xf4' {
      3
    } else {
      0
    }
    if self.buffer_position == StreamParserBufferBytes {
      self.buffer_limit += self.utf8_remaining
    }
  }
  self.buffer_end = (
      byte == b'\n' && self.buffer_position <= StreamParserBufferBytes
    ) ||
    self.buffer_position == self.buffer_limit
  if self.buffer_end {
    self.buffer_position = 0
    self.buffer_limit = StreamParserBufferBytes
    self.utf8_remaining = 0
  }
}

///|
async fn StreamInput::discard_buffer(self : StreamInput) -> Unit {
  // The fixed jq CLI feeds fgets-sized, newline-terminated parser buffers.
  // Recovery drops the remainder without advancing the parser's location.
  while !self.buffer_end && self.peek() is Some(byte) {
    if self.buffer_end {
      break
    }
    self.position += 1
    self.offset += 1L
    self.advance_buffer(byte)
  }
}

///|
async fn StreamInput::space(self : StreamInput) -> Byte? {
  while self.peek() is Some(byte) && json_space(byte) {
    ignore(self.take())
  }
  self.peek()
}

///|
fn[T] StreamInput::error(
  self : StreamInput,
  message : String,
  next~ : Bool = false,
) -> T raise StreamError {
  raise StreamError(
    message,
    self.line,
    self.column + (if next { 1 } else { 0 }),
  )
}

///|
async fn StreamInput::scalar(self : StreamInput) -> Json {
  let token : Array[Byte] = []
  if self.peek() == Some(b'"') {
    token.push(self.take().unwrap())
    let mut escaped = false
    for ;; {
      guard self.take() is Some(byte) else {
        self.error("Unfinished string at EOF")
      }
      token.push(byte)
      if escaped {
        escaped = false
      } else if byte == b'\\' {
        escaped = true
      } else if byte == b'"' {
        break
      }
    }
    @json.parse(@utf8.decode_lossy(Bytes::from_array(token))) catch {
      _ => self.error("Invalid escape")
    }
  } else {
    while self.peek() is Some(byte) &&
          !json_space(byte) &&
          ![b'[', b']', b'{', b'}', b':', b',', b'"'].contains(byte) {
      token.push(self.take().unwrap())
    }
    let text = @utf8.decode(Bytes::from_array(token))
    if ["true", "false", "null"].contains(text) {
      return @json.parse(text)
    }
    match stream_number(text) {
      Some(value) => value
      None => {
        let message = if text.has_prefix("t") ||
          text.has_prefix("f") ||
          text.has_prefix("n") {
          "Invalid literal"
        } else {
          "Invalid numeric literal"
        }
        if self.peek() == Some(b'\n') {
          raise StreamError(message, self.line + 1, 0)
        }
        self.error(message, next=self.peek() is Some(_))
      }
    }
  }
}

///|
priv enum StreamPhase {
  First
  Next
  Colon
  Value
  Done
}

///|
priv struct StreamFrame {
  object : Bool
  mut phase : StreamPhase
  mut index : Int32
}

///|
async fn StreamInput::read(
  self : StreamInput,
  emit : async (Json) -> Unit,
  errors~ : Bool = false,
) -> Unit {
  if self.peek() == Some(b'\xef') {
    ignore(self.take())
    guard self.take() == Some(b'\xbb') && self.take() == Some(b'\xbf') else {
      self.error("Malformed BOM")
    }
    self.column = 0
  }
  let frames : Array[StreamFrame] = []
  let path : Array[Json] = []
  let mut pending : Json? = None
  while self.space() is Some(byte) {
    let current = frames.last()
    let failure = try {
      match byte {
        b'[' | b'{' => {
          ignore(self.take())
          if current is Some(frame) {
            guard (!frame.object && frame.phase is (First | Next)) ||
              (frame.object && frame.phase is Value) else {
              self.error("Expected a separator between values")
            }
            frame.phase = Done
          }
          let object = byte == b'{'
          frames.push({ object, phase: First, index: 0, })
          path.push(if object { Json::null() } else { Json(0) })
        }
        b':' => {
          ignore(self.take())
          guard current is Some(frame) && frame.object && frame.phase is Colon else {
            self.error("':' not as part of an object")
          }
          guard pending is Some(String(_) as key) else {
            self.error("Object keys must be strings")
          }
          path[path.length() - 1] = key
          pending = None
          frame.phase = Value
        }
        b',' => {
          ignore(self.take())
          guard current is Some(frame) && frame.phase is Done else {
            self.error("Expected value before ','")
          }
          if pending is Some(value) {
            emit(Json::array([Json::array([..path]), value]))
            pending = None
          }
          frame.index += 1
          frame.phase = Next
          path[path.length() - 1] = if frame.object {
            Json::null()
          } else {
            Json(frame.index)
          }
        }
        b']' | b'}' => {
          ignore(self.take())
          guard current is Some(frame) else {
            self.error(
              "Unmatched '" +
              byte.to_int().to_char().unwrap().to_string() +
              "' at the top-level",
            )
          }
          if frame.phase is Next {
            self.error(
              if frame.object {
                "Expected another key:value pair"
              } else {
                "Expected another array element"
              },
            )
          }
          guard frame.object == (byte == b'}') else {
            self.error("Unmatched container delimiter")
          }
          if frame.object && frame.phase is Colon {
            self.error("Objects must consist of key:value pairs")
          }
          guard frame.phase is (First | Done) else {
            self.error("Missing value in key:value pair")
          }
          let empty = frame.phase is First
          if pending is Some(value) {
            emit(Json::array([Json::array([..path]), value]))
            pending = None
          }
          if !empty {
            emit(Json::array([Json::array([..path])]))
          }
          ignore(frames.pop())
          ignore(path.pop())
          if empty {
            emit(
              Json::array([
                Json::array([..path]),
                if frame.object {
                  Json::object(Map([]))
                } else {
                  Json::array([])
                },
              ]),
            )
          }
        }
        _ => {
          let value = self.scalar()
          match current {
            None => {
              if byte != b'"' &&
                self.peek() is Some(delimiter) &&
                [b']', b'}', b':', b','].contains(delimiter) {
                self.error(
                  match delimiter {
                    b']' => "Unmatched ']' at the top-level"
                    b'}' => "Unmatched '}' at the top-level"
                    b':' => "':' not as part of an object"
                    _ => "Expected value before ','"
                  },
                  next=true,
                )
              }
              emit(Json::array([Json::array([]), value]))
            }
            Some(frame) =>
              if frame.object && frame.phase is (First | Next) {
                pending = Some(value)
                frame.phase = Colon
              } else {
                guard (!frame.object && frame.phase is (First | Next)) ||
                  (frame.object && frame.phase is Value) else {
                  self.error("Expected separator between values", next=true)
                }
                pending = Some(value)
                frame.phase = Done
              }
          }
        }
      }
      None
    } catch {
      StreamError(_, _, _) as error => Some(error)
      error => raise error
    }
    if failure is Some(StreamError(message, line, column) as error) {
      if !errors {
        raise error
      }
      if line > self.line || (line == self.line && column > self.column) {
        ignore(self.take())
      }
      self.line = line
      self.column = column
      emit(
        Json::array([
          Json::string(
            message +
            " at line " +
            line.to_string() +
            ", column " +
            column.to_string(),
          ),
          Json::array([..path]),
        ]),
      )
      pending = None
      frames.clear()
      path.clear()
      self.discard_buffer()
    }
  }
  if !frames.is_empty() {
    if errors {
      emit(
        Json::array([
          Json::string(
            "Unfinished JSON term at EOF at line " +
            self.line.to_string() +
            ", column " +
            self.column.to_string(),
          ),
          Json::array([..path]),
        ]),
      )
    } else {
      self.error("Unfinished JSON term at EOF")
    }
  }
}
