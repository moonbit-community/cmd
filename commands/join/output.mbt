///|
// Strategy: join-record-output

///|
priv struct JoinInput {
  records : @stream.RecordReader
  mut batch : @stream.RecordBatch?
}

///|
fn JoinInput::new(reader : &@io.Reader, delimiter : Byte) -> JoinInput {
  { records: @stream.RecordReader::new(reader, delimiter~), batch: None, }
}

///|
// Only a physical input read may block a producer. Flush completed output
// before that boundary, while consuming already buffered records directly.
async fn next_join_record(
  scanner : JoinInput,
  output : @stream.BlockWriter,
) -> @stream.Line? {
  for ;; {
    if scanner.batch is Some(batch) && batch.next() is Some(record) {
      return Some({
        data: record.data.to_owned(),
        terminated: record.terminated,
      })
    }
    output.flush()
    scanner.batch = scanner.records.next_batch()
    if scanner.batch is None {
      return None
    }
  }
}
