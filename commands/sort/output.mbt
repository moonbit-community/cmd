///|
priv struct SortedOutput {
  writer : @stream.BlockWriter
  delimiter : Byte
  unique : Bool
  specs : Array[KeySpec]
  global : Modifiers
  mut previous : Entry?
}

///|
fn SortedOutput::remember(self : SortedOutput, entry : Entry) -> Unit {
  if self.unique {
    self.previous = Some({
      record: b"",
      keys: if entry.keys.is_empty() {
        [entry.record]
      } else {
        entry.keys
      },
      index: entry.index,
    })
  }
}

///|
fn SortedOutput::buffer(
  self : SortedOutput,
  entry : Entry,
) -> FixedArray[Byte]? raise {
  if self.previous is Some(old) &&
    self.unique &&
    compare_entries(old, entry, self.specs, self.global, false) == 0 {
    return None
  }
  let record = FixedArray::make(entry.record.length() + 1, self.delimiter)
  record.blit_from_bytesview(0, entry.record[:])
  if self.writer.try_write_slice(record, 0, record.length()) {
    self.remember(entry)
    None
  } else {
    Some(record)
  }
}

///|
async fn SortedOutput::emit(self : SortedOutput, entry : Entry) -> Unit {
  if self.buffer(entry) is Some(record) {
    self.writer.write_slice(record, 0, record.length())
    self.remember(entry)
  }
}

///|
fn SortedOutput::buffer_entries(
  self : SortedOutput,
  entries : ArrayView[Entry],
  start : Int32,
) -> (Int32, FixedArray[Byte])? raise {
  for index in start..<entries.length() {
    if self.buffer(entries[index]) is Some(record) {
      return Some((index, record))
    }
  }
  None
}

///|
async fn SortedOutput::emit_entries(
  self : SortedOutput,
  entries : ArrayView[Entry],
) -> Unit {
  let mut start = 0
  while self.buffer_entries(entries, start) is Some((index, record)) {
    self.writer.write_slice(record, 0, record.length())
    self.remember(entries[index])
    start = index + 1
  }
}
