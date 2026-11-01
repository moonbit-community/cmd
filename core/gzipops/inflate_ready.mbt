///|
// Strategy: inflate-ready-spans

///|
priv enum ReadyStep {
  NeedInput
  NeedOutput
  MatchTail(Int32, Int32)
  EndBlock
}

///|
// A length/distance token consumes at most 48 bits. The synchronous caller
// reserves six input bytes and reads only those needed by each actual code.
fn Bits::take_ready(self : Bits, count : Int32) -> Int32 {
  while self.available < count {
    self.pending = self.pending |
      (self.buffer[self.position].to_uint() << self.available)
    self.position += 1
    self.available += 8
  }
  let value = self.peek(count)
  self.drop_bits(count)
  value
}

///|
fn Huffman::read_ready(self : Huffman, bits : Bits) -> Int32 raise {
  guard self.width > 0 else { fail("invalid Huffman code") }
  for ;; {
    if self.buffered(bits) is Some(symbol) {
      return symbol
    }
    bits.pending = bits.pending |
      (bits.buffer[bits.position].to_uint() << bits.available)
    bits.position += 1
    bits.available += 8
  }
}

///|
fn compressed_ready(
  bits : Bits,
  literal : Huffman,
  distance : Huffman,
  output : InflateOutput,
) -> ReadyStep raise {
  for ;; {
    if output.count == output.pending.length() {
      return NeedOutput
    }
    if bits.end - bits.position < 6 {
      return NeedInput
    }
    let symbol = literal.read_ready(bits)
    if symbol < 256 {
      output.push(symbol.to_byte())
    } else if symbol == 256 {
      return EndBlock
    } else {
      guard symbol <= 285 else { fail("invalid length symbol") }
      let length = length_base[symbol - 257] +
        bits.take_ready(length_extra[symbol - 257])
      let distance_symbol = distance.read_ready(bits)
      guard distance_symbol < 30 else { fail("invalid distance symbol") }
      let count = distance_base[distance_symbol] +
        bits.take_ready(distance_extra[distance_symbol])
      guard count <= output.history else {
        fail("distance exceeds output history")
      }
      let space = output.pending.length() - output.count
      let copied = length.min(space)
      output.copy_match(count, copied)
      if copied < length {
        // Commit the already decoded token once. The caller flushes before
        // copying its tail from the same overlapping history after wraparound.
        return MatchTail(count, length - copied)
      }
    }
  }
}
