///|
// Strategy: seq-integer-batches

///|
fn Decimal::bounded_integer(self : Decimal) -> Int64? {
  if self.scale != 0 ||
    self.coefficient.compare_int64(-9223372036854775808L) < 0 ||
    self.coefficient.compare_int64(9223372036854775807L) > 0 {
    None
  } else {
    Some(self.coefficient.to_int64())
  }
}

///|
priv struct IntegerSequence {
  mut current : Int64
  last : Int64
  step : Int64
  separator : Bytes
  width : Int32
  scratch : FixedArray[Byte]
  mut emitted : Bool
  mut done : Bool
}

///|
fn IntegerSequence::new(
  first : Int64,
  step : Int64,
  last : Int64,
  separator : Bytes,
  width : Int32,
) -> IntegerSequence {
  {
    current: first,
    step,
    last,
    separator,
    width,
    scratch: FixedArray::make(20, b'0'),
    emitted: false,
    done: false,
  }
}

///|
fn IntegerSequence::fill(
  self : IntegerSequence,
  output : FixedArray[Byte],
) -> Int32 {
  let mut used = 0
  while !self.done {
    let value = self.current
    if (self.step > 0 && value > self.last) ||
      (self.step < 0 && value < self.last) {
      if self.emitted {
        output[used] = b'\n'
        used += 1
      }
      self.done = true
      break
    }
    // Reserve the complete next record and its eventual terminal newline.
    if output.length() - used < self.separator.length() + 21 {
      break
    }
    if self.emitted {
      for byte in self.separator {
        output[used] = byte
        used += 1
      }
    }
    let negative = value < 0
    let mut magnitude = if negative {
      0UL - value.reinterpret_as_uint64()
    } else {
      value.reinterpret_as_uint64()
    }
    let mut start = 20
    for ;; {
      start -= 1
      self.scratch[start] = (magnitude % 10UL).to_byte() + b'0'
      magnitude /= 10UL
      if magnitude == 0UL {
        break
      }
    }
    if negative {
      output[used] = b'-'
      used += 1
    }
    let digits = 20 - start + (if negative { 1 } else { 0 })
    for _ in digits..<self.width {
      output[used] = b'0'
      used += 1
    }
    for i in start..<20 {
      output[used] = self.scratch[i]
      used += 1
    }
    self.emitted = true
    if (self.step > 0 && value > 9223372036854775807L - self.step) ||
      (self.step < 0 && value < -9223372036854775808L - self.step) {
      output[used] = b'\n'
      used += 1
      self.done = true
      break
    }
    self.current += self.step
  }
  used
}

///|
async fn print_integers(
  sequence : IntegerSequence,
  writer : &@io.Writer,
) -> Unit {
  let buffer = FixedArray::make(65536, b'\x00')
  while !sequence.done {
    let count = sequence.fill(buffer)
    if count > 0 {
      writer.write(buffer.unsafe_reinterpret_as_bytes()[:count])
    }
  }
}
