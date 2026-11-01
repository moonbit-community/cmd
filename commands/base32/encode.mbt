///|
// Strategy: base32-byte-encoding
priv struct Base32Encoder {
  wrap : Int32
  pending : FixedArray[Byte]
  mut count : Int32
  mut column : Int32
}

///|
fn Base32Encoder::new(wrap : Int32) -> Base32Encoder {
  { wrap, pending: FixedArray::make(5, b'\x00'), count: 0, column: 0, }
}

///|
fn Base32Encoder::wrapped(
  self : Base32Encoder,
  raw : FixedArray[Byte],
  ending~ : Bool = false,
) -> Bytes {
  if self.wrap == 0 {
    return raw.unsafe_reinterpret_as_bytes()
  }
  let total = self.column.to_int64() + raw.length().to_int64()
  let breaks = total / self.wrap.to_int64()
  let tail = if ending && total % self.wrap.to_int64() != 0 { 1 } else { 0 }
  let output = FixedArray::make(raw.length() + breaks.to_int() + tail, b'\n')
  let mut source = 0
  let mut destination = 0
  while source < raw.length() {
    let count = (self.wrap - self.column).min(raw.length() - source)
    raw.blit_to(output, src_offset=source, dst_offset=destination, len=count)
    source += count
    destination += count
    self.column += count
    if self.column == self.wrap {
      self.column = 0
      destination += 1
    }
  }
  if ending {
    self.column = 0
  }
  output.unsafe_reinterpret_as_bytes()
}

///|
// The reader bounds each call. Only the unfinished quantum survives it.
fn Base32Encoder::encode(self : Base32Encoder, input : BytesView) -> Bytes {
  let output = FixedArray::make((input.length() + self.count) / 5 * 8, b'=')
  let mut index = 0
  let mut target = 0
  if self.count != 0 {
    while self.count < 5 && index < input.length() {
      self.pending[self.count] = input[index]
      self.count += 1
      index += 1
    }
    if self.count == 5 {
      encode_groups(self.pending.unsafe_reinterpret_as_bytes()[:], output, 0)
      self.count = 0
      target = 8
    }
  }
  let complete = (input.length() - index) / 5 * 5
  encode_groups(input[index:index + complete], output, target)
  index += complete
  while index < input.length() {
    self.pending[self.count] = input[index]
    self.count += 1
    index += 1
  }
  self.wrapped(output)
}

///|
fn Base32Encoder::finish(self : Base32Encoder) -> Bytes {
  let output = FixedArray::make(if self.count == 0 { 0 } else { 8 }, b'=')
  if self.count != 0 {
    for index in self.count..<5 {
      self.pending[index] = b'\x00'
    }
    encode_groups(self.pending.unsafe_reinterpret_as_bytes()[:], output, 0)
    let symbols = (self.count * 8 + 4) / 5
    for index in symbols..<8 {
      output[index] = b'='
    }
  }
  self.count = 0
  self.wrapped(output, ending=true)
}

///|
async fn encode_stream(
  reader : &@io.Reader,
  wrap : Int32,
  writer : &@io.Writer,
) -> Unit {
  let encoder = Base32Encoder::new(wrap)
  while reader.read_some(max_len=65536) is Some(chunk) {
    let output = encoder.encode(chunk)
    if !output.is_empty() {
      writer.write(output)
    }
  }
  let output = encoder.finish()
  if !output.is_empty() {
    writer.write(output)
  }
}
