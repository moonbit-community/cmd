///|
/// A record view owns a reference to immutable input storage. It remains valid
/// after the reader advances. Only records spanning reads require a copy.
pub(all) struct RecordView {
  data : BytesView
  terminated : Bool
}

///|
/// Complete records from one read, consumed synchronously with `next`.
struct RecordBatch {
  mut first : Bytes?
  data : BytesView
  delimiter : Bytes
  mut offset : Int32
  terminated : Bool
}

///|
#inline
pub fn RecordBatch::next(self : RecordBatch) -> RecordView? {
  if self.first is Some(data) {
    self.first = None
    return Some({ data: data[:], terminated: self.terminated, })
  }
  guard self.offset < self.data.length() else { return None }
  let start = self.offset
  // `data` contains only complete records and always ends in the delimiter.
  let end = start + self.data[start:].find(self.delimiter).unwrap()
  self.offset = end + 1
  Some({ data: self.data[start:end], terminated: true, })
}

///|
struct RecordReader {
  reader : &@io.Reader
  delimiter : Bytes
  pending : @buffer.Buffer
  mut eof : Bool
}

///|
pub fn RecordReader::new(
  reader : &@io.Reader,
  delimiter~ : Byte = b'\n',
) -> RecordReader {
  {
    reader,
    delimiter: Bytes::from_array([delimiter]),
    pending: @buffer.Buffer(),
    eof: false,
  }
}

///|
/// Return all complete records available in a read before requesting more input.
/// EOF emits a nonempty final fragment once. A read error leaves that fragment
/// unreported, matching `LineScanner`; previously returned views stay valid.
pub async fn RecordReader::next_batch(self : RecordReader) -> RecordBatch? {
  while !self.eof {
    guard self.reader.read_some(max_len=1048576) is Some(chunk) else {
      self.eof = true
      if self.pending.is_empty() {
        return None
      }
      let first = self.pending.to_bytes()
      self.pending.reset()
      return Some({
        first: Some(first),
        data: b""[:],
        delimiter: self.delimiter,
        offset: 0,
        terminated: false,
      })
    }
    guard chunk.rev_find(self.delimiter) is Some(last) else {
      self.pending.write_bytes(chunk)
      continue
    }
    let mut start = 0
    let first = if self.pending.is_empty() {
      None
    } else {
      let end = chunk.find(self.delimiter).unwrap()
      self.pending.write_bytes(chunk[:end])
      let data = self.pending.to_bytes()
      self.pending.reset()
      start = end + 1
      Some(data)
    }
    self.pending.write_bytes(chunk[last + 1:])
    return Some({
      first,
      data: chunk[start:last + 1],
      delimiter: self.delimiter,
      offset: 0,
      terminated: true,
    })
  }
  None
}

///|
/// Flush synchronous record output. Consume pending bytes before writing: a
/// failed or partially completed write must never be retried by deferred cleanup.
pub async fn flush_buffer(
  writer : &@io.Writer,
  buffer : @buffer.Buffer,
) -> Unit {
  if !buffer.is_empty() {
    let data = buffer.to_bytes()
    buffer.reset()
    writer.write(data)
  }
}
