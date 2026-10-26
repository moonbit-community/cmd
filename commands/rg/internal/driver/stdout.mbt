///|
/// A buffered writer to a file descriptor (stdout), implementing termcolor's
/// `Write`. Like grep-cli's `StandardStream`, it is either line buffered
/// (flushes after every newline) or block buffered.
pub struct StdoutWriter {
  priv fd : Int32
  priv buf : FixedArray[Byte]
  priv mut len : Int32
  priv line_buffered : Bool
}

///|
pub fn StdoutWriter::new(fd : Int32, line_buffered : Bool) -> StdoutWriter {
  { fd, buf: FixedArray::make(8192, b'\x00'), len: 0, line_buffered, }
}

///|
async fn StdoutWriter::flush_buf(self : StdoutWriter) -> Unit {
  if self.len > 0 {
    let n = self.len
    self.len = 0
    @sys.write_fd(self.fd, self.buf, 0, n)
  }
}

///|
pub impl @termcolor.Write for StdoutWriter with fn write_slice(
  self,
  data,
  start,
  end,
) {
  let len = end - start
  if len >= self.buf.length() {
    self.flush_buf()
    @sys.write_fd(self.fd, data, start, len)
    return
  }
  if self.len + len > self.buf.length() {
    self.flush_buf()
  }
  if len <= 16 {
    // Tiny writes (separators, line numbers) are common: copying them
    // directly is cheaper than a `memmove` call.
    let buf = self.buf
    let at = self.len
    for i in 0..<len {
      buf[at + i] = data[start + i]
    }
  } else {
    data.blit_to(self.buf, len~, src_offset=start, dst_offset=self.len)
  }
  self.len += len
  if self.line_buffered && @memchr.memchr(b'\n', data, start, end) >= 0 {
    self.flush_buf()
  }
}

///|
/// Copies small byte strings straight into the buffer (the default
/// implementation allocates a temporary array).
pub impl @termcolor.Write for StdoutWriter with fn write_bytes(self, bytes) {
  let len = bytes.length()
  // Fast path for single bytes (field separators, terminators).
  if len == 1 && self.len < self.buf.length() {
    self.buf[self.len] = bytes[0]
    self.len += 1
    if self.line_buffered && bytes[0] == b'\n' {
      self.flush_buf()
    }
    return
  }
  if len >= self.buf.length() {
    self.flush_buf()
    let tmp = FixedArray::makei(len, i => bytes[i])
    @sys.write_fd(self.fd, tmp, 0, len)
    return
  }
  if self.len + len > self.buf.length() {
    self.flush_buf()
  }
  let buf = self.buf
  let at = self.len
  for i in 0..<len {
    buf[at + i] = bytes[i]
  }
  self.len += len
  if self.line_buffered {
    for i in 0..<len {
      if bytes[i] == b'\n' {
        self.flush_buf()
        break
      }
    }
  }
}

///|
pub impl @termcolor.Write for StdoutWriter with fn flush(self) {
  self.flush_buf()
}
