///|
priv struct ReverseDecoder {
  style : Style
  cols : Int32
  base : Int64
  mut want : Int64
  mut column : Int32
  mut ignore_garbage : Bool
  mut skip_line : Bool
  mut first : Int32
  mut second : Int32
  mut third : Int32
  mut bits : Int32
  mut bit_count : Int32
}

///|
fn ReverseDecoder::new(
  style : Style,
  cols : Int32,
  base : Int64,
) -> ReverseDecoder {
  {
    style,
    cols,
    base,
    want: 0L,
    column: cols,
    ignore_garbage: true,
    skip_line: false,
    first: -1,
    second: 0,
    third: 0,
    bits: 0,
    bit_count: 0,
  }
}

///|
fn ReverseDecoder::newline(self : ReverseDecoder) -> Unit {
  if !(self.style is Plain) {
    self.want = 0L
  }
  self.column = self.cols
  self.ignore_garbage = true
  self.skip_line = false
}

///|
fn ReverseDecoder::feed(
  self : ReverseDecoder,
  byte : Byte,
) -> (Int64, Byte?)? raise CliError {
  if byte == b'\r' {
    return None
  }
  if self.skip_line {
    if byte == b'\n' {
      self.newline()
    }
    return None
  }
  if self.style is Plain && byte is (b' ' | b'\n' | b'\t') {
    return None
  }
  if self.style is Bits {
    self.first = hex_val(byte)
    if self.first < 0 && self.ignore_garbage {
      return None
    }
    if byte is (b'0' | b'1') {
      self.bits = (self.bits << 1) | (byte.to_int() - 0x30)
      self.bit_count += 1
    }
  } else {
    self.third = self.second
    self.second = self.first
    self.first = hex_val(byte)
    if self.first < 0 && self.ignore_garbage {
      return None
    }
  }
  self.ignore_garbage = false
  if !(self.style is Plain) && self.column >= self.cols {
    if self.first < 0 {
      self.column = 0
      if self.style is Bits {
        self.bit_count = 0
      }
    } else {
      if self.want > (9223372036854775807L - self.first.to_int64()) / 16L {
        raise CliError(5, "xxd: addressed offset overflow.")
      }
      self.want = self.want * 16L + self.first.to_int64()
    }
    return None
  }
  let target = checked_add(
    self.base,
    self.want,
    5,
    "xxd: addressed offset overflow.",
  )
  let mut result : Byte? = None
  if self.style is Bits {
    if self.bit_count == 8 {
      result = Some(self.bits.to_byte())
      self.bits = 0
      self.bit_count = 0
    }
  } else if self.second >= 0 && self.first >= 0 {
    result = Some(((self.second << 4) | self.first).to_byte())
    self.first = -1
  } else if self.first < 0 && self.second < 0 && self.third < 0 {
    self.skip_line = true
  }
  if result is Some(_) {
    self.want = checked_add(self.want, 1L, 5, "xxd: addressed offset overflow.")
    if !(self.style is Plain) {
      self.column += 1
      if self.column >= self.cols {
        self.skip_line = true
      }
    }
  }
  if byte == b'\n' {
    self.newline()
  }
  Some((target, result))
}

///|
async fn flush_reverse(output : Output, pending : Array[Byte]) -> Unit {
  if !pending.is_empty() {
    output.write(Bytes::from_array(pending))
    pending.clear()
  }
}

///|
async fn reverse_stream(
  reader : &@io.Reader,
  output : Output,
  opts : Options,
) -> Unit {
  if opts.style is Little || opts.style is Include {
    raise CliError(255, "xxd: Sorry, cannot revert this type of hexdump")
  }
  let base = match opts.seek {
    Some(seek) => if seek.negative { -seek.amount } else { seek.amount }
    None => 0L
  }
  let decoder = ReverseDecoder::new(opts.style, opts.cols, base)
  let pending : Array[Byte] = []
  while @stream.read_chunk(reader) is Some(chunk) {
    try {
      for byte in chunk {
        if decoder.feed(byte) is Some((target, value)) {
          let current = checked_add(
            output.position,
            pending.length().to_int64(),
            5,
            "xxd: output offset overflow.",
          )
          if target != current {
            flush_reverse(output, pending)
            output.seek(target)
          }
          if value is Some(value) {
            pending.push(value)
          }
        }
      }
    } catch {
      CliError(status, message) => {
        if status == 5 {
          flush_reverse(output, pending)
        }
        raise CliError(status, message)
      }
      error => raise error
    }
    flush_reverse(output, pending)
  }
}
