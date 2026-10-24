///|
async fn skip_bytes(reader : &@io.Reader, count : Int64) -> Unit {
  let buffer : FixedArray[Byte] = FixedArray::make(65536, 0)
  let mut remaining = count
  while remaining > 0L {
    let count = reader.read(buffer, max_len=remaining.min(65536L).to_int())
    if count == 0 {
      raise CliError(4, "xxd: Sorry, cannot seek.")
    }
    remaining -= count.to_int64()
  }
}

///|
async fn input_offset(file : @fs.File?, seek : Seek?) -> Int64 {
  guard seek is Some(seek) else { return 0L }
  let amount = if seek.negative { -seek.amount } else { seek.amount }
  if !seek.negative {
    return amount
  }
  guard file is Some(file) else {
    raise CliError(4, "xxd: Sorry, cannot seek.")
  }
  if file.kind() != @fs.Regular && file.kind() != @fs.BlockDevice {
    raise CliError(4, "xxd: Sorry, cannot seek.")
  }
  let start = if seek.relative { 0L } else { file.size() }
  let position = checked_add(start, amount, 4, "xxd: Sorry, cannot seek.")
  if position < 0L {
    raise CliError(4, "xxd: Sorry, cannot seek.")
  }
  position
}

///|
priv struct Output {
  file : @fs.File?
  mut position : Int64
}

///|
async fn Output::write(self : Output, bytes : Bytes) -> Unit {
  let next = checked_add(
    self.position,
    bytes.length().to_int64(),
    3,
    "xxd: output offset overflow.",
  )
  try {
    match self.file {
      Some(file) => file.write_at(bytes[:], position=self.position)
      None => @stdio.stdout.write(bytes)
    }
  } catch {
    error => raise CliError(3, "xxd: \{error}")
  }
  self.position = next
}

///|
async fn Output::seek(self : Output, position : Int64) -> Unit {
  if position < 0L || (self.file is None && position < self.position) {
    raise CliError(5, "xxd: Sorry, cannot seek backwards.")
  }
  if self.file is Some(_) {
    self.position = position
    return
  }
  let zeros = Bytes::make(65536, b'\x00')
  while self.position < position {
    let count = (position - self.position).min(65536L).to_int()
    self.write(zeros[:count].to_owned())
  }
}
