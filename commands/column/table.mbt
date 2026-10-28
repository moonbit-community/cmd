///|
let table_batch_size : Int32 = 65536

///|
priv enum TablePhase {
  Field
  Padding
  Separator
  Newline
}

///|
// A row can expand far beyond its input length because of global widths.
// Retain only its fields and a cursor, never a complete padded output row.
priv struct TableRow {
  fields : Array[TableField]
  widths : Array[Int32]
  separator : Bytes
  mut column : Int32
  mut phase : TablePhase
  mut bytes : BytesView
  mut offset : Int32
  mut padding : Int32
}

///|
fn TableRow::from_bytes(
  snapshot : Snapshot,
  data : BytesView,
  separator : Bytes,
  plan : Bytes?,
) -> TableRow {
  let fields = match plan {
    Some(plan) => fields_from_plan(data, plan)
    None => snapshot.separator.table_fields(data)
  }
  {
    fields,
    widths: snapshot.widths,
    separator,
    column: 0,
    phase: if snapshot.widths.is_empty() {
      Newline
    } else {
      Field
    },
    bytes: fields.get(0).map(field => field.data).unwrap_or(b""[:]),
    offset: 0,
    padding: 0,
  }
}

///|
fn TableRow::fill(
  self : TableRow,
  output : @buffer.Buffer,
  limit~ : Int32 = table_batch_size,
) -> Bool {
  let spaces = b"                                                                "
  while output.length() < limit {
    let available = limit - output.length()
    match self.phase {
      Field => {
        let count = available.min(self.bytes.length() - self.offset)
        output.write_bytes(self.bytes[self.offset:self.offset + count])
        self.offset += count
        if self.offset == self.bytes.length() {
          self.offset = 0
          if self.column + 1 == self.widths.length() {
            self.phase = Newline
          } else {
            self.padding = self.widths[self.column] -
              self.fields
              .get(self.column)
              .map(field => field.width)
              .unwrap_or(0)
            self.phase = Padding
          }
        }
      }
      Padding => {
        let count = self.padding.min(available).min(spaces.length())
        output.write_bytes(spaces[:count])
        self.padding -= count
        if self.padding == 0 {
          self.phase = Separator
        }
      }
      Separator => {
        let count = available.min(self.separator.length() - self.offset)
        output.write_bytes(self.separator[self.offset:self.offset + count])
        self.offset += count
        if self.offset == self.separator.length() {
          self.column += 1
          self.bytes = self.fields
            .get(self.column)
            .map(field => field.data)
            .unwrap_or(b""[:])
          self.offset = 0
          self.phase = Field
        }
      }
      Newline => {
        output.write_byte(b'\n')
        return true
      }
    }
  }
  false
}

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
  mut row : TableRow?
}

///|
fn TableRenderer::fill(
  self : TableRenderer,
  output : @buffer.Buffer,
) -> TableBatch {
  while output.length() < table_batch_size {
    match self.row {
      Some(row) => {
        if !row.fill(output) {
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
          TableRow::from_bytes(
            self.snapshot,
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
  let batch = @buffer.Buffer(size_hint=table_batch_size)
  for ;; {
    match renderer.fill(batch) {
      MissingPage(record) =>
        renderer.row = Some(
          TableRow::from_bytes(
            self,
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
