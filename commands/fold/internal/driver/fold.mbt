///|
priv enum CountMode {
  Bytes
  Characters
  Columns
}

///|
priv struct FoldState {
  width : Int32
  mode : CountMode
  spaces : Bool
  profile : @textwidth.Profile
  decoder : @textwidth.Decoder
  mut pending : Array[Byte]
  mut column : Int32
  mut last_width : Int32
  mut blank_end : Int32
}

///|
fn FoldState::new(
  width : Int32,
  bytes : Bool,
  characters : Bool,
  spaces : Bool,
  profile~ : @textwidth.Profile = CBytes,
) -> FoldState {
  let mode = if bytes {
    Bytes
  } else if characters {
    Characters
  } else {
    Columns
  }
  {
    width,
    mode,
    spaces,
    profile,
    decoder: @textwidth.Decoder(profile),
    pending: [],
    column: 0,
    last_width: 0,
    blank_end: 0,
  }
}

///|
fn FoldState::advance(
  self : FoldState,
  ch : Char?,
  byte_count : Int32,
) -> Int32 {
  if self.mode is Bytes {
    return self.column + byte_count
  }
  match ch {
    Some('\b') => (self.column - self.last_width).max(0)
    Some('\r') => 0
    Some('\t') => self.column + 8 - self.column % 8
    _ => {
      self.last_width = if self.mode is Characters {
        1
      } else if self.profile == CBytes {
        if ch is Some('\u0000') {
          0
        } else {
          1
        }
      } else {
        @textwidth.cells(ch, fallback=1)
      }
      self.column + self.last_width
    }
  }
}

///|
fn FoldState::feed(
  self : FoldState,
  data : Bytes,
  eof~ : Bool = false,
) -> Bytes {
  let out : Array[Byte] = []
  self.decoder.feed(
    data[:],
    (ch, raw) => {
      if ch is Some('\n') {
        out.append(self.pending)
        out.push(b'\n')
        self.pending.clear()
        self.blank_end = 0
        self.column = 0
        return
      }
      for ;; {
        let next = self.advance(ch, raw.length())
        if next <= self.width || self.pending.is_empty() {
          self.column = next
          for b in raw {
            self.pending.push(b)
          }
          if self.spaces && @textwidth.is_blank(ch) {
            self.blank_end = self.pending.length()
          }
          break
        }
        let split = if self.blank_end > 0 {
          self.blank_end
        } else {
          self.pending.length()
        }
        out.append(self.pending[:split])
        out.push(b'\n')
        self.pending = self.pending[split:].to_owned()
        self.blank_end = 0
        self.column = 0
        if !self.pending.is_empty() {
          let rest = Bytes::from_array(self.pending)
          for i = 0; i < rest.length(); {
            let (buffered, len) = self.profile.next(rest[:], i)
            self.column = self.advance(buffered, len)
            continue i + len
          }
        }
      }
    },
    eof~,
  )
  Bytes::from_array(out)
}

///|
async fn fold_stream(reader : &@io.BinaryReader, state : FoldState) -> Unit {
  let chunks = @stream.ChunkReader::new(reader)
  while chunks.read() is Some(chunk) {
    @stdio.stdout.write(state.feed(chunk))
  }
  @stdio.stdout.write(state.feed(b"", eof=true))
  @stdio.stdout.write(Bytes::from_array(state.pending))
}
