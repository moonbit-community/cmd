///|
// One cursor spans the envelope and DEFLATE stream. Alignment discards only
// partial-byte padding; complete prefetched bytes can belong to the trailer.
priv struct Bits {
  reader : &@io.Reader
  buffer : FixedArray[Byte]
  mut position : Int32
  mut end : Int32
  mut eof : Bool
  mut pending : UInt32
  mut available : Int32
}

///|
fn Bits::new(reader : &@io.Reader) -> Bits {
  {
    reader,
    buffer: FixedArray::make(65536, b'\x00'),
    position: 0,
    end: 0,
    eof: false,
    pending: 0U,
    available: 0,
  }
}

///|
async fn Bits::refill(self : Bits) -> Bool {
  if self.position < self.end {
    return true
  }
  if self.eof {
    return false
  }
  self.end = self.reader.read(self.buffer)
  self.position = 0
  self.eof = self.end == 0
  !self.eof
}

///|
async fn Bits::fill_byte(self : Bits) -> Bool {
  if !self.refill() {
    return false
  }
  self.pending = self.pending |
    (self.buffer[self.position].to_uint() << self.available)
  self.position += 1
  self.available += 8
  true
}

///|
fn Bits::peek(self : Bits, count : Int32) -> Int32 {
  (self.pending & ((1U << count) - 1U)).reinterpret_as_int()
}

///|
fn Bits::drop_bits(self : Bits, count : Int32) -> Unit {
  self.pending = self.pending >> count
  self.available -= count
}

///|
async fn Bits::take(self : Bits, count : Int32) -> Int32 {
  while self.available < count {
    guard self.fill_byte() else { fail("unexpected end of file") }
  }
  let value = self.peek(count)
  self.drop_bits(count)
  value
}

///|
fn Bits::align(self : Bits) -> Unit {
  self.drop_bits(self.available & 7)
}

///|
async fn Bits::next_byte(self : Bits) -> Byte? {
  if self.available == 0 && !self.fill_byte() {
    return None
  }
  let byte = self.peek(8).to_byte()
  self.drop_bits(8)
  Some(byte)
}

///|
async fn Bits::uint32_le(self : Bits) -> UInt32 {
  let a = self.take(8).reinterpret_as_uint()
  let b = self.take(8).reinterpret_as_uint()
  let c = self.take(8).reinterpret_as_uint()
  let d = self.take(8).reinterpret_as_uint()
  a | (b << 8) | (c << 16) | (d << 24)
}
