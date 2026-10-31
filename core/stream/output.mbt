///|
// Strategy: bounded-output

///|
/// Bounded output storage. Writes borrow private storage until completion.
/// Failure consumes the queued prefix and prevents deferred cleanup from
/// replaying bytes already accepted by the destination.
struct BlockWriter {
  writer : &@io.Writer
  buffer : FixedArray[Byte]
  mut length : Int32
  line_buffered : Bool
  mut active : Bool
  mut failed : Bool
}

///|
pub fn BlockWriter::new(
  writer : &@io.Writer,
  size~ : Int32 = 65536,
  line_buffered~ : Bool = false,
) -> BlockWriter {
  {
    writer,
    buffer: FixedArray::make(size.max(1), b'\x00'),
    length: 0,
    line_buffered,
    active: false,
    failed: false,
  }
}

///|
#inline
fn BlockWriter::check_ready(self : BlockWriter) -> Unit raise {
  if self.failed {
    fail("output buffer has failed")
  }
  if self.active {
    fail("output buffer is already writing")
  }
}

///|
// Only the I/O boundary needs in-flight state and cancellation cleanup.
// Filling private storage is synchronous and cannot suspend.
async fn BlockWriter::write_block(
  self : BlockWriter,
  bytes : BytesView,
) -> Unit {
  self.active = true
  defer {
    self.active = false
  }
  errdefer {
    self.failed = true
    self.length = 0
  }
  self.writer.write(bytes)
}

///|
async fn BlockWriter::drain(self : BlockWriter) -> Unit {
  if self.length > 0 {
    let length = self.length
    self.length = 0
    self.write_block(self.buffer.unsafe_reinterpret_as_bytes()[:length])
  }
}

///|
/// The caller must not mutate the input span until this call returns.
#inline
async fn BlockWriter::write_slice_slow(
  self : BlockWriter,
  data : FixedArray[Byte],
  start : Int32,
  end : Int32,
) -> Unit {
  guard start >= 0 && start <= end && end <= data.length() else {
    fail("invalid output span")
  }
  self.check_ready()
  let length = end - start
  if length >= self.buffer.length() {
    self.drain()
    self.write_block(data.unsafe_reinterpret_as_bytes()[start:end])
    return
  }
  if length > self.buffer.length() - self.length {
    self.drain()
  }
  self.append_slice(data, start, length)
  if self.line_buffered && @bytesearch.memchr(b'\n', data, start, end) >= 0 {
    self.drain()
  }
}

///|
#inline
async fn BlockWriter::write_bytes_slow(
  self : BlockWriter,
  bytes : BytesView,
) -> Unit {
  self.check_ready()
  let length = bytes.length()
  if length == 1 && self.length < self.buffer.length() {
    self.buffer[self.length] = bytes[0]
    self.length += 1
    if self.line_buffered && bytes[0] == b'\n' {
      self.drain()
    }
    return
  }
  if length >= self.buffer.length() {
    self.drain()
    self.write_block(bytes)
    return
  }
  if length > self.buffer.length() - self.length {
    self.drain()
  }
  self.append_bytes(bytes)
  if self.line_buffered && bytes.find(b"\n") is Some(_) {
    self.drain()
  }
}

///|
pub async fn BlockWriter::flush(self : BlockWriter) -> Unit {
  if self.failed {
    return
  }
  self.check_ready()
  self.drain()
}

///|
pub impl @io.Writer for BlockWriter with fn write_once(
  self,
  bytes,
  offset~,
  len~,
) {
  self.write_bytes(bytes[offset:offset + len])
  len
}

///|
pub extend BlockWriter with @io.Writer::{write_once, write, write_reader}

///|
/// Accept a complete span without I/O. False leaves the buffer unchanged;
/// the caller may then use the ordinary async write. Failed or active writers
/// reject the operation before touching either buffer.
pub fn BlockWriter::try_write_slice(
  self : BlockWriter,
  data : FixedArray[Byte],
  start : Int32,
  end : Int32,
) -> Bool raise {
  guard start >= 0 && start <= end && end <= data.length() else {
    fail("invalid output span")
  }
  self.check_ready()
  let length = end - start
  if self.line_buffered ||
    length >= self.buffer.length() ||
    length > self.buffer.length() - self.length {
    return false
  }
  self.append_slice(data, start, length)
  true
}

///|
pub async fn BlockWriter::write_slice(
  self : BlockWriter,
  data : FixedArray[Byte],
  start : Int32,
  end : Int32,
) -> Unit {
  if !self.try_write_slice(data, start, end) {
    self.write_slice_slow(data, start, end)
  }
}

///|
fn BlockWriter::buffer_bytes(
  self : BlockWriter,
  bytes : BytesView,
) -> Bool raise {
  self.check_ready()
  let length = bytes.length()
  if self.line_buffered ||
    length >= self.buffer.length() ||
    length > self.buffer.length() - self.length {
    return false
  }
  self.append_bytes(bytes)
  true
}

///|
pub async fn BlockWriter::write_bytes(
  self : BlockWriter,
  bytes : BytesView,
) -> Unit {
  if !self.buffer_bytes(bytes) {
    self.write_bytes_slow(bytes)
  }
}

///|
fn BlockWriter::append_slice(
  self : BlockWriter,
  data : FixedArray[Byte],
  start : Int32,
  length : Int32,
) -> Unit {
  if length <= 16 {
    for index in 0..<length {
      self.buffer[self.length + index] = data[start + index]
    }
  } else {
    data.blit_to(
      self.buffer,
      len=length,
      src_offset=start,
      dst_offset=self.length,
    )
  }
  self.length += length
}

///|
fn BlockWriter::append_bytes(self : BlockWriter, bytes : BytesView) -> Unit {
  let length = bytes.length()
  if length <= 16 {
    for index in 0..<length {
      self.buffer[self.length + index] = bytes[index]
    }
  } else {
    self.buffer.blit_from_bytesview(self.length, bytes)
  }
  self.length += length
}
