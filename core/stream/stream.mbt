///|
pub let chunk_size : Int32 = 65536

///|
/// Recover the underlying error for command diagnostics and exit status.
pub fn transport_cause(error : Error) -> Error {
  match error {
    @binary.ReaderError::TransportError(cause, ..)
    | @binary.WriterError::TransportError(cause, ..) => transport_cause(cause)
    _ => error
  }
}

///|
pub async fn read_chunk(reader : &@io.Reader) -> Bytes? {
  reader.read_some(max_len=chunk_size)
}

///|
/// Read bounded chunks without waiting for a full block. Each returned chunk
/// owns its bytes, including when the source produces a short read.
struct ChunkReader {
  reader : &@binary.BinaryReader
  mut buffer : FixedArray[Byte]
}

///|
pub fn ChunkReader::new(
  reader : &@binary.BinaryReader,
  size~ : Int32 = chunk_size,
) -> ChunkReader {
  { reader, buffer: FixedArray::make(size.max(1), b'\x00'), }
}

///|
pub async fn ChunkReader::read(self : ChunkReader) -> Bytes? {
  let length = self.reader.read_into(self.buffer.mut_view())
  if length == 0 {
    None
  } else if length == self.buffer.length() {
    let bytes = self.buffer.unsafe_reinterpret_as_bytes()
    self.buffer = FixedArray::make(length, b'\x00')
    Some(bytes)
  } else {
    Some(self.buffer.unsafe_reinterpret_as_bytes()[:length].to_owned())
  }
}

///|
#derive(Eq, Debug)
pub(all) struct Line {
  data : Bytes
  terminated : Bool
}

///|
pub struct LineScanner {
  records : RecordReader
  mut batch : RecordBatch?
}

///|
pub fn LineScanner::new(
  reader : &@io.Reader,
  delimiter~ : Byte = b'\n',
) -> LineScanner {
  {
    records: RecordReader::with_source(
      () => reader.read_some(max_len=chunk_size),
      delimiter,
    ),
    batch: None,
  }
}

///|
pub fn LineScanner::from_binary(
  reader : &@binary.BinaryReader,
  delimiter~ : Byte = b'\n',
) -> LineScanner {
  let chunks = ChunkReader::new(reader)
  {
    records: RecordReader::with_source(() => chunks.read(), delimiter),
    batch: None,
  }
}

///|
pub async fn LineScanner::next(self : LineScanner) -> Line? {
  for ;; {
    if self.batch is Some(batch) && batch.next() is Some(record) {
      return Some({
        data: record.data.to_owned(),
        terminated: record.terminated,
      })
    }
    self.batch = self.records.next_batch()
    if self.batch is None {
      return None
    }
  }
}

///|
pub extend Line with Eq::{not_equal, equal}

///|
pub extend Line with @debug.Debug::{to_repr}
