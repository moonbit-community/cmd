///|
struct DumpState {
  formats : Array[Format]
  base : Int
  width : Int
  big : Bool
  verbose : Bool
  pending : Array[Byte]
  mut skip : Int64
  mut remaining : Int64?
  mut offset : Int64
  mut previous : Bytes?
  mut squeezed : Bool
}

///|
fn DumpState::row(self : DumpState) -> String {
  let data = Bytes::from_array(self.pending)
  self.pending.clear()
  let out = if !self.verbose &&
    data.length() == self.width &&
    self.previous == Some(data) {
    if self.squeezed {
      ""
    } else {
      self.squeezed = true
      "*\n"
    }
  } else {
    self.squeezed = false
    render_row(data, self.offset, self.width, self.formats, self.base, self.big)
  }
  self.previous = Some(data)
  self.offset += data.length().to_int64()
  out
}

///|
fn DumpState::feed(self : DumpState, chunk : Bytes) -> String {
  let out = StringBuilder()
  for byte in chunk {
    if self.skip > 0L {
      self.skip -= 1L
      self.offset += 1L
      continue
    }
    if self.remaining == Some(0L) {
      break
    }
    self.pending.push(byte)
    if self.remaining is Some(n) {
      self.remaining = Some(n - 1L)
    }
    if self.pending.length() == self.width {
      out.write_string(self.row())
    }
  }
  out.to_string()
}

///|
async fn DumpState::read(self : DumpState, reader : &@io.Reader) -> Unit {
  let buffer : FixedArray[Byte] = FixedArray::make(65536, 0)
  while self.skip > 0L || self.remaining != Some(0L) {
    let maximum = match self.remaining {
      Some(n) => self.skip.min(65536L) + n.min(65536L)
      None => 65536L
    }
    let count = reader.read(buffer, max_len=maximum.min(65536L).to_int())
    if count == 0 {
      break
    }
    @stdio.stdout.write(self.feed(Bytes::from_array(buffer[:count].to_owned())))
  }
}

///|
fn parse_count(text : String) -> Int64 raise OdError {
  if text == "" || text.has_prefix("-") {
    raise OdError("invalid byte count '\{text}'")
  }
  let mut digits = text
  let mut multiplier = 1L
  if text.has_suffix("b") {
    digits = text[:text.length() - 1].to_owned()
    multiplier = 512L
  } else if text.has_suffix("K") {
    digits = text[:text.length() - 1].to_owned()
    multiplier = 1024L
  } else if text.has_suffix("M") {
    digits = text[:text.length() - 1].to_owned()
    multiplier = 1048576L
  } else if text.has_suffix("G") {
    digits = text[:text.length() - 1].to_owned()
    multiplier = 1073741824L
  }
  let radix = if digits.has_prefix("0x") || digits.has_prefix("0X") {
    16
  } else if digits.length() > 1 && digits[0] == '0' {
    8
  } else {
    10
  }
  if radix == 16 {
    digits = digits[2:].to_owned()
  }
  let value = @string.parse_int64(digits, base=radix) catch {
    _ => raise OdError("invalid byte count '\{text}'")
  }
  if value < 0L || value > 9223372036854775807L / multiplier {
    raise OdError("byte count out of range")
  }
  value * multiplier
}
