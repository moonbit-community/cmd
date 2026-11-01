///|
// Strategy: nl-record-output
priv struct Numbering {
  header_style : String
  body_style : String
  footer_style : String
  width : Int32
  separator : String
  number : Ref[Int32]
  starting_number : Int32
  increment : Int32
  number_format : String
  join_blank_lines : Int32
  no_renumber : Bool
  section : Ref[Int32]
  blank_run : Ref[Int32]
  markers : Array[Bytes]
  mut blank_prefix : Bytes?
}

///|
fn Numbering::record(
  self : Numbering,
  data : BytesView,
) -> (FixedArray[Byte], Bool) {
  if !self.markers[2].is_empty() {
    for index, marker in self.markers {
      if data.equal(marker[:]) {
        self.section.val = index
        self.blank_run.val = 0
        if !self.no_renumber {
          self.number.val = self.starting_number
        }
        return (FixedArray::make(1, b'\n'), false)
      }
    }
  }
  let style = match self.section.val {
    0 => self.header_style
    2 => self.footer_style
    _ => self.body_style
  }
  let numbered = if data.is_empty() {
    self.blank_run.val += 1
    if style == "a" && self.blank_run.val == self.join_blank_lines {
      self.blank_run.val = 0
      true
    } else {
      false
    }
  } else {
    self.blank_run.val = 0
    style == "a" || style == "t"
  }
  let prefix = if numbered {
    @utf8.encode(
      format_number(self.number.val, self.width, self.number_format) +
      self.separator,
    )
  } else {
    match self.blank_prefix {
      Some(prefix) => prefix
      None => {
        let prefix = @utf8.encode(
          spaces(self.width + @utf8.encode(self.separator).length()),
        )
        self.blank_prefix = Some(prefix)
        prefix
      }
    }
  }
  let record = FixedArray::make(prefix.length() + data.length() + 1, b'\n')
  record.blit_from_bytesview(0, prefix[:])
  record.blit_from_bytesview(prefix.length(), data)
  (record, numbered)
}

///|
// A declined admission owns the complete record; its number advances only
// after the caller finishes the asynchronous write successfully.
fn Numbering::buffer_batch(
  self : Numbering,
  batch : @stream.RecordBatch,
  output : @stream.BlockWriter,
) -> (FixedArray[Byte], Bool)? raise {
  while batch.next() is Some(line) {
    let (record, numbered) = self.record(line.data)
    if !output.try_write_slice(record, 0, record.length()) {
      return Some((record, numbered))
    }
    if numbered {
      self.number.val += self.increment
    }
  }
  None
}
