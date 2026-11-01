///|
pub let chunk_size : Int32 = 65536

///|
pub async fn read_chunk(reader : &@io.Reader) -> Bytes? {
  reader.read_some(max_len=chunk_size)
}

///|
pub(all) struct Line {
  data : Bytes
  terminated : Bool
} derive(Eq, Debug)

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
    records: RecordReader::with_read_size(reader, delimiter, chunk_size),
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
