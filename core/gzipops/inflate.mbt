///|
priv enum DecodeEntry {
  Invalid
  Symbol(Int32, Int32)
  More(FixedArray[DecodeEntry], Int32)
}

///|
priv struct Huffman {
  codes : Map[Int32, Int32]
  width : Int32
  main_bits : Int32
  main : FixedArray[DecodeEntry]
}

///|
fn huffman(
  lengths : Array[Int32],
  strict~ : Bool = false,
  main_bits~ : Int32 = 9,
) -> Huffman raise {
  let counts = Array::make(16, 0)
  let mut width = 0
  for length in lengths {
    guard length >= 0 && length <= 15 else {
      fail("invalid Huffman code length")
    }
    if length > 0 {
      counts[length] += 1
      if length > width {
        width = length
      }
    }
  }
  let next = Array::make(16, 0)
  let mut space = 1
  let mut code = 0
  for length in 1..<=15 {
    space = space * 2 - counts[length]
    guard space >= 0 else { fail("oversubscribed Huffman tree") }
    code = (code + counts[length - 1]) << 1
    next[length] = code
  }
  if space > 0 && (strict || (width != 0 && width != 1)) {
    fail("incomplete Huffman tree")
  }
  let codes : Map[Int32, Int32] = Map([])
  let main_bits = main_bits.min(width.max(1))
  let main = FixedArray::make(1 << main_bits, DecodeEntry::Invalid)
  let sub_widths = FixedArray::make(1 << main_bits, 0)
  let reversed_codes = Array::make(lengths.length(), 0)
  for symbol, length in lengths {
    if length == 0 {
      continue
    }
    let mut reversed = 0
    let mut value = next[length]
    for _ in 0..<length {
      reversed = (reversed << 1) | (value & 1)
      value = value >> 1
    }
    next[length] += 1
    codes[(length << 16) | reversed] = symbol
    reversed_codes[symbol] = reversed
    if length > main_bits {
      let prefix = reversed & ((1 << main_bits) - 1)
      sub_widths[prefix] = sub_widths[prefix].max(length - main_bits)
    }
  }
  for prefix, sub_width in sub_widths {
    if sub_width > 0 {
      main[prefix] = More(FixedArray::make(1 << sub_width, Invalid), sub_width)
    }
  }
  for symbol, length in lengths {
    if length == 0 {
      continue
    }
    let reversed = reversed_codes[symbol]
    if length <= main_bits {
      for index = reversed; index < main.length(); index = index + (1 << length) {
        main[index] = Symbol(symbol, length)
      }
    } else {
      let prefix = reversed & ((1 << main_bits) - 1)
      guard main[prefix] is More(table, _) else { abort("missing subtable") }
      for index = reversed >> main_bits
          index < table.length()
          index = index + (1 << (length - main_bits)) {
        table[index] = Symbol(symbol, length)
      }
    }
  }
  { codes, width, main_bits, main, }
}

///|
// A short code may be complete before the full lookup width is available.
// Check that case before reading another byte, preserving late read errors.
fn Huffman::buffered(self : Huffman, bits : Bits) -> Int32? raise {
  match self.main[bits.peek(self.main_bits)] {
    Symbol(symbol, length) if length <= bits.available => {
      bits.drop_bits(length)
      Some(symbol)
    }
    More(table, width) if bits.available >= self.main_bits =>
      match table[bits.peek(self.main_bits + width) >> self.main_bits] {
        Symbol(symbol, length) if length <= bits.available => {
          bits.drop_bits(length)
          Some(symbol)
        }
        Invalid if bits.available >= self.main_bits + width =>
          fail("invalid Huffman code")
        _ => None
      }
    Invalid if bits.available >= self.main_bits => fail("invalid Huffman code")
    _ => None
  }
}

///|
async fn Huffman::read(self : Huffman, bits : Bits) -> Int32 {
  guard self.width > 0 else { fail("invalid Huffman code") }
  for ;; {
    if self.buffered(bits) is Some(symbol) {
      return symbol
    }
    if !bits.fill_byte() {
      break
    }
  }
  // EOF can leave fewer bits than a lookup width. Retain the canonical slow
  // path so those bits receive the same symbol/truncation validation.
  let mut code = 0
  for length in 1..<=self.width {
    code = code | (bits.take(1) << (length - 1))
    if self.codes.get((length << 16) | code) is Some(symbol) {
      return symbol
    }
  }
  fail("invalid Huffman code")
}

///|
fn fixed_trees() -> (Huffman, Huffman) raise {
  let lengths = Array::makei(288, symbol => {
    if symbol <= 143 {
      8
    } else if symbol <= 255 {
      9
    } else if symbol <= 279 {
      7
    } else {
      8
    }
  })
  (huffman(lengths), huffman(Array::make(32, 5), main_bits=6))
}

///|
async fn dynamic_trees(bits : Bits) -> (Huffman, Huffman) {
  let literal_count = bits.take(5) + 257
  let distance_count = bits.take(5) + 1
  let code_count = bits.take(4) + 4
  guard literal_count <= 286 else { fail("invalid literal code count") }
  let order = [16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15]
  let code_lengths = Array::make(19, 0)
  for index in 0..<code_count {
    code_lengths[order[index]] = bits.take(3)
  }
  let tree = huffman(code_lengths, strict=true, main_bits=7)
  let total = literal_count + distance_count
  let lengths : Array[Int32] = []
  while lengths.length() < total {
    let symbol = tree.read(bits)
    let (value, count) = match symbol {
      0..<=15 => (symbol, 1)
      16 => {
        guard !lengths.is_empty() else { fail("missing previous code length") }
        (lengths[lengths.length() - 1], bits.take(2) + 3)
      }
      17 => (0, bits.take(3) + 3)
      18 => (0, bits.take(7) + 11)
      _ => fail("invalid code-length symbol")
    }
    guard count <= total - lengths.length() else {
      fail("code-length repeat exceeds tree")
    }
    for _ in 0..<count {
      lengths.push(value)
    }
  }
  guard lengths[256] > 0 else { fail("missing end-of-block code") }
  (
    huffman(lengths[:literal_count].to_owned()),
    huffman(lengths[literal_count:].to_owned(), main_bits=6),
  )
}

///|
let crc_table : FixedArray[UInt32] = FixedArray::makei(256, index => {
  let mut value = index.reinterpret_as_uint()
  for _ in 0..<8 {
    value = (value >> 1) ^ (if (value & 1U) == 0U { 0U } else { 0xedb88320U })
  }
  value
})

///|
fn update_crc(crc : UInt32, byte : Byte) -> UInt32 {
  (crc >> 8) ^ crc_table[((crc ^ byte.to_uint()) & 0xffU).reinterpret_as_int()]
}

///|
priv struct InflateOutput {
  window : FixedArray[Byte]
  mut cursor : Int32
  mut history : Int32
  mut crc : UInt32
  mut size : UInt32
  pending : FixedArray[Byte]
  mut count : Int32
  writer : &@io.Writer
  test_only : Bool
}

///|
fn InflateOutput::push(self : InflateOutput, byte : Byte) -> Unit {
  self.window[self.cursor] = byte
  self.cursor = (self.cursor + 1) & 32767
  if self.history < 32768 {
    self.history += 1
  }
  self.crc = update_crc(self.crc, byte)
  self.size += 1U
  if !self.test_only {
    self.pending[self.count] = byte
    self.count += 1
  }
}

///|
async fn InflateOutput::flush(self : InflateOutput) -> Unit {
  if self.count > 0 {
    let count = self.count
    self.count = 0
    self.writer.write(self.pending.unsafe_reinterpret_as_bytes()[:count])
  }
}

///|
async fn stored_payload(
  bits : Bits,
  length : Int32,
  output : InflateOutput,
) -> Unit {
  let mut remaining = length
  while remaining > 0 && bits.available >= 8 {
    output.push(bits.peek(8).to_byte())
    bits.drop_bits(8)
    remaining -= 1
    if output.count == output.pending.length() {
      output.flush()
    }
  }
  while remaining > 0 {
    guard bits.refill() else { fail("unexpected end of file") }
    let count = remaining
      .min(bits.end - bits.position)
      .min(output.pending.length() - output.count)
    for index in bits.position..<(bits.position + count) {
      output.push(bits.buffer[index])
    }
    bits.position += count
    remaining -= count
    if output.count == output.pending.length() {
      output.flush()
    }
  }
}

///|
let length_base : ReadOnlyArray[Int32] = [
  3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83,
  99, 115, 131, 163, 195, 227, 258,
]

///|
let length_extra : ReadOnlyArray[Int32] = [
  0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5,
  5, 0,
]

///|
let distance_base : ReadOnlyArray[Int32] = [
  1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769,
  1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577,
]

///|
let distance_extra : ReadOnlyArray[Int32] = [
  0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11,
  12, 12, 13, 13,
]

///|
async fn compressed_block(
  bits : Bits,
  literal : Huffman,
  distance : Huffman,
  output : InflateOutput,
) -> Unit {
  for ;; {
    let symbol = literal.read(bits)
    if symbol < 256 {
      output.push(symbol.to_byte())
      if output.count == output.pending.length() {
        output.flush()
      }
    } else if symbol == 256 {
      return
    } else {
      guard symbol <= 285 else { fail("invalid length symbol") }
      let length = length_base[symbol - 257] +
        bits.take(length_extra[symbol - 257])
      let distance_symbol = distance.read(bits)
      guard distance_symbol < 30 else { fail("invalid distance symbol") }
      let count = distance_base[distance_symbol] +
        bits.take(distance_extra[distance_symbol])
      guard count <= output.history else {
        fail("distance exceeds output history")
      }
      let mut remaining = length
      while remaining > 0 {
        let chunk = remaining.min(output.pending.length() - output.count)
        for _ in 0..<chunk {
          output.push(output.window[(output.cursor - count) & 32767])
        }
        remaining -= chunk
        if output.count == output.pending.length() {
          output.flush()
        }
      }
    }
  }
}

///|
async fn inflate(
  bits : Bits,
  writer : &@io.Writer,
  test_only : Bool,
) -> (UInt32, UInt32) {
  let output : InflateOutput = {
    window: FixedArray::make(32768, b'\x00'),
    cursor: 0,
    history: 0,
    crc: 0xffffffffU,
    size: 0U,
    pending: FixedArray::make(65536, b'\x00'),
    count: 0,
    writer,
    test_only,
  }
  errdefer output.flush()
  let mut fixed_cache : (Huffman, Huffman)? = None
  let mut is_last = false
  while !is_last {
    is_last = bits.take(1) != 0
    match bits.take(2) {
      0 => {
        bits.align()
        let length = bits.take(16)
        guard (length ^ bits.take(16)) == 0xffff else {
          fail("invalid stored-block length")
        }
        stored_payload(bits, length, output)
      }
      1 => {
        let (literal, distance) = match fixed_cache {
          Some(trees) => trees
          None => {
            let trees = fixed_trees()
            fixed_cache = Some(trees)
            trees
          }
        }
        compressed_block(bits, literal, distance, output)
      }
      2 => {
        let (literal, distance) = dynamic_trees(bits)
        compressed_block(bits, literal, distance, output)
      }
      _ => fail("reserved deflate block type")
    }
  }
  bits.align()
  output.flush()
  (output.crc ^ 0xffffffffU, output.size)
}
