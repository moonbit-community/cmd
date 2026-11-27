///|
priv enum Phase {
  Field
  Padding
  Separator
  Newline
}

///|
// A row can expand far beyond its input length because of global widths.
// Retain only its fields and a cursor, never a complete padded output row.
pub struct Row {
  priv fields : Array[Field]
  priv widths : Array[Int32]
  priv separator : Bytes
  priv mut column : Int32
  priv mut phase : Phase
  priv mut bytes : BytesView
  priv mut offset : Int32
  priv mut padding : Int32
}

///|
pub fn Row::new(
  fields : Array[Field],
  widths : Array[Int32],
  separator : Bytes,
) -> Row {
  {
    fields,
    widths,
    separator,
    column: 0,
    phase: if widths.is_empty() {
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
pub fn Row::fill(self : Row, output : @buffer.Buffer, limit~ : Int32) -> Bool {
  let spaces = b"                                                                "
  while output.length() < limit {
    let available = limit - output.length()
    match self.phase {
      Field => {
        let count = available.min(self.bytes.length() - self.offset)
        output.write_bytesview(self.bytes[self.offset:self.offset + count])
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
        output.write_bytesview(spaces[:count])
        self.padding -= count
        if self.padding == 0 {
          self.phase = Separator
        }
      }
      Separator => {
        let count = available.min(self.separator.length() - self.offset)
        output.write_bytesview(self.separator[self.offset:self.offset + count])
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
