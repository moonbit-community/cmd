///|
priv struct StringDump {
  minimum : Int64
  base : Int32
  label : Int64?
  pending : Array[Byte]
  mut skip : Int64
  mut remaining : Int64?
  mut offset : Int64
  mut start : Int64
}

///|
fn StringDump::done(self : StringDump) -> Bool {
  self.skip == 0L &&
  (
    self.remaining == Some(0L) ||
    (
      self.pending.is_empty() &&
      self.remaining is Some(left) &&
      left < self.minimum
    )
  )
}

///|
fn StringDump::record(self : StringDump, output : StringBuilder) -> Unit {
  if self.pending.length().to_int64() >= self.minimum {
    let prefix = labeled_address(self.start, self.base, self.label)
    if prefix != "" {
      output.write_string(prefix + " ")
    }
    for byte in self.pending {
      output.write_char(byte.to_int().unsafe_to_char())
    }
    output.write_char('\n')
  }
  self.pending.clear()
}

///|
fn StringDump::feed(self : StringDump, data : BytesView) -> String {
  let output = StringBuilder()
  for byte in data {
    if self.skip > 0L {
      self.skip -= 1
      self.offset += 1
      self.start = self.offset
      continue
    }
    if self.done() {
      break
    }
    self.offset += 1
    if self.remaining is Some(left) {
      self.remaining = Some(left - 1)
    }
    if byte == b'\x00' {
      self.record(output)
      self.start = self.offset
    } else if byte >= b' ' && byte <= b'~' {
      self.pending.push(byte)
    } else {
      self.pending.clear()
      self.start = self.offset
    }
    if self.remaining == Some(0L) && byte >= b' ' && byte <= b'~' {
      self.record(output)
    }
  }
  output.to_string()
}

///|
async fn StringDump::read(self : StringDump, reader : &@io.Reader) -> Unit {
  let buffer = FixedArray::make(65536, b'\x00')
  let data = buffer.unsafe_reinterpret_as_bytes()
  while !self.done() {
    let request = match self.remaining {
      Some(left) =>
        (self.skip.min(65536L) + left.min(65536L)).min(65536L).to_int()
      None => 65536
    }
    let count = reader.read(buffer, max_len=request)
    if count == 0 {
      break
    }
    @stdio.stdout.write(self.feed(data[:count]))
  }
}
