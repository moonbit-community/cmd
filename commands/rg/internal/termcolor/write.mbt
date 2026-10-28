///|
/// A byte sink, analogous to Rust's `std::io::Write` (with `write_all`
/// semantics: implementations must write every byte or raise).
///
/// Only `write_slice` is required. Writers backed by the OS (e.g. stdout)
/// are expected to be provided by the CLI layer by implementing this trait.
pub(open) trait Write {
  /// Writes all of `buf[start:end]`.
  async fn write_slice(Self, FixedArray[Byte], Int32, Int32) -> Unit
  /// Writes all of the given bytes.
  async fn write_bytes(Self, BytesView) -> Unit = _
  /// Flushes any buffered data.
  async fn flush(Self) -> Unit = _
}

///|
impl Write with fn write_bytes(self, bytes) {
  let n = bytes.length()
  if n == 0 {
    return
  }
  let tmp = FixedArray::make(n, b'\x00')
  for i in 0..<n {
    tmp[i] = bytes[i]
  }
  self.write_slice(tmp, 0, n)
}

///|
impl Write with fn flush(_self) {
  ()
}

///|
/// A writer that supports colors (and, optionally, hyperlinks). This
/// mirrors termcolor's `WriteColor` trait.
pub(open) trait WriteColor: Write {
  /// Returns true if and only if the underlying writer supports colors.
  fn supports_color(Self) -> Bool
  /// Set the color settings of the writer.
  async fn set_color(Self, ColorSpec) -> Unit
  /// Reset the current color settings to their original settings.
  async fn reset(Self) -> Unit
  /// Returns true if and only if the underlying writer must synchronously
  /// interact with an end user's device in order to control colors.
  fn is_synchronous(Self) -> Bool = _
  /// Set the current hyperlink of the writer.
  async fn set_hyperlink(Self, HyperlinkSpec) -> Unit = _
  /// Returns true if and only if the underlying writer supports hyperlinks.
  fn supports_hyperlinks(Self) -> Bool = _
}

///|
impl WriteColor with fn is_synchronous(_self) {
  false
}

///|
impl WriteColor with fn set_hyperlink(_self, _link) {
  ()
}

///|
impl WriteColor with fn supports_hyperlinks(_self) {
  false
}

///|
/// A growable in-memory byte vector. This is the analogue of Rust's
/// `Vec<u8>` used as an `io::Write` implementation.
pub struct ByteVec {
  priv mut data : FixedArray[Byte]
  priv mut len : Int32
}

///|
pub fn ByteVec::new(capacity~ : Int32 = 64) -> ByteVec {
  {
    data: FixedArray::make(if capacity < 1 { 1 } else { capacity }, 0),
    len: 0,
  }
}

///|
fn ByteVec::reserve(self : ByteVec, additional : Int32) -> Unit {
  let need = self.len + additional
  if need <= self.data.length() {
    return
  }
  let mut cap = self.data.length() * 2
  if cap < need {
    cap = need
  }
  let data = FixedArray::make(cap, b'\x00')
  self.data.blit_to(data, len=self.len)
  self.data = data
}

///|
/// Appends a single byte.
pub fn ByteVec::push(self : ByteVec, b : Byte) -> Unit {
  self.reserve(1)
  self.data[self.len] = b
  self.len += 1
}

///|
/// Appends `buf[start:end]`.
pub fn ByteVec::extend_slice(
  self : ByteVec,
  buf : FixedArray[Byte],
  start : Int32,
  end : Int32,
) -> Unit {
  let n = end - start
  if n <= 0 {
    return
  }
  self.reserve(n)
  buf.blit_to(self.data, len=n, src_offset=start, dst_offset=self.len)
  self.len += n
}

///|
/// Appends the given bytes.
pub fn ByteVec::extend_bytes(self : ByteVec, bytes : BytesView) -> Unit {
  let n = bytes.length()
  self.reserve(n)
  for i in 0..<n {
    self.data[self.len + i] = bytes[i]
  }
  self.len += n
}

///|
/// Appends the UTF-8 encoding of the given string.
pub fn ByteVec::extend_string(self : ByteVec, s : StringView) -> Unit {
  for c in s {
    let c = c.to_int()
    if c < 0x80 {
      self.push(c.to_byte())
    } else if c < 0x800 {
      self.push((0xC0 | (c >> 6)).to_byte())
      self.push((0x80 | (c & 0x3F)).to_byte())
    } else if c < 0x10000 {
      self.push((0xE0 | (c >> 12)).to_byte())
      self.push((0x80 | ((c >> 6) & 0x3F)).to_byte())
      self.push((0x80 | (c & 0x3F)).to_byte())
    } else {
      self.push((0xF0 | (c >> 18)).to_byte())
      self.push((0x80 | ((c >> 12) & 0x3F)).to_byte())
      self.push((0x80 | ((c >> 6) & 0x3F)).to_byte())
      self.push((0x80 | (c & 0x3F)).to_byte())
    }
  }
}

///|
pub fn ByteVec::length(self : ByteVec) -> Int32 {
  self.len
}

///|
pub fn ByteVec::clear(self : ByteVec) -> Unit {
  self.len = 0
}

///|
/// Returns the underlying storage. Only the first `length()` bytes are
/// meaningful.
pub fn ByteVec::storage(self : ByteVec) -> FixedArray[Byte] {
  self.data
}

///|
/// Returns a copy of the contents as `Bytes`.
pub fn ByteVec::to_bytes(self : ByteVec) -> Bytes {
  Bytes::makei(self.len, i => self.data[i])
}

///|
/// Returns a copy of `self[start:end]` as `Bytes`.
pub fn ByteVec::slice_to_bytes(
  self : ByteVec,
  start : Int32,
  end : Int32,
) -> Bytes {
  Bytes::makei(end - start, i => self.data[start + i])
}

///|
pub impl Write for ByteVec with fn write_slice(self, buf, start, end) {
  self.extend_slice(buf, start, end)
}

///|
pub impl Write for ByteVec with fn write_bytes(self, bytes) {
  self.extend_bytes(bytes)
}
