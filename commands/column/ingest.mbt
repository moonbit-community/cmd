///|
priv struct SpoolBatch {
  data : @buffer.Buffer
  index : @buffer.Buffer
  mut deferred : Bytes?
}

///|
fn SpoolBatch::new() -> SpoolBatch {
  {
    data: @buffer.Buffer(size_hint=65536),
    index: @buffer.Buffer(size_hint=65536),
    deferred: None,
  }
}

///|
// Each buffer is bounded independently. A record that does not fit is retained
// once as the current encoded record, then written without growing the batch.
fn Snapshot::stage_record(
  self : Snapshot,
  pending : SpoolBatch,
  line : String,
) -> Bool raise {
  let bytes = @utf8.encode(line)
  if self.records == 576460752303423487L ||
    self.size > 9223372036854775807L - bytes.length().to_int64() {
    raise LayoutError("temporary snapshot exceeds 64-bit offsets")
  }
  pending.index.write_int64_le(self.size)
  pending.index.write_int64_le(bytes.length().to_int64())
  if bytes.length() <= 65536 - pending.data.length() {
    pending.data.write_bytes(bytes)
  } else {
    pending.deferred = Some(bytes)
  }
  self.records += 1
  self.size += bytes.length().to_int64()
  if self.table {
    self.observe_table_fields(bytes[:])
  } else {
    self.longest = self.longest.max(display_width(line))
  }
  pending.deferred is None &&
  pending.data.length() < 65536 &&
  pending.index.length() < 65536
}

///|
fn Snapshot::stage_records(
  self : Snapshot,
  records : @stream.RecordBatch,
  pending : SpoolBatch,
) -> Bool raise {
  while records.next() is Some(record) {
    if input_line(record.data) is Some(line) &&
      !self.stage_record(pending, line) {
      return false
    }
  }
  true
}

///|
async fn SpoolBatch::flush(
  self : SpoolBatch,
  data : &@io.Writer,
  index : &@io.Writer,
) -> Unit {
  @stream.flush_buffer(data, self.data)
  if self.deferred is Some(bytes) {
    self.deferred = None
    data.write(bytes)
  }
  @stream.flush_buffer(index, self.index)
}
