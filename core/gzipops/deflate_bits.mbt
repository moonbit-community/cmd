///|
priv struct DeflateBits {
  bytes : @buffer.Buffer
  mut pending : UInt32
  mut count : Int32
}

///|
fn DeflateBits::new() -> DeflateBits {
  { bytes: @buffer.Buffer(), pending: 0U, count: 0, }
}

///|
// Callers supply at most 16 bits, already restricted to the requested width.
fn DeflateBits::put(self : DeflateBits, value : UInt32, width : Int32) -> Unit {
  self.pending = self.pending | (value << self.count)
  self.count += width
  while self.count >= 8 {
    self.bytes.write_byte(self.pending.to_byte())
    self.pending = self.pending >> 8
    self.count -= 8
  }
}

///|
fn DeflateBits::align(self : DeflateBits) -> Unit {
  if self.count > 0 {
    self.bytes.write_byte(self.pending.to_byte())
    self.pending = 0U
    self.count = 0
  }
}

///|
// Complete bytes can be streamed while a partial byte spans compressed blocks.
fn DeflateBits::drain(self : DeflateBits) -> Bytes {
  let result = self.bytes.to_bytes()
  self.bytes.reset()
  result
}

///|
fn DeflateBits::stored(
  self : DeflateBits,
  input : BytesView,
  finish~ : Bool,
) -> Unit {
  let mut offset = 0
  for ;; {
    let count = (input.length() - offset).min(65535)
    let last = offset + count == input.length()
    self.put(if finish && last { 1U } else { 0U }, 3)
    self.align()
    self.put(count.reinterpret_as_uint(), 16)
    self.put((count ^ 0xffff).reinterpret_as_uint(), 16)
    self.bytes.write_bytes(input[offset:offset + count])
    offset += count
    if last {
      break
    }
  }
}

///|
fn deflate_stored_bits(count : Int32, pending_bits : Int32) -> Int32 {
  let first = count.min(65535)
  let padding = (8 - (pending_bits + 3) % 8) % 8
  3 +
  padding +
  32 +
  first * 8 +
  (if count > 65535 { 40 + (count - first) * 8 } else { 0 })
}

///|
fn deflate_length_symbol(length : Int32) -> Int32 {
  let mut index = 28
  while length < length_base[index] {
    index -= 1
  }
  index + 257
}

///|
fn deflate_distance_symbol(distance : Int32) -> Int32 {
  let mut index = 29
  while distance < distance_base[index] {
    index -= 1
  }
  index
}
