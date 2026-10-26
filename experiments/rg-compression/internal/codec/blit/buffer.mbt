///|
/// Pure MoonBit storage for the imported codecs. All copies check their bounds.
pub struct Buffer {
  priv mut storage : FixedArray[Byte]
  priv mut used : Int
}

///|
pub fn Buffer::new(size_hint? : Int = 16) -> Buffer {
  { storage: FixedArray::make(size_hint.max(1), b'\x00'), used: 0 }
}

///|
pub fn Buffer::length(self : Buffer) -> Int { self.used }

///|
pub fn Buffer::data(self : Buffer) -> FixedArray[Byte] { self.storage }

///|
pub fn Buffer::reset(self : Buffer) -> Unit { self.used = 0 }

///|
pub fn Buffer::ensure_capacity(self : Buffer, additional : Int) -> Unit {
  guard additional >= 0 && self.used <= 2147483647 - additional else {
    abort("codec buffer length overflow")
  }
  let needed = self.used + additional
  if needed <= self.storage.length() { return }
  let capacity = if self.storage.length() <= 1073741823 {
    (self.storage.length() * 2).max(needed)
  } else { needed }
  let next = FixedArray::make(capacity, b'\x00')
  self.storage.blit_to(next, len=self.used)
  self.storage = next
}

///|
pub fn Buffer::unsafe_advance(self : Buffer, count : Int) -> Unit {
  guard count >= 0 && count <= self.storage.length() - self.used else {
    abort("codec output exceeds reserved capacity")
  }
  self.used += count
}

///|
pub fn Buffer::get_byte(self : Buffer, index : Int) -> Byte {
  guard index >= 0 && index < self.used else { abort("codec history index") }
  self.storage[index]
}

///|
pub fn Buffer::write_byte(self : Buffer, byte : Byte) -> Unit {
  self.ensure_capacity(1)
  self.storage[self.used] = byte
  self.used += 1
}

///|
pub fn Buffer::write_byte_unchecked(self : Buffer, byte : Byte) -> Unit {
  self.write_byte(byte)
}

///|
pub fn Buffer::write_bytesview(self : Buffer, bytes : BytesView) -> Unit {
  self.ensure_capacity(bytes.length())
  for byte in bytes { self.storage[self.used] = byte; self.used += 1 }
}

///|
pub fn Buffer::write_bytes(self : Buffer, bytes : BytesView) -> Unit {
  self.write_bytesview(bytes)
}

///|
pub fn Buffer::write_fixed(self : Buffer, bytes : FixedArray[Byte], offset : Int, len : Int) -> Unit {
  guard offset >= 0 && len >= 0 && offset <= bytes.length() - len else {
    abort("codec copy range")
  }
  self.ensure_capacity(len)
  bytes.blit_to(self.storage, src_offset=offset, dst_offset=self.used, len~)
  self.used += len
}

///|
pub fn Buffer::copy_from_self(self : Buffer, source : Int, len : Int) -> Unit {
  guard source >= 0 && source < self.used && len >= 0 else {
    abort("codec invalid match distance")
  }
  self.ensure_capacity(len)
  for i in 0..<len {
    self.storage[self.used] = self.storage[source + i]
    self.used += 1
  }
}

///|
pub fn Buffer::to_bytes(self : Buffer) -> Bytes {
  Bytes::from_array(self.storage[:self.used])
}

///|
pub fn make_uninit(len : Int) -> FixedArray[Byte] {
  FixedArray::make(len, b'\x00')
}

///|
pub fn blit_fixed_array(dst : FixedArray[Byte], dst_offset : Int, src : FixedArray[Byte], src_offset : Int, len : Int) -> Unit {
  src.blit_to(dst, src_offset~, dst_offset~, len~)
}

///|
pub fn blit_bytes(dst : FixedArray[Byte], dst_offset : Int, src : Bytes, src_offset : Int, len : Int) -> Unit {
  guard dst_offset >= 0 && src_offset >= 0 && len >= 0 &&
    dst_offset <= dst.length() - len && src_offset <= src.length() - len else {
    abort("codec byte copy range")
  }
  for i in 0..<len { dst[dst_offset + i] = src[src_offset + i] }
}

///|
pub fn match_length_bv(bytes : BytesView, a : Int, b : Int, max_len : Int) -> Int {
  let mut count = 0
  while count < max_len && bytes[a + count] == bytes[b + count] { count += 1 }
  count
}
