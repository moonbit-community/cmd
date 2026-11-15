///|
// Strategy: comm-borrowed-merge

///|
priv struct CommInput {
  records : @stream.RecordReader
  mut batch : @stream.RecordBatch?
  mut current : BytesView?
  mut previous : BytesView?
  mut descending : Bool
  mut warned : Bool
  mut needed : Bool
  mut eof : Bool
}

///|
fn CommInput::new(reader : &@io.Reader, delimiter : Byte) -> CommInput {
  {
    records: @stream.RecordReader::new(reader, delimiter~),
    batch: None,
    current: None,
    previous: None,
    descending: false,
    warned: false,
    needed: true,
    eof: false,
  }
}

///|
// Views retain immutable storage across refills; only split records are copied.
fn CommInput::advance(self : CommInput) -> Bool {
  if self.batch is Some(batch) && batch.next() is Some(record) {
    self.descending = match self.previous {
      Some(old) => old.lexical_compare(record.data) > 0
      None => false
    }
    self.current = Some(record.data)
    self.previous = self.current
  } else if self.eof {
    self.current = None
    // EOF repeats the last order comparison after an unpaired record.
  } else {
    return false
  }
  self.needed = false
  true
}

///|
priv enum CommAction {
  Read(CommInput)
  Warn(CommInput, String)
  Flush
  Done
}

///|
priv struct CommMerge {
  left : CommInput
  right : CommInput
  hide1 : Bool
  hide2 : Bool
  hide3 : Bool
  order_mode : Int32
  record_delimiter : Byte
  prefix2 : Bytes
  prefix3 : Bytes
  output : @buffer.Buffer
  mut unpairable : Bool
  mut count1 : Int64
  mut count2 : Int64
  mut count3 : Int64
}

///|
fn CommMerge::pump(self : CommMerge) -> CommAction {
  for ;; {
    if self.left.needed {
      if !self.left.advance() {
        return Read(self.left)
      }
      if self.should_warn(self.left) {
        return Warn(self.left, "file 1")
      }
    }
    if self.right.needed {
      if !self.right.advance() {
        return Read(self.right)
      }
      if self.should_warn(self.right) {
        return Warn(self.right, "file 2")
      }
    }
    let (column, line) = match (self.left.current, self.right.current) {
      (Some(a), Some(b)) => {
        let order = a.lexical_compare(b)
        if order < 0 {
          (1, a)
        } else if order > 0 {
          (2, b)
        } else {
          (3, a)
        }
      }
      (Some(a), None) => (1, a)
      (None, Some(b)) => (2, b)
      (None, None) => return Done
    }
    let visible = match column {
      1 => {
        self.unpairable = true
        self.count1 += 1
        self.left.needed = true
        !self.hide1
      }
      2 => {
        self.unpairable = true
        self.count2 += 1
        self.right.needed = true
        if !self.hide2 {
          self.output.write_bytes(self.prefix2)
        }
        !self.hide2
      }
      _ => {
        self.count3 += 1
        self.left.needed = true
        self.right.needed = true
        if !self.hide3 {
          self.output.write_bytes(self.prefix3)
        }
        !self.hide3
      }
    }
    if visible {
      self.output.write_bytes(line)
      self.output.write_byte(self.record_delimiter)
      if self.output.length() >= 65536 {
        return Flush
      }
    }
  }
}

///|
fn CommMerge::should_warn(self : CommMerge, input : CommInput) -> Bool {
  !input.warned &&
  input.descending &&
  (self.order_mode > 0 || (self.order_mode == 0 && self.unpairable))
}
