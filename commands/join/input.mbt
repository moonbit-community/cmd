///|
// Strategy: join-record-output

///|
priv struct Input {
  records : @stream.RecordReader
  mut batch : @stream.RecordBatch?
}

///|
fn Input::new(reader : &@io.Reader, delimiter : Byte) -> Input {
  { records: @stream.RecordReader::new(reader, delimiter~), batch: None, }
}

///|
// Only a physical input read may block a producer. Flush completed output
// before that boundary, while consuming already buffered records directly.
async fn Input::next(
  self : Input,
  output : @stream.BlockWriter,
) -> @stream.Line? {
  for ;; {
    if self.batch is Some(batch) && batch.next() is Some(record) {
      return Some({
        data: record.data.to_owned(),
        terminated: record.terminated,
      })
    }
    output.flush()
    self.batch = self.records.next_batch()
    if self.batch is None {
      return None
    }
  }
}
