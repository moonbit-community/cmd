///|
priv enum InputMode {
  Words
  Lines
  Delimited(Int32)
}

///|
priv struct ItemReader {
  reader : &@io.Reader
  mode : InputMode
  limit : Int32
  mut buffer : Bytes
  mut position : Int32
  mut ended : Bool
}

///|
fn ItemReader::new(
  reader : &@io.Reader,
  mode : InputMode,
  limit : Int32,
) -> ItemReader {
  { reader, mode, limit, buffer: b"", position: 0, ended: false, }
}

///|
async fn ItemReader::next(self : ItemReader) -> BytesView? {
  guard !self.ended else { return None }
  let bytes : Array[Byte] = []
  let mut quote : Byte? = None
  let mut escaped = false
  let mut started = false
  let literal_delimiter = match self.mode {
    Words => None
    Lines => Some(10)
    Delimited(delimiter) => Some(delimiter)
  }
  for ;; {
    if self.position == self.buffer.length() {
      match self.reader.read_some(max_len=65536) {
        Some(chunk) => {
          self.buffer = chunk
          self.position = 0
        }
        None => {
          self.ended = true
          if escaped {
            raise XargsError("input ends with an unmatched backslash")
          }
          if quote is Some(delimiter) {
            raise XargsError(
              "input contains an unmatched '\'\{delimiter.to_int().unsafe_to_char()}\' quote",
            )
          }
          return if started { Some(Bytes::from_array(bytes)) } else { None }
        }
      }
    }
    if literal_delimiter is Some(delimiter) {
      let start = self.position
      let mut end = start
      // Preserve the signed-char delimiter boundary. Decode a completed view
      // before refilling; only items crossing chunks need an owned accumulator.
      while end < self.buffer.length() && self.buffer[end].to_int() != delimiter {
        end += 1
      }
      if end - start > self.limit - bytes.length() {
        raise XargsError("input item exceeds \{self.limit} byte limit")
      }
      self.position = end
      if end < self.buffer.length() && bytes.is_empty() {
        self.position += 1
        return Some(self.buffer[start:end])
      }
      for byte in self.buffer[start:end] {
        bytes.push(byte)
      }
      if end < self.buffer.length() {
        self.position += 1
        return Some(Bytes::from_array(bytes))
      }
      started = started || end > start
      continue
    }
    while self.position < self.buffer.length() {
      let byte = self.buffer[self.position]
      self.position += 1
      if escaped {
        bytes.push(byte)
        escaped = false
      } else if byte == b'\\' && quote != Some(b'\'') {
        escaped = true
        started = true
      } else {
        match quote {
          Some(delimiter) =>
            if byte == delimiter {
              quote = None
            } else {
              bytes.push(byte)
            }
          None =>
            if byte == b'\'' || byte == b'"' {
              quote = Some(byte)
              started = true
            } else if byte is (b' ' | b'\t' | b'\n' | b'\r') {
              if started {
                return Some(Bytes::from_array(bytes))
              }
            } else {
              bytes.push(byte)
              started = true
            }
        }
      }
      if bytes.length() > self.limit {
        raise XargsError("input item exceeds \{self.limit} byte limit")
      }
    }
  }
}

///|
fn input_text(bytes : BytesView) -> String raise XargsError {
  @utf8.decode(bytes) catch {
    _ => raise XargsError("input is not valid UTF-8")
  }
}
