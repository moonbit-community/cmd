///|
priv struct SortInput {
  specs : Array[KeySpec]
  global : Modifiers
  separator : Byte?
  seed : Bytes
  mut sequence : Int64
  mut retained : Int64
  mut entries : Array[Entry]
}

///|
fn SortInput::entry(self : SortInput, record : BytesView) -> Entry {
  let entry = make_entry(
    record.to_owned(),
    self.sequence,
    self.specs,
    self.global,
    self.separator,
    seed=self.seed,
  )
  self.sequence += 1
  entry
}

///|
fn SortInput::admit(self : SortInput, entry : Entry) -> Unit {
  self.entries.push(entry)
  self.retained += entry_cost(entry)
}

///|
// Consume the complete in-memory batch without an asynchronous call per record.
// An entry that crosses the run budget remains owned while the old run spills.
fn SortInput::batch(
  self : SortInput,
  batch : @stream.RecordBatch,
  limit : Int64,
) -> Entry? {
  let mut pending = None
  batch.each_while((record, _) => {
    let entry = self.entry(record)
    if !self.entries.is_empty() && entry_cost(entry) > limit - self.retained {
      pending = Some(entry)
      false
    } else {
      self.admit(entry)
      true
    }
  })
  |> ignore
  pending
}
