///|
/// The default buffer capacity (64 KB).
pub const DEFAULT_BUFFER_CAPACITY : Int32 = 65536

///|
priv enum BufferAllocation {
  Eager
  ErrorLimit(Int32)
}

///|
/// How binary data is detected and handled while reading.
priv enum BinaryMode {
  BNone
  BQuit(Byte)
  BConvert(Byte)
}

///|
/// An error raised by the searcher itself.
pub suberror SearchError {
  /// A configuration error.
  ConfigError(String)
  /// A generic I/O-like error (e.g. the heap limit was exceeded).
  SearchIOError(String)
} derive(Debug)

///|
pub fn SearchError::to_string(self : SearchError) -> String {
  match self {
    ConfigError(s) => s
    SearchIOError(s) => s
  }
}

///|
pub impl Show for SearchError with fn output(self, logger) {
  logger.write_string(self.to_string())
}

///|
fn alloc_error(limit : Int32) -> SearchError {
  SearchIOError("configured allocation limit (\{limit}) exceeded")
}

///|
/// A source of bytes.
pub(open) trait Reader {
  /// Reads up to `len` bytes into `buf[start:start+len]`, returning the
  /// number of bytes read (0 at end of input).
  async fn read(Self, FixedArray[Byte], Int32, Int32) -> Int32
}

///|
/// A reader over an in-memory byte buffer.
pub struct SliceReader {
  priv buf : FixedArray[Byte]
  priv mut pos : Int32
  priv end : Int32
}

///|
fn SliceReader::new(
  buf : FixedArray[Byte],
  start : Int32,
  end : Int32,
) -> SliceReader {
  { buf, pos: start, end, }
}

///|
pub fn SliceReader::from_bytes(bytes : Bytes) -> SliceReader {
  let buf = bytes.to_fixedarray()
  { buf, pos: 0, end: buf.length(), }
}

///|
pub impl Reader for SliceReader with fn read(self, buf, start, len) {
  let n = if self.end - self.pos < len { self.end - self.pos } else { len }
  self.buf.blit_to(buf, len=n, src_offset=self.pos, dst_offset=start)
  self.pos += n
  n
}

///|
/// A buffer that reads data and exposes complete lines.
priv struct LineBuffer {
  capacity : Int32
  lineterm : Byte
  buffer_alloc : BufferAllocation
  mut binary : BinaryMode
  mut buf : FixedArray[Byte]
  mut pos : Int32
  mut last_lineterm : Int32
  mut end : Int32
  mut absolute_byte_offset : Int64
  mut binary_byte_offset : Int64?
}

///|
fn LineBuffer::new(
  capacity : Int32,
  lineterm : Byte,
  buffer_alloc : BufferAllocation,
  binary : BinaryMode,
) -> LineBuffer {
  {
    capacity,
    lineterm,
    buffer_alloc,
    binary,
    buf: FixedArray::make(capacity, b'\x00'),
    pos: 0,
    last_lineterm: 0,
    end: 0,
    absolute_byte_offset: 0,
    binary_byte_offset: None,
  }
}

///|
fn LineBuffer::clear(self : LineBuffer) -> Unit {
  self.pos = 0
  self.last_lineterm = 0
  self.end = 0
  self.absolute_byte_offset = 0
  self.binary_byte_offset = None
}

///|
fn LineBuffer::buffer_len(self : LineBuffer) -> Int32 {
  self.last_lineterm - self.pos
}

///|
fn LineBuffer::consume(self : LineBuffer, amt : Int32) -> Unit {
  guard amt <= self.buffer_len() else { abort("consume beyond buffer") }
  self.pos += amt
  self.absolute_byte_offset += amt.to_int64()
}

///|
async fn LineBuffer::fill(self : LineBuffer, rdr : &Reader) -> Bool {
  if self.binary is BQuit(_) && self.binary_byte_offset is Some(_) {
    return self.buffer_len() > 0
  }
  self.roll()
  while true {
    self.ensure_capacity()
    // Keep each read request independent of spare capacity after a long line.
    let readlen = rdr.read(
      self.buf,
      self.end,
      (self.buf.length() - self.end).min(1048576),
    )
    if readlen == 0 {
      self.last_lineterm = self.end
      return self.buffer_len() > 0
    }
    let oldend = self.end
    self.end += readlen
    match self.binary {
      BNone => ()
      BQuit(byte) =>
        if find_byte(self.buf, byte, oldend, self.end) is Some(i) {
          self.end = i
          self.last_lineterm = self.end
          self.binary_byte_offset = Some(
            self.absolute_byte_offset + self.end.to_int64(),
          )
          return self.pos < self.end
        }
      BConvert(byte) =>
        if replace_bytes(self.buf, oldend, self.end, byte, self.lineterm)
          is Some(i) {
          if self.binary_byte_offset is None {
            self.binary_byte_offset = Some(
              self.absolute_byte_offset + (oldend + i).to_int64(),
            )
          }
        }
    }
    if rfind_byte(self.buf, self.lineterm, oldend, self.end) is Some(i) {
      self.last_lineterm = i + 1
      return true
    }
  }
  false
}

///|
fn LineBuffer::roll(self : LineBuffer) -> Unit {
  if self.pos == self.end {
    self.pos = 0
    self.last_lineterm = 0
    self.end = 0
    return
  }
  let roll_len = self.end - self.pos
  self.buf.blit_to(self.buf, len=roll_len, src_offset=self.pos, dst_offset=0)
  self.pos = 0
  self.last_lineterm = roll_len
  self.end = roll_len
}

///|
fn LineBuffer::ensure_capacity(self : LineBuffer) -> Unit raise SearchError {
  if self.end < self.buf.length() {
    return
  }
  let len = if self.buf.length() < 1 { 1 } else { self.buf.length() }
  // Retain geometric growth while limiting unused space in large buffers.
  let growth = if len < 1048576 { len } else { len / 4 }
  let additional = match self.buffer_alloc {
    Eager => growth
    ErrorLimit(limit) => {
      let used = self.buf.length() - self.capacity
      let n = if growth < limit - used { growth } else { limit - used }
      if n == 0 {
        raise alloc_error(self.capacity + limit)
      }
      n
    }
  }
  let newbuf = FixedArray::make(self.buf.length() + additional, b'\x00')
  self.buf.blit_to(newbuf, len=self.end, src_offset=0, dst_offset=0)
  self.buf = newbuf
}

///|
/// Replaces all occurrences of `src` with `replacement` in
/// `buf[start:end]`, returning the offset (relative to `start`) of the
/// first replacement.
fn replace_bytes(
  buf : FixedArray[Byte],
  start : Int32,
  end : Int32,
  src : Byte,
  replacement : Byte,
) -> Int32? {
  if src == replacement {
    return None
  }
  let mut first : Int32? = None
  let mut i = @memchr.memchr(src, buf, start, end)
  while i >= 0 {
    buf[i] = replacement
    if first is None {
      first = Some(i - start)
    }
    i = @memchr.memchr(src, buf, i + 1, end)
  }
  first
}
