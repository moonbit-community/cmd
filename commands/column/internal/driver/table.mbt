///|
const TABLE_BATCH_SIZE : Int32 = 65536

///|
priv enum TableBatch {
  Full
  MissingPage(Int64)
  Finished
}

///|
priv struct TableRenderer {
  snapshot : Snapshot
  separator : Bytes
  mut record : Int64
  mut row : @layout.Row?
}

///|
fn TableRenderer::fill(
  self : TableRenderer,
  output : @buffer.Buffer,
) -> TableBatch {
  while output.length() < TABLE_BATCH_SIZE {
    match self.row {
      Some(row) => {
        if !row.fill(output, limit=TABLE_BATCH_SIZE) {
          return Full
        }
        self.record += 1
        self.row = None
      }
      None => {
        if self.record == self.snapshot.records {
          return Finished
        }
        guard self.snapshot.cached_record_bytes(self.record) is Some(data) else {
          return MissingPage(self.record)
        }
        self.row = Some(
          self.snapshot.table_row(
            data,
            self.separator,
            if data.length() >= 1024 {
              self.snapshot.field_plans.get(self.record)
            } else {
              None
            },
          ),
        )
      }
    }
  }
  Full
}

///|
async fn Snapshot::render_table(
  self : Snapshot,
  output : &@io.Writer,
  output_separator : String,
) -> Unit {
  let renderer : TableRenderer = {
    snapshot: self,
    separator: @utf8.encode(output_separator),
    record: 0L,
    row: None,
  }
  let batch = @buffer.Buffer(size_hint=TABLE_BATCH_SIZE)
  for ;; {
    match renderer.fill(batch) {
      MissingPage(record) =>
        renderer.row = Some(
          self.table_row(
            self.record_bytes(record),
            renderer.separator,
            self.field_plans.get(record),
          ),
        )
      Full => {
        let bytes = batch.to_bytes()
        batch.reset()
        output.write(bytes)
      }
      Finished => {
        if !batch.is_empty() {
          output.write(batch.to_bytes())
        }
        break
      }
    }
  }
}
