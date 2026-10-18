///|
struct FoldState {
  width : Int32
  bytes : Bool
  characters : Bool
  spaces : Bool
  mut pending : Array[Byte]
  mut column : Int32
  mut last_width : Int32
}

///|
fn FoldState::new(
  width : Int32,
  bytes : Bool,
  characters : Bool,
  spaces : Bool,
) -> FoldState {
  { width, bytes, characters, spaces, pending: [], column: 0, last_width: 0, }
}

///|
fn FoldState::advance(self : FoldState, byte : Byte) -> Int32 {
  if self.bytes {
    return self.column + 1
  }
  match byte {
    b'\b' => (self.column - self.last_width).max(0)
    b'\r' => 0
    b'\t' => self.column + 8 - self.column % 8
    _ => {
      self.last_width = if byte == b'\x00' && !self.characters { 0 } else { 1 }
      self.column + self.last_width
    }
  }
}

///|
fn FoldState::feed(self : FoldState, data : Bytes) -> Bytes {
  let out : Array[Byte] = []
  for byte in data {
    if byte == b'\n' {
      out.append(self.pending)
      out.push(byte)
      self.pending.clear()
      self.column = 0
      continue
    }
    for ;; {
      let next = self.advance(byte)
      if next <= self.width || self.pending.is_empty() {
        self.column = next
        self.pending.push(byte)
        break
      }
      let mut split = self.pending.length()
      if self.spaces {
        for index = self.pending.length() - 1; index >= 0; index = index - 1 {
          if self.pending[index] is (b' ' | b'\t') {
            split = index + 1
            break
          }
        }
      }
      out.append(self.pending[:split])
      out.push(b'\n')
      self.pending = self.pending[split:].to_owned()
      self.column = 0
      for buffered in self.pending {
        self.column = self.advance(buffered)
      }
    }
  }
  Bytes::from_array(out)
}

///|
async fn fold_stream(reader : &@io.Reader, state : FoldState) -> Unit {
  while @stream.read_chunk(reader) is Some(chunk) {
    @stdio.stdout.write(state.feed(chunk))
  }
  @stdio.stdout.write(Bytes::from_array(state.pending))
}
