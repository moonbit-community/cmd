///|
priv suberror HexdumpError {
  HexdumpError(String)
}

///|
struct DumpState {
  program : FormatProgram
  verbose : Bool
  pending : Array[Byte]
  mut skip : Int64
  mut remaining : Int64?
  mut offset : Int64
  mut previous : Bytes?
  mut squeezed : Bool
}

///|
fn DumpState::row(self : DumpState) -> Bytes {
  let data = Bytes::from_array(self.pending)
  self.pending.clear()
  let out = @buffer.Buffer()
  if !self.verbose &&
    data.length() == self.program.block_size &&
    self.previous == Some(data) {
    if !self.squeezed {
      out.write_string_utf8("*\n")
      self.squeezed = true
    }
  } else {
    self.squeezed = false
    for entry in self.program.entries {
      match entry {
        Builtin(mode) => {
          let end = if data.length() < 16 { data.length() } else { 16 }
          let displayed = data[:end].to_owned()
          out.write_string_utf8(render_row(displayed, self.offset, mode))
        }
        Custom(format) =>
          out.write_bytes(
            render_custom(format, data[:], self.offset, self.program.block_size)[:],
          )
      }
    }
  }
  self.previous = Some(data)
  self.offset += data.length().to_int64()
  out.to_bytes()
}

///|
fn DumpState::feed(self : DumpState, chunk : Bytes) -> Bytes {
  let out = @buffer.Buffer()
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
    if self.pending.length() == self.program.block_size {
      out.write_bytes(self.row()[:])
    }
  }
  out.to_bytes()
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
fn parse_count(text : String) -> Int64 raise HexdumpError {
  if text == "" || text.has_prefix("-") {
    raise HexdumpError("invalid byte count '\{text}'")
  }
  let mut digits = text
  let mut multiplier = 1L
  for
    (suffix, factor) in [
      ("KiB", 1024L),
      ("MiB", 1048576L),
      ("GiB", 1073741824L),
      ("KB", 1000L),
      ("MB", 1000000L),
      ("GB", 1000000000L),
      ("K", 1024L),
      ("M", 1048576L),
      ("G", 1073741824L),
      ("k", 1024L),
      ("m", 1048576L),
      ("g", 1073741824L),
      ("b", 512L),
    ] {
    if text.has_suffix(suffix) {
      digits = text[:text.length() - suffix.length()].to_owned()
      multiplier = factor
      break
    }
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
  let n = @string.parse_int64(digits, base=radix) catch {
    _ => raise HexdumpError("invalid byte count '\{text}'")
  }
  if n < 0L || n > 9223372036854775807L / multiplier {
    raise HexdumpError("byte count out of range")
  }
  n * multiplier
}
