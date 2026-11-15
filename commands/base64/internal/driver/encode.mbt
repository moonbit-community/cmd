///|
// Strategy: base64-byte-encoding
priv struct Base64Encoder {
  wrap : Int32
  mut column : Int32
  mut pending : Int32
  mut count : Int32
}

///|
fn Base64Encoder::new(wrap : Int32) -> Base64Encoder {
  { wrap, column: 0, pending: 0, count: 0, }
}

///|
let encode_alphabet : Bytes = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

///|
fn encode_word(word : Int32, output : FixedArray[Byte], offset : Int32) -> Unit {
  output[offset] = encode_alphabet[(word >> 18) & 63]
  output[offset + 1] = encode_alphabet[(word >> 12) & 63]
  output[offset + 2] = encode_alphabet[(word >> 6) & 63]
  output[offset + 3] = encode_alphabet[word & 63]
}

///|
fn Base64Encoder::wrapped(
  self : Base64Encoder,
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
  output.unsafe_reinterpret_as_bytes()
}

///|
fn Base64Encoder::encode(self : Base64Encoder, input : BytesView) -> Bytes {
  let output = FixedArray::make((input.length() + self.count) / 3 * 4, b'=')
  let mut index = 0
  let mut target = 0
  if self.count != 0 {
    while self.count < 3 && index < input.length() {
      self.pending = (self.pending << 8) | input[index].to_int()
      self.count += 1
      index += 1
    }
    if self.count == 3 {
      encode_word(self.pending, output, 0)
      self.pending = 0
      self.count = 0
      target = 4
    }
  }
  while index + 2 < input.length() {
    let word = (input[index].to_int() << 16) |
      (input[index + 1].to_int() << 8) |
      input[index + 2].to_int()
    encode_word(word, output, target)
    index += 3
    target += 4
  }
  while index < input.length() {
    self.pending = (self.pending << 8) | input[index].to_int()
    self.count += 1
    index += 1
  }
  self.wrapped(output)
}

///|
fn Base64Encoder::finish(self : Base64Encoder) -> Bytes {
  let output = FixedArray::make(if self.count == 0 { 0 } else { 4 }, b'=')
  if self.count != 0 {
    let word = self.pending << ((3 - self.count) * 8)
    output[0] = encode_alphabet[(word >> 18) & 63]
    output[1] = encode_alphabet[(word >> 12) & 63]
    if self.count == 2 {
      output[2] = encode_alphabet[(word >> 6) & 63]
    }
  }
  self.pending = 0
  self.count = 0
  self.wrapped(output, ending=true)
}
